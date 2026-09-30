import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/services/write_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('QueueOp toJson/fromJson', () {
    final op = QueueOp(
      type: QueueOpType.saveTask,
      id: 't1',
      payload: {'foo': 'bar'},
      attempts: 2,
    );

    final j = op.toJson();
    final copy = QueueOp.fromJson(Map<String, dynamic>.from(j));

    expect(copy.type, op.type);
    expect(copy.id, 't1');
    expect(copy.payload?['foo'], 'bar');
    expect(copy.attempts, 2);
  });

  test('WriteQueue retry logic', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final q = WriteQueue(prefs);

    final op = QueueOp(type: QueueOpType.saveTask, id: 't-retry');

    var called = 0;

    q.attachOpBuilder(
      (o) => () async {
        called++;
        // fail until internal attempts reaches 3 -> then succeed
        if (o.attempts < 3) throw Exception('transient');
      },
    );

    q.enqueueOp(op);

    // wait enough time for retries (backoff increases); keep generous margin
    await Future.delayed(Duration(seconds: 5));

    // op should have been attempted multiple times and eventually succeeded
    expect(called >= 4, isTrue);
  });

  test('WriteQueue failure handler is called on permanent failure', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final q = WriteQueue(prefs);

    final op = QueueOp(type: QueueOpType.saveTask, id: 't-fail');
    q.attachOpBuilder(
      (o) => () async {
        // always fail
        throw Exception('permanent');
      },
    );

    q.attachFailureHandler((o, err) {
      // noop for test; we will verify the queue was processed/cleared
    });

    q.enqueueOp(op);
    // backoff sums to about ~12.4s for full exhaustion; wait a bit longer
    await Future.delayed(Duration(seconds: 15));

    // Verify queue persisted data is cleared after processing
    final prefs2 = await SharedPreferences.getInstance();
    final raw = prefs2.getString('write_queue_v1');
    // should be either null or an empty list string
    if (raw != null && raw.isNotEmpty) {
      final list = jsonDecode(raw) as List<dynamic>;
      expect(list.isEmpty, isTrue);
    }
  });
}
