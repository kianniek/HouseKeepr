import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/models/completion_record.dart';

void main() {
  test('CompletionRecord parses ISO and defaults', () {
    final now = DateTime.utc(2025, 3, 4, 5, 6, 7);
    final m = {
      'id': 'c1',
      'taskId': 't1',
      'date': '2025-03-04',
      'completedBy': 'u1',
      'createdAt': now.toIso8601String(),
    };

    final r = CompletionRecord.fromMap(m);
    expect(r.id, 'c1');
    expect(r.taskId, 't1');
    expect(r.date, '2025-03-04');
    expect(r.completedBy, 'u1');
    expect(r.createdAt, now.toUtc());

    final m2 = {'taskId': 't2', 'date': '2025-03-05'};
    final r2 = CompletionRecord.fromMap(m2);
    expect(r2.taskId, 't2');
    expect(r2.date, '2025-03-05');
    expect(r2.createdAt, isA<DateTime>());
  });
}
