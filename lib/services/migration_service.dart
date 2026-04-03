import 'package:shared_preferences/shared_preferences.dart';
import '../repositories/task_repository.dart';
import '../repositories/shopping_repository.dart';
import '../firestore/firestore_task_repository.dart';
import '../firestore/firestore_shopping_repository.dart';

class MigrationService {
  final SharedPreferences prefs;
  final TaskRepository localTaskRepo;
  final ShoppingRepository localShoppingRepo;
  final FirestoreTaskRepository firestoreTaskRepo;
  final FirestoreShoppingRepository firestoreShoppingRepo;

  static const _kMigratedKey = 'migrated_to_firestore_v1';

  MigrationService({
    required this.prefs,
    required this.localTaskRepo,
    required this.localShoppingRepo,
    required this.firestoreTaskRepo,
    required this.firestoreShoppingRepo,
  });

  Future<void> migrateIfNeeded(String userId) async {
    final migrated = prefs.getBool('${_kMigratedKey}_$userId') ?? false;
    if (migrated) return;

    final tasks = localTaskRepo.loadTasks();
    for (final t in tasks) {
      await firestoreTaskRepo.saveTask(t);
    }

    final items = localShoppingRepo.loadItems();
    for (final i in items) {
      await firestoreShoppingRepo.saveItem(i);
    }

    await prefs.setBool('${_kMigratedKey}_$userId', true);
  }
}
