import 'package:shared_preferences/shared_preferences.dart';
import '../models/completion_record.dart';

class HistoryRepository {
  static const _kKey = 'completion_history_v1';
  final SharedPreferences prefs;

  HistoryRepository(this.prefs);

  List<CompletionRecord> loadAll() {
    final raw = prefs.getStringList(_kKey) ?? [];
    final out = <CompletionRecord>[];
    for (final s in raw) {
      try {
        out.add(CompletionRecord.fromJson(s));
      } catch (_) {}
    }
    return out;
  }

  Future<void> saveAll(List<CompletionRecord> records) async {
    final raw = records.map((r) => r.toJson()).toList();
    await prefs.setStringList(_kKey, raw);
  }

  Future<void> add(CompletionRecord r) async {
    final list = loadAll();
    list.add(r);
    await saveAll(list);
  }

  Future<void> remove(String id) async {
    final list = loadAll();
    list.removeWhere((r) => r.id == id);
    await saveAll(list);
  }

  List<CompletionRecord> forTaskOnDate(String taskId, String date) {
    return loadAll()
        .where((r) => r.taskId == taskId && r.date == date)
        .toList();
  }
}
