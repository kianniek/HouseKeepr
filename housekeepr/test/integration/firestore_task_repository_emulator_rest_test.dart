import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:test/test.dart';
// Keep this test pure-Dart (no Flutter imports) so it can run with `dart test`.

void main() {
  group('Firestore emulator REST integration', () {
    final host = const String.fromEnvironment(
      'FIRESTORE_EMULATOR_HOST',
      defaultValue: '',
    );
    final projectId = const String.fromEnvironment(
      'FIREBASE_PROJECT_ID',
      defaultValue: 'demo-project',
    );

    test('save/load task via emulator REST API', () async {
      // If no FIRESTORE_EMULATOR_HOST is set, skip the integration test
      if (host.isEmpty) {
        return;
      }

      final parts = host.split(':');
      if (parts.length != 2) {
        return;
      }
      final port = int.tryParse(parts[1]);
      if (port == null) {
        return;
      }

      Future<bool> isHostOpen(
        String host,
        int port, {
        Duration timeout = const Duration(seconds: 2),
      }) async {
        try {
          final socket = await Socket.connect(host, port, timeout: timeout);
          socket.destroy();
          return true;
        } catch (_) {
          return false;
        }
      }

      final reachable = await isHostOpen(
        parts[0],
        port,
        timeout: const Duration(seconds: 2),
      );
      if (!reachable) {
        return;
      }

      final base = Uri(scheme: 'http', host: parts[0], port: port);

      // Running under `dart test` so we can create a real HttpClient directly
      // to connect to the local emulator.

      // Note: do not run this under `flutter_test` since that test binding
      // overrides HttpClient and interferes with real HTTP calls.

      // Execute the test body directly.

      {
        final userId = 'integration-test-user';
        // Plain Map representing a Task (keeps test independent of Flutter SDK)
        final t = <String, dynamic>{
          'id': 't1',
          'title': 'Integration Test Task',
          'description': 'deadline + repeatDays check',
          'assigned_to_id': 'u1',
          'assigned_to_name': 'Tester',
          'priority': 2, // corresponds to TaskPriority.high
          'deadline': DateTime.utc(2025, 10, 21, 15, 30),
          'isRepeating': true,
          'repeatRule': 'weekly',
          'repeatDays': [1, 3, 5],
          'isHouseholdTask': false,
        };

        final docPath =
            '/v1/projects/$projectId/databases/(default)/documents/users/$userId/tasks/${t['id']}';
        final collectionPath =
            '/v1/projects/$projectId/databases/(default)/documents/users/$userId/tasks';

        final postUri = base.replace(
          path: collectionPath,
          queryParameters: {'documentId': t['id']},
        );

        final payload = {
          'fields': _transformToFirestoreFields(Map<String, dynamic>.from(t)),
        };

        // Write document
        final httpClient = HttpClient();
        try {
          final request = await httpClient.postUrl(postUri);
          request.headers.contentType = ContentType.json;
          request.write(json.encode(payload));
          final response = await request.close();
          await response.transform(utf8.decoder).join();
          expect(response.statusCode, anyOf([200, 201]));

          // Read back from the document resource path
          final getReq = await httpClient.getUrl(base.replace(path: docPath));
          final getRes = await getReq.close();
          final getBody = await getRes.transform(utf8.decoder).join();
          expect(getRes.statusCode, equals(200));

          final data = json.decode(getBody) as Map<String, dynamic>;
          // Extract fields back to simple map for assertions
          final map = _transformFromFirestoreFields(
            data['fields'] as Map<String, dynamic>,
          );

          expect(map['title'], equals(t['title']));
          if (map['deadline'] is String) {
            expect(
              DateTime.parse(map['deadline']).toUtc(),
              equals((t['deadline'] as DateTime).toUtc()),
            );
          }
          expect(
            (map['repeatDays'] as List<dynamic>?)
                ?.map((e) => e as int)
                .toList(),
            equals(t['repeatDays']),
          );
        } finally {
          httpClient.close(force: true);
        }
      }
    });
  });
}

Map<String, dynamic> _transformToFirestoreFields(Map<String, dynamic> src) {
  final out = <String, dynamic>{};
  src.forEach((k, v) {
    if (v == null) {
      return;
    }
    if (v is String) {
      out[k] = {'stringValue': v};
    } else if (v is bool) {
      out[k] = {'booleanValue': v};
    } else if (v is int) {
      out[k] = {'integerValue': v};
    } else if (v is double) {
      out[k] = {'doubleValue': v};
    } else if (v is DateTime) {
      out[k] = {'timestampValue': v.toUtc().toIso8601String()};
    } else if (v is List) {
      out[k] = {
        'arrayValue': {
          'values': v.map((e) => {'integerValue': e}).toList(),
        },
      };
    } else {
      out[k] = {'stringValue': v.toString()};
    }
  });
  return out;
}

Map<String, dynamic> _transformFromFirestoreFields(
  Map<String, dynamic> fields,
) {
  final out = <String, dynamic>{};
  fields.forEach((k, v) {
    if (v is Map<String, dynamic>) {
      if (v.containsKey('stringValue')) {
        out[k] = v['stringValue'];
      } else if (v.containsKey('integerValue')) {
        out[k] =
            int.tryParse(v['integerValue'].toString()) ?? v['integerValue'];
      } else if (v.containsKey('doubleValue')) {
        out[k] = v['doubleValue'];
      } else if (v.containsKey('booleanValue')) {
        out[k] = v['booleanValue'];
      } else if (v.containsKey('timestampValue')) {
        out[k] = v['timestampValue'];
      } else if (v.containsKey('arrayValue')) {
        final arr = v['arrayValue'] as Map<String, dynamic>;
        final vals = (arr['values'] as List<dynamic>?)?.map((e) {
          if (e is Map && e.containsKey('integerValue')) {
            return int.tryParse(e['integerValue'].toString()) ??
                e['integerValue'];
          }
          if (e is Map && e.containsKey('stringValue')) {
            return e['stringValue'];
          }
          return e;
        }).toList();
        out[k] = vals;
      }
    }
  });
  return out;
}
