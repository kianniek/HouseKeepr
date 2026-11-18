import 'dart:convert';

import 'package:http/http.dart' as http;

/// Minimal WebDAV backup/restore client using `package:http` (Android & Web).
class WebDavClient {
  WebDavClient({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;
  static const Duration _timeout = Duration(seconds: 30);

  Map<String, String> _authHeaders(String username, String password) {
    final token = base64Encode(utf8.encode('$username:$password'));
    return <String, String>{
      'Authorization': 'Basic $token',
      'Content-Type': 'application/json',
    };
  }

  /// Uploads [jsonPayload] to [fileUrl] via HTTP `PUT`.
  Future<void> uploadBackup({
    required String fileUrl,
    required String username,
    required String password,
    required String jsonPayload,
  }) async {
    final uri = Uri.parse(fileUrl.trim());
    final res = await _client
        .put(
          uri,
          headers: _authHeaders(username, password),
          body: jsonPayload,
        )
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('WebDAV upload failed (HTTP ${res.statusCode})');
    }
  }

  /// Downloads a JSON backup from [fileUrl] via HTTP `GET`.
  Future<String> downloadBackup({
    required String fileUrl,
    required String username,
    required String password,
  }) async {
    final uri = Uri.parse(fileUrl.trim());
    final res = await _client
        .get(uri, headers: _authHeaders(username, password))
        .timeout(_timeout);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('WebDAV download failed (HTTP ${res.statusCode})');
    }
    return res.body;
  }
}
