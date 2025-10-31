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
    // Load first page by default to support lazy-loading for long lists.
    final tasks = repo.loadTasksPage(offset: 0, limit: 20);
    // Keep track of whether more pages are available via a simple boolean
    // exposed on the state (conservative: if total local tasks > page size).
    final all = repo.loadTasks();
    final hasMore = all.length > tasks.length;
    emit(state.copyWith(tasks: tasks, hasMore: hasMore));
  }

  /// Load a subsequent page of tasks and append to current state.
  Future<void> loadMore({int pageSize = 20}) async {
    final current = state.tasks;
    final next = repo.loadTasksPage(offset: current.length, limit: pageSize);
    if (next.isEmpty) return;
    final merged = List<Task>.from(current)..addAll(next);
    final all = repo.loadTasks();
    final hasMore = all.length > merged.length;
    await repo.saveTasks(merged);
    emit(state.copyWith(tasks: merged, hasMore: hasMore));
  }

  Future<void> addTask(Task task) async {
    // mark as pending locally so UI shows sync status
    final pending = task.copyWith(syncStatus: SyncStatus.pending);
    final list = List<Task>.from(state.tasks)..add(pending);
    await repo.saveTasks(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          // No previous task for new items; include payload only
          final payload = pending.toMap();
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveTask,
              id: pending.id,
              payload: payload,
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
    // When updating, mark local copy as pending until sync completes
    final pending = task.copyWith(syncStatus: SyncStatus.pending);
    final prev = state.tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );
    final list = state.tasks.map((t) => t.id == task.id ? pending : t).toList();
    await repo.saveTasks(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          // Include previous state in payload to allow rollback on persistent failure
          final payload = pending.toMap();
          try {
            payload['_previous'] = prev.toMap();
          } catch (_) {}
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveTask,
              id: pending.id,
              payload: payload,
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
    final prev = state.tasks.firstWhere(
      (t) => t.id == id,
      orElse: () => throw StateError('task'),
    );
    final list = List<Task>.from(state.tasks)..removeWhere((t) => t.id == id);
    await repo.saveTasks(list);
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          // include previous item payload so failure handler can restore
          final payload = <String, dynamic>{};
          try {
            payload['_previous'] = prev.toMap();
          } catch (_) {}
          writeQueue!.enqueueOp(
            QueueOp(type: QueueOpType.deleteTask, id: id, payload: payload),
          );
        } else {
          Future<void> op() => remoteRepo!.deleteTask(id);
          unawaited(op());
        }
      }
    }
    emit(state.copyWith(tasks: list));
  }

  /// Restore a previously-backed-up task map into the local store without
  /// re-enqueueing remote operations. This is used by the write-queue failure
  /// handler to rollback optimistic updates when a persistent remote failure
  /// occurs.
  Future<void> restoreTaskFromMap(Map<String, dynamic> m) async {
    try {
      final t = Task.fromMap(Map<String, dynamic>.from(m));
      final list = List<Task>.from(state.tasks);
      final idx = list.indexWhere((x) => x.id == t.id);
      if (idx != -1) {
        list[idx] = t;
      } else {
        list.add(t);
      }
      await repo.saveTasks(list);
      emit(state.copyWith(tasks: list));
    } catch (_) {}
  }

  /// Mark a task archived locally and persist. This will enqueue a save
  /// so the remote store receives the update when online.
  Future<void> archiveTask(String id) async {
    final t = state.tasks.firstWhere((t) => t.id == id);
    final updated = t.copyWith(archived: true, syncStatus: SyncStatus.pending);
    final list = state.tasks.map((x) => x.id == id ? updated : x).toList();
    await repo.saveTasks(list);
    if (writeQueue != null) {
      final payload = updated.toMap();
      try {
        payload['_previous'] = t.toMap();
      } catch (_) {}
      writeQueue!.enqueueOp(
        QueueOp(type: QueueOpType.saveTask, id: id, payload: payload),
      );
    } else if (remoteRepo != null) {
      unawaited(remoteRepo!.saveTask(updated));
    }
    emit(state.copyWith(tasks: list));
  }

  /// Bulk-delete tasks locally and enqueue delete ops for each. This will
  /// persist local state immediately and queue remote deletes.
  Future<void> bulkDelete(List<String> ids) async {
    final prevs = state.tasks.where((t) => ids.contains(t.id)).toList();
    final list = List<Task>.from(state.tasks)
      ..removeWhere((t) => ids.contains(t.id));
    await repo.saveTasks(list);
    if (writeQueue != null) {
      for (final p in prevs) {
        final payload = <String, dynamic>{};
        try {
          payload['_previous'] = p.toMap();
        } catch (_) {}
        writeQueue!.enqueueOp(
          QueueOp(type: QueueOpType.deleteTask, id: p.id, payload: payload),
        );
      }
    } else if (remoteRepo != null) {
      for (final id in ids) {
        unawaited(remoteRepo!.deleteTask(id));
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

  /// Mark the local task with [taskId] as having a sync failure. This updates
  /// the local repository and emits a new state so the UI can show a failed
  /// sync badge without re-enqueueing the operation.
  Future<void> markTaskSyncFailed(String taskId, String? error) async {
    try {
      final t = state.tasks.firstWhere((t) => t.id == taskId);
      final updated = t.copyWith(
        syncStatus: SyncStatus.failed,
        lastSyncError: error,
        isRetrying: false,
      );
      await repo.updateTask(updated);
      final list = state.tasks
          .map((x) => x.id == taskId ? updated : x)
          .toList();
      emit(state.copyWith(tasks: list));
    } catch (_) {
      // task not found or update failed: ignore silently
    }
  }

  /// Retry syncing a task that previously failed. This updates the local
  /// task status to `syncing` (persisted), emits the new state, and then
  /// re-enqueues the save operation on the WriteQueue (or calls remoteRepo
  /// directly if no queue is attached).
  Future<bool> retryTask(String taskId) async {
    try {
      final t = state.tasks.firstWhere((t) => t.id == taskId);
      final updating = t.copyWith(
        syncStatus: SyncStatus.syncing,
        lastSyncError: null,
        isRetrying: true,
      );
      // persist updated local status
      await repo.updateTask(updating);
      final list = state.tasks
          .map((x) => x.id == taskId ? updating : x)
          .toList();
      emit(state.copyWith(tasks: list));

      final mode = settings?.getSyncMode() ?? SyncMode.sync;
      if (mode == SyncMode.localOnly) return false;

      if (writeQueue != null) {
        // enqueue the operation again using the updated payload
        writeQueue!.enqueueOp(
          QueueOp(
            type: QueueOpType.saveTask,
            id: updating.id,
            payload: updating.toMap(),
          ),
        );
        // show pending until writeQueue processes it and clear isRetrying
        final pending = updating.copyWith(
          syncStatus: SyncStatus.pending,
          isRetrying: false,
        );
        await repo.updateTask(pending);
        final list2 = state.tasks
            .map((x) => x.id == taskId ? pending : x)
            .toList();
        emit(state.copyWith(tasks: list2));
        return true;
      } else if (remoteRepo != null) {
        try {
          await remoteRepo!.saveTask(updating);
          // remoteRepo will cause Firestore snapshot eventually which marks as synced
          // clear isRetrying after direct save succeeded
          final done = updating.copyWith(isRetrying: false);
          await repo.updateTask(done);
          final list3 = state.tasks
              .map((x) => x.id == taskId ? done : x)
              .toList();
          emit(state.copyWith(tasks: list3));
          return true;
        } catch (e) {
          // mark as failed if remote call failed
          await markTaskSyncFailed(taskId, e.toString());
          return false;
        }
      }
    } catch (_) {
      // ignore if task not found
    }
    return false;
  }

  /// Retry all tasks currently marked as failed. Returns the count of
  /// tasks that were successfully started for retry.
  Future<int> retryAllFailed() async {
    final failed = state.tasks
        .where((t) => t.syncStatus == SyncStatus.failed)
        .toList();
    if (failed.isEmpty) return 0;
    var succeeded = 0;
    for (final t in failed) {
      try {
        final ok = await retryTask(t.id);
        if (ok) succeeded++;
      } catch (_) {
        // ignore per-task errors and continue
      }
    }
    return succeeded;
  }
}

// helper to allow fire-and-forget when writeQueue not available
void unawaited(Future<void> f) {}
