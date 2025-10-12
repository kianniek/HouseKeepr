import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:housekeepr/services/write_queue.dart';

class InMemoryPrefs implements SharedPreferences {
  final Map<String, Object> _map = {};

  @override
  Future<bool> setString(String key, String value) async {
    _map[key] = value;
    return true;
  }

  @override
  String? getString(String key) => _map[key] as String?;

  @override
  Future<bool> remove(String key) async {
    _map.remove(key);
    return true;
  }

  // The rest of SharedPreferences API members are not used by WriteQueue tests.
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('WriteQueue per-user persistence and migration', () async {
    final prefs = InMemoryPrefs();
    // simulate old global queue present
    final oldKey = 'write_queue_v1';
    final sample = [
      {
        'type': 0,
        'id': 't1',
        'payload': {'id': 't1', 'title': 'A'},
        'attempts': 0,
      },
    ];
    prefs.setString(oldKey, jsonEncode(sample));

    final wq = WriteQueue(prefs);
    // initially no user, but global key exists
    // setUserId should migrate global -> per-user
    wq.setUserId('userA');
    final perKey = 'write_queue_v1_userA';
    expect(prefs.getString(perKey), isNotNull);
    expect(prefs.getString(oldKey), isNull);

    // enqueue an op and ensure it's persisted under per-user key
    final op = QueueOp(
      type: QueueOpType.saveTask,
      id: 't2',
      payload: {'id': 't2'},
    );
    wq.enqueueOp(op);
    final raw = prefs.getString(perKey);
    expect(raw, isNotNull);
    final list = (jsonDecode(raw!) as List).cast<Map<String, dynamic>>();
    expect(list.length, equals(2));

    // switching to null clears in-memory queue (and prevents future saves to per-key)
    wq.setUserId(null);
    // set back to userA and ensure previous persisted items are reloaded
    wq.setUserId('userA');
    final raw2 = prefs.getString(perKey);
    expect(raw2, isNotNull);
  });

  test('WriteQueue retries failed ops and resumes on attach', () async {
    final prefs = InMemoryPrefs();
    final wq = WriteQueue(prefs);
    wq.setUserId('userB');

    int callCount = 0;
    // Enqueue an op that will fail 2 times, then succeed
    wq.attachOpBuilder((op) {
      return () async {
        callCount++;
        if (callCount < 3) throw Exception('fail');
      };
    });
    wq.enqueueOp(QueueOp(type: QueueOpType.saveTask, id: 't3'));
    // Wait for processing
    await Future.delayed(const Duration(seconds: 2));
    expect(callCount, equals(3));

    // Detach opBuilder, enqueue another op (should not process)
    wq.attachOpBuilder(null);
    wq.enqueueOp(QueueOp(type: QueueOpType.saveTask, id: 't4'));
    await Future.delayed(const Duration(milliseconds: 200));
    // callCount should not change
    expect(callCount, equals(3));

    // Re-attach opBuilder, should process pending op
    int processed = 0;
    wq.attachOpBuilder((op) {
      return () async {
        processed++;
      };
    });
    await Future.delayed(const Duration(seconds: 1));
    expect(processed, equals(1));
  });
}
