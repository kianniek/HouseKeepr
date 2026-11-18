import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/server_connection.dart';

/// Exception thrown by [OpenGymServerClient] on network or API errors.
class OpenGymServerException implements Exception {
  const OpenGymServerException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() =>
      statusCode != null ? 'HTTP $statusCode: $message' : message;
}

/// Capabilities reported by `<serverUrl>/api/config`.
class ServerCapabilities {
  const ServerCapabilities({
    required this.serverUrl,
    required this.oidcEnabled,
    this.oidcLabel,
  });

  final String serverUrl;
  final bool oidcEnabled;
  final String? oidcLabel;
}

/// HTTP client for connecting OpenGym to an optional self-hosted openGym server.
///
/// Uses `package:http` so it works identically on Android and Flutter Web.
class OpenGymServerClient {
  OpenGymServerClient({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 20);

  /// Normalizes a user-entered server address into a base URL without trailing slash.
  static String? normalizeServerUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;
    final withScheme =
        RegExp(r'^https?://', caseSensitive: false).hasMatch(trimmed)
            ? trimmed
            : 'https://$trimmed';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || uri.host.isEmpty) return null;
    final normalized = uri.toString();
    return normalized.endsWith('/')
        ? normalized.substring(0, normalized.length - 1)
        : normalized;
  }

  /// Returns `true` if [raw] uses plain `http://` on a non-localhost host.
  static bool isPlainHttpRemote(String raw) {
    final base = normalizeServerUrl(raw);
    if (base == null) return false;
    final uri = Uri.parse(base);
    if (uri.scheme.toLowerCase() != 'http') return false;
    final host = uri.host.toLowerCase();
    return host != 'localhost' && host != '127.0.0.1' && host != '::1';
  }

  Map<String, String> _headers({
    String? authToken,
    String? cfAccessClientId,
    String? cfAccessClientSecret,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (authToken != null && authToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $authToken';
    }
    if (cfAccessClientId != null &&
        cfAccessClientId.isNotEmpty &&
        cfAccessClientSecret != null &&
        cfAccessClientSecret.isNotEmpty) {
      headers['CF-Access-Client-Id'] = cfAccessClientId;
      headers['CF-Access-Client-Secret'] = cfAccessClientSecret;
    }
    return headers;
  }

  Future<Map<String, dynamic>> _send(
    String method,
    String url, {
    Map<String, String>? headers,
    Object? body,
  }) async {
    final uri = Uri.parse(url);
    late http.Response response;
    final encodedBody = body != null ? jsonEncode(body) : null;

    switch (method) {
      case 'GET':
        response = await _client.get(uri, headers: headers).timeout(_timeout);
      case 'POST':
        response = await _client
            .post(uri, headers: headers, body: encodedBody)
            .timeout(_timeout);
      case 'PUT':
        response = await _client
            .put(uri, headers: headers, body: encodedBody)
            .timeout(_timeout);
      default:
        throw ArgumentError('Unsupported HTTP method: $method');
    }

    Map<String, dynamic> decoded = const <String, dynamic>{};
    if (response.body.isNotEmpty) {
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map<String, dynamic>) {
          decoded = raw;
        } else if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } catch (_) {
        if (response.statusCode >= 200 && response.statusCode < 300) {
          throw OpenGymServerException(
            'Unexpected non-JSON response from server.',
            statusCode: response.statusCode,
          );
        }
      }
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final errMsg = decoded['error'] as String? ?? 'Request failed';
      throw OpenGymServerException(errMsg, statusCode: response.statusCode);
    }

    return decoded;
  }

  /// Probes `<serverUrl>/api/config` to verify reachability and auth options.
  Future<ServerCapabilities> probeServer(
    String serverUrl, {
    String? cfAccessClientId,
    String? cfAccessClientSecret,
  }) async {
    final base = normalizeServerUrl(serverUrl);
    if (base == null) {
      throw const OpenGymServerException('Invalid server URL');
    }
    final data = await _send(
      'GET',
      '$base/api/config',
      headers: _headers(
        cfAccessClientId: cfAccessClientId,
        cfAccessClientSecret: cfAccessClientSecret,
      ),
    );
    final oidc = data['oidc'];
    final oidcEnabled = oidc is Map && oidc['enabled'] == true;
    final oidcLabel = oidc is Map ? oidc['label'] as String? : null;
    return ServerCapabilities(
      serverUrl: base,
      oidcEnabled: oidcEnabled,
      oidcLabel: oidcLabel,
    );
  }

  /// Exchanges a 6/8-character pairing [code] for a bearer token.
  Future<String> pairWithCode(
    String serverUrl,
    String code, {
    String? cfAccessClientId,
    String? cfAccessClientSecret,
  }) async {
    final base = normalizeServerUrl(serverUrl);
    if (base == null) {
      throw const OpenGymServerException('Invalid server URL');
    }
    final data = await _send(
      'POST',
      '$base/api/pair/redeem',
      headers: _headers(
        cfAccessClientId: cfAccessClientId,
        cfAccessClientSecret: cfAccessClientSecret,
      ),
      body: <String, dynamic>{'code': code.trim()},
    );
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const OpenGymServerException('Server did not return an auth token');
    }
    return token;
  }

  /// Signs in with username & password to obtain a bearer token.
  Future<String> loginWithPassword(
    String serverUrl, {
    required String username,
    required String password,
    String? cfAccessClientId,
    String? cfAccessClientSecret,
  }) async {
    final base = normalizeServerUrl(serverUrl);
    if (base == null) {
      throw const OpenGymServerException('Invalid server URL');
    }
    final data = await _send(
      'POST',
      '$base/api/login',
      headers: _headers(
        cfAccessClientId: cfAccessClientId,
        cfAccessClientSecret: cfAccessClientSecret,
      ),
      body: <String, dynamic>{
        'username': username.trim(),
        'password': password,
      },
    );
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw const OpenGymServerException('Login did not return an auth token');
    }
    return token;
  }

  /// Pushes local unsynced records to `<serverUrl>/api/sync`.
  Future<Map<String, dynamic>> pushSync(
    ServerConnectionConfig config,
    Map<String, dynamic> payload,
  ) async {
    final base = normalizeServerUrl(config.serverUrl);
    if (base == null || !config.isConnected) {
      throw const OpenGymServerException('Not connected to a server');
    }
    return _send(
      'PUT',
      '$base/api/sync',
      headers: _headers(
        authToken: config.authToken,
        cfAccessClientId: config.cfAccessClientId,
        cfAccessClientSecret: config.cfAccessClientSecret,
      ),
      body: payload,
    );
  }

  /// Pulls remote records from `<serverUrl>/api/sync`.
  Future<Map<String, dynamic>> pullSync(
    ServerConnectionConfig config, {
    String? since,
  }) async {
    final base = normalizeServerUrl(config.serverUrl);
    if (base == null || !config.isConnected) {
      throw const OpenGymServerException('Not connected to a server');
    }
    final query =
        since != null && since.isNotEmpty ? '?since=${Uri.encodeQueryComponent(since)}' : '';
    return _send(
      'GET',
      '$base/api/sync$query',
      headers: _headers(
        authToken: config.authToken,
        cfAccessClientId: config.cfAccessClientId,
        cfAccessClientSecret: config.cfAccessClientSecret,
      ),
    );
  }

  /// Fetches shared community routines from `<serverUrl>/api/community/routines`.
  Future<List<Map<String, dynamic>>> fetchCommunityRoutines(
    ServerConnectionConfig config,
  ) async {
    final base = normalizeServerUrl(config.serverUrl);
    if (base == null || !config.isConnected) {
      throw const OpenGymServerException('Not connected to a server');
    }
    final data = await _send(
      'GET',
      '$base/api/community/routines',
      headers: _headers(
        authToken: config.authToken,
        cfAccessClientId: config.cfAccessClientId,
        cfAccessClientSecret: config.cfAccessClientSecret,
      ),
    );
    final rawList = data['routines'];
    if (rawList is! List) return const <Map<String, dynamic>>[];
    return rawList
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
  }
}
