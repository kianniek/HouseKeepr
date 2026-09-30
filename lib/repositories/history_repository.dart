import 'package:hive/hive.dart';
import '../models/completion_record.dart';

class HistoryRepository {
  Box get _box => Hive.box('history');

  List<CompletionRecord> loadAll() {
    final out = <CompletionRecord>[];
    for (final raw in _box.values) {
      try {
        out.add(CompletionRecord.fromMap(Map<String, dynamic>.from(raw)));
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveAll(List<CompletionRecord> records) async {
    // store each record under its id
    for (final r in records) {
      await _box.put(r.id, r.toMap());
    }
  }

  Future<void> add(CompletionRecord r) async {
    await _box.put(r.id, r.toMap());
  }

  Future<void> remove(String id) async {
    await _box.delete(id);
  }

  List<CompletionRecord> forTaskOnDate(String taskId, String date) {
    return loadAll()
        .where((r) => r.taskId == taskId && r.date == date)
        .toList();
  }
}
