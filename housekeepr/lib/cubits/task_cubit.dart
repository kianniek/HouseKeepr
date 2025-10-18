import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../firestore/remote_task_repository.dart';
import '../core/settings_repository.dart';
import '../core/sync_mode.dart';
import '../services/write_queue.dart';

part 'task_state.dart';

class TaskCubit extends Cubit<TaskState> {
  final TaskRepository repo;
  RemoteTaskRepository? remoteRepo;
  final SettingsRepository? settings;
  final WriteQueue? writeQueue;

  TaskCubit(this.repo, {this.settings, this.writeQueue})
    : super(TaskState.initial()) {
    load();
  }

  void load() {
    final tasks = repo.loadTasks();
    emit(state.copyWith(tasks: tasks));
  }

  Future<void> addTask(Task task) async {
    final list = List<Task>.from(state.tasks)..add(task);
    await repo.saveTasks(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveTask,
              id: task.id,
              payload: task.toMap(),
            ),
          );
        } else {
          Future<void> op() => remoteRepo!.saveTask(task);
          unawaited(op());
        }
      }
    }
    emit(state.copyWith(tasks: list));
  }

  Future<void> updateTask(Task task) async {
    final list = state.tasks.map((t) => t.id == task.id ? task : t).toList();
    await repo.saveTasks(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveTask,
              id: task.id,
              payload: task.toMap(),
            ),
          );
        } else {
          Future<void> op() => remoteRepo!.saveTask(task);
          unawaited(op());
        }
      }
    }
    emit(state.copyWith(tasks: list));
  }

  /// Replace current tasks list (e.g. after loading from a remote source)
  Future<void> replaceAll(List<Task> tasks) async {
    await repo.saveTasks(tasks);
    emit(state.copyWith(tasks: tasks));
  }

  Future<void> deleteTask(String id) async {
    final list = List<Task>.from(state.tasks)..removeWhere((t) => t.id == id);
    await repo.saveTasks(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          writeQueue!.enqueueOp(QueueOp(type: QueueOpType.deleteTask, id: id));
        } else {
          Future<void> op() => remoteRepo!.deleteTask(id);
          unawaited(op());
        }
      }
    }
    emit(state.copyWith(tasks: list));
  }

  void setRemoteRepository(RemoteTaskRepository? r) {
    remoteRepo = r;
  }
}

// helper to allow fire-and-forget when writeQueue not available
void unawaited(Future<void> f) {}
