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
import '../services/recurrence_generator.dart';
import '../services/notification_service.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

part 'task_state.dart';

class TaskCubit extends Cubit<TaskState> {
  final TaskRepository repo;
  RemoteTaskRepository? remoteRepo;
  final SettingsRepository? settings;
  WriteQueue? writeQueue;
  HistoryRepository? historyRepo;
  StreamSubscription<QuerySnapshot>? _tasksSubscription;

  // Track IDs of tasks that have been deleted locally but might still
  // exist on the server temporarily.
  final Set<String> _pendingDeletes = {};

  Future<void>? initializationFuture;

  TaskCubit(this.repo, {this.settings, this.writeQueue, this.historyRepo})
    : super(TaskState.initial()) {
    initializationFuture = load();
  }

  Future<void> load() async {
    final tasks = repo.loadTasksPage(offset: 0, limit: 20);
    final all = repo.loadTasks();
    final hasMore = all.length > tasks.length;

    emit(state.copyWith(tasks: tasks, hasMore: hasMore));

    try {
      final now = DateTime.now();
      final to = now.add(const Duration(days: 90));
      await repo.materializeOccurrences(from: now, to: to);
    } catch (_) {}
  }

  Future<void> loadMore({int pageSize = 20}) async {
    final current = state.tasks;
    final next = repo.loadTasksPage(offset: current.length, limit: pageSize);
    if (next.isEmpty) return;

    final merged = List<Task>.from(current)..addAll(next);
    final all = repo.loadTasks();
    final hasMore = all.length > merged.length;

    emit(state.copyWith(tasks: merged, hasMore: hasMore));
  }

