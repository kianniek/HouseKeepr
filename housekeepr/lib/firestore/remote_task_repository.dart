import '../models/task.dart';

/// Small interface to abstract remote task persistence for testing.
abstract class RemoteTaskRepository {
  Future<void> saveTask(Task task);
  Future<void> deleteTask(String id);
}
