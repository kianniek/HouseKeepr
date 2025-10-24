import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import '../models/task.dart';
import '../repositories/task_repository.dart';
import '../firestore/remote_task_repository.dart';
import '../core/settings_repository.dart';
import '../core/sync_mode.dart';
import '../services/write_queue.dart';
import '../repositories/history_repository.dart';
import '../models/completion_record.dart';

part 'task_state.dart';

class TaskCubit extends Cubit<TaskState> {
  final TaskRepository repo;
  RemoteTaskRepository? remoteRepo;
  final SettingsRepository? settings;
  WriteQueue? writeQueue;
  HistoryRepository? historyRepo;

  TaskCubit(this.repo, {this.settings, this.writeQueue, this.historyRepo})
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

  /// Attach a WriteQueue and HistoryRepository so the cubit can enqueue
  /// remote history ops. This is called during app initialization.
  void attachWriteQueueAndHistory(WriteQueue? wq, HistoryRepository? hr) {
    // keep references for use when creating completion history ops
    // (we already store writeQueue in the constructor field)
    // historyRepo is also stored in the constructor field; if called after
    // construction, set it here for later use.
    if (wq != null) {
      // replace the writeQueue reference
      // ignore: prefer_final_fields
      writeQueue = wq;
    }
    if (hr != null) historyRepo = hr;
  }

  /// Mark a repeating occurrence as completed for [date] (YYYY-MM-DD, UTC).
  Future<void> completeOccurrence(
    String taskId,
    String date, {
    String? completedBy,
  }) async {
    if (historyRepo != null) {
      final rec = CompletionRecord(
        taskId: taskId,
        date: date,
        completedBy: completedBy,
      );
      await historyRepo!.add(rec);
      final mode = settings?.getSyncMode() ?? SyncMode.sync;
      if (mode != SyncMode.localOnly) {
        // enqueue remote save via writeQueue if available
        if (writeQueue != null) {
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveHistory,
              id: rec.id,
              payload: rec.toMap(),
            ),
          );
        } else if (remoteRepo != null) {
          // If no writeQueue but remoteRepo present, attempt direct remote save
          // remoteRepo may not know how to save history; callers should attach
        }
      }
    }
    // also update task.completedDates for convenience
    final t = state.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('task'),
    );
    final current = List<String>.from(t.completedDates ?? <String>[]);
    if (!current.contains(date)) current.add(date);
    await updateTask(t.copyWith(completedDates: current));
  }

  Future<void> uncompleteOccurrence(String taskId, String date) async {
    // remove history records for that task/date
    if (historyRepo != null) {
      final recs = historyRepo!.forTaskOnDate(taskId, date);
      for (final r in recs) {
        await historyRepo!.remove(r.id);
        final mode = settings?.getSyncMode() ?? SyncMode.sync;
        if (mode != SyncMode.localOnly) {
          if (writeQueue != null) {
            writeQueue!.enqueueOp(
              QueueOp(type: QueueOpType.deleteHistory, id: r.id),
            );
          }
        }
      }
    }
    final t = state.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('task'),
    );
    final current = List<String>.from(t.completedDates ?? <String>[]);
    current.remove(date);
    await updateTask(t.copyWith(completedDates: current));
  }
}

// helper to allow fire-and-forget when writeQueue not available
void unawaited(Future<void> f) {}