  Future<void> addTask(Task task) async {
    // If we are re-adding a task (e.g. undoing a delete), clear the pending delete flag
    _pendingDeletes.remove(task.id);

    final pending = task.copyWith(syncStatus: SyncStatus.pending);
    final list = List<Task>.from(state.tasks)..add(pending);
    await repo.saveTasks(list);

    try {
      NotificationService.instance.show('Task created', task.title);
      if (pending.deadline != null && pending.reminderEnabled) {
        final offset = pending.reminderOffsetMinutes ?? 0;
        final scheduled = pending.deadline!.toUtc().subtract(
          Duration(minutes: offset),
        );
        final now = DateTime.now().toUtc();
        if (!scheduled.isBefore(now)) {
          NotificationService.instance.scheduleReminder(
            pending.id,
            scheduled,
            title: 'Task due',
            body: pending.title,
            priorityLevel: pending.priority.index,
          );
        }
      }
    } catch (_) {}
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
          final payload = pending.toMap();
          try {
            payload['_isNew'] = true;
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

  Future<void> removeLocalTask(String id) async {
    try {
      final list = List<Task>.from(state.tasks)..removeWhere((t) => t.id == id);
      await repo.saveTasks(list);
      emit(state.copyWith(tasks: list));
    } catch (_) {}
  }

  Future<void> updateTask(Task task) async {
    final pending = task.copyWith(syncStatus: SyncStatus.pending);
    final prev = state.tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );
    final list = state.tasks.map((t) => t.id == task.id ? pending : t).toList();

    // Optimistic UI update: emit immediately so the item moves in the UI
    // as soon as the user toggles the checkbox.
    emit(state.copyWith(tasks: list));

    // Persist in background; if persistence fails we'll still have shown the
    // optimistic update. Persisting errors are swallowed to avoid crashing
    // the UI flow here.
    try {
      await repo.saveTasks(list);
    } catch (_) {}

    try {
      NotificationService.instance.show('Task updated', task.title);
      await NotificationService.instance.cancelReminder(task.id);
      if (pending.deadline != null && pending.reminderEnabled) {
        final offset = pending.reminderOffsetMinutes ?? 0;
        final scheduled = pending.deadline!.toUtc().subtract(
          Duration(minutes: offset),
        );
        final now = DateTime.now().toUtc();
        if (!scheduled.isBefore(now)) {
          await NotificationService.instance.scheduleReminder(
            pending.id,
            scheduled,
            title: 'Task due',
            body: task.title,
            priorityLevel: pending.priority.index,
          );
        }
      }
    } catch (_) {}
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
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
    // Ensure final persisted list is emitted (may be redundant but keeps
    // state consistent with other flows that emit after persistence).
    emit(state.copyWith(tasks: list));
  }

  Future<void> replaceAll(List<Task> tasks) async {
    try {
      debugPrint('TaskCubit.replaceAll called with ${tasks.length} tasks');

      // Filter out tasks that are pending deletion.
      // This prevents the server stream from resurrecting tasks that we just deleted locally
      // but haven't been deleted on the server yet.
      final filteredTasks = tasks
          .where((t) => !_pendingDeletes.contains(t.id))
          .toList();

      // Clean up _pendingDeletes: if an ID is in _pendingDeletes but NOT in the incoming 'tasks'
      // list (meaning it's gone from the server too), we can stop tracking it.
      _pendingDeletes.removeWhere((id) => !tasks.any((t) => t.id == id));

      await repo.saveTasks(filteredTasks);
      debugPrint(
        'TaskCubit.replaceAll: Emitting state with ${filteredTasks.length} items',
      );
      emit(state.copyWith(tasks: filteredTasks));
    } catch (e, st) {
      debugPrint('TaskCubit.replaceAll ERROR: $e$st');
      // If save/filter fails, try to just emit what we have
      try {
        emit(state.copyWith(tasks: tasks));
      } catch (_) {}
    }
  }

  Future<void> deleteTask(String id) async {
    // Mark as pending delete so sync service ignores it if it comes back
    _pendingDeletes.add(id);

    final prev = state.tasks.firstWhere(
      (t) => t.id == id,
      orElse: () => throw StateError('task'),
    );
    final list = List<Task>.from(state.tasks)..removeWhere((t) => t.id == id);
    await repo.saveTasks(list);
    try {
      NotificationService.instance.show('Task deleted', id);
      await NotificationService.instance.cancelReminder(id);
    } catch (_) {}
    final mode = settings?.getSyncMode() ?? SyncMode.sync;
    if (mode != SyncMode.localOnly) {
      if (remoteRepo != null) {
        if (writeQueue != null) {
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

  Future<void> restoreTaskFromMap(Map<String, dynamic> m) async {
    try {
      final t = Task.fromMap(Map<String, dynamic>.from(m));
      // If we are restoring, unmark it from pending deletes
      _pendingDeletes.remove(t.id);

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

  Future<void> bulkDelete(List<String> ids) async {
    // Add all to pending deletes
    _pendingDeletes.addAll(ids);

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

  Future<void> bulkArchive(List<String> ids) async {
    final prevs = state.tasks.where((t) => ids.contains(t.id)).toList();
    final list = state.tasks
        .map(
          (t) => ids.contains(t.id)
              ? t.copyWith(archived: true, syncStatus: SyncStatus.pending)
              : t,
        )
        .toList();
    await repo.saveTasks(list);
    if (writeQueue != null) {
      for (final p in prevs) {
        final updated = p.copyWith(
          archived: true,
          syncStatus: SyncStatus.pending,
        );
        final payload = updated.toMap();
        try {
          payload['_previous'] = p.toMap();
        } catch (_) {}
        writeQueue!.enqueueOp(
          QueueOp(type: QueueOpType.saveTask, id: updated.id, payload: payload),
        );
      }
    } else if (remoteRepo != null) {
      for (final id in ids) {
        final t = list.firstWhere((x) => x.id == id);
        unawaited(remoteRepo!.saveTask(t));
      }
    }
    emit(state.copyWith(tasks: list));
  }

  void setRemoteRepository(RemoteTaskRepository? r) {
    remoteRepo = r;
  }

  void subscribeToTasksStream(Stream<QuerySnapshot> tasksStream) {
    _tasksSubscription?.cancel();
    _tasksSubscription = tasksStream.listen((snapshot) async {
      try {
        final items = snapshot.docs
            .map((d) => Task.fromMap(d.data() as Map<String, dynamic>))
            .toList();

        // Apply pendinng deletes filter here too just in case
        final filtered = items
            .where((t) => !_pendingDeletes.contains(t.id))
            .toList();
        _pendingDeletes.removeWhere((id) => !items.any((t) => t.id == id));

        await repo.saveTasks(filtered);
        emit(state.copyWith(tasks: filtered));
      } catch (_) {}
    });
  }

  @override
  Future<void> close() {
    _tasksSubscription?.cancel();
    return super.close();
  }

  // --- CHANGED METHOD ---
  void attachWriteQueueAndHistory(WriteQueue? wq, HistoryRepository? hr) {
    if (wq != null) {
      writeQueue = wq;
      // Pre-fill pending deletes from the persistent queue to prevent
      // resurrection of deleted tasks on app restart.
      final queuedDeletes = wq.getPendingDeleteTaskIds();
      if (queuedDeletes.isNotEmpty) {
        debugPrint(
          'TaskCubit: Restored ${queuedDeletes.length} pending deletes from queue',
        );
        _pendingDeletes.addAll(queuedDeletes);
      }
    }
    if (hr != null) historyRepo = hr;
  }
  // ----------------------

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
        if (writeQueue != null) {
          writeQueue!.enqueueOp(
            QueueOp(
              type: QueueOpType.saveHistory,
              id: rec.id,
              payload: rec.toMap(),
            ),
          );
        }
      }
    }
    final t = state.tasks.firstWhere(
      (t) => t.id == taskId,
      orElse: () => throw StateError('task'),
    );
    final current = List<String>.from(t.completedDates ?? <String>[]);
    if (!current.contains(date)) current.add(date);
    await updateTask(t.copyWith(completedDates: current));
    try {
      NotificationService.instance.show('Task completed', '${t.title} — $date');
      await NotificationService.instance.cancelReminder(taskId);
    } catch (_) {}
  }

  Future<void> uncompleteOccurrence(String taskId, String date) async {
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
    try {
      NotificationService.instance.show(
        'Task uncompleted',
        '${t.title} — $date',
      );
    } catch (_) {}
  }

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
    } catch (_) {}
  }

  Future<bool> retryTask(String taskId) async {
    try {
      final t = state.tasks.firstWhere((t) => t.id == taskId);
      final updating = t.copyWith(
        syncStatus: SyncStatus.syncing,
        lastSyncError: null,
        isRetrying: true,
      );
      await repo.updateTask(updating);
      final list = state.tasks
          .map((x) => x.id == taskId ? updating : x)
          .toList();
      emit(state.copyWith(tasks: list));

      final mode = settings?.getSyncMode() ?? SyncMode.sync;
      if (mode == SyncMode.localOnly) return false;

      if (writeQueue != null) {
        writeQueue!.enqueueOp(
          QueueOp(
            type: QueueOpType.saveTask,
            id: updating.id,
            payload: updating.toMap(),
          ),
        );
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
          final done = updating.copyWith(isRetrying: false);
          await repo.updateTask(done);
          final list3 = state.tasks
              .map((x) => x.id == taskId ? done : x)
              .toList();
          emit(state.copyWith(tasks: list3));
          return true;
        } catch (e) {
          await markTaskSyncFailed(taskId, e.toString());
          return false;
        }
      }
    } catch (_) {}
    return false;
  }

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
      } catch (_) {}
    }
    return succeeded;
  }
}

void unawaited(Future<void> f) {}
