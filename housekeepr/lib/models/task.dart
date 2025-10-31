import 'dart:convert';
// Optional import to detect Firestore Timestamp when reading remote docs.
import 'package:cloud_firestore/cloud_firestore.dart' as fs;

import 'package:equatable/equatable.dart';

enum TaskPriority { low, medium, high, urgent }

enum SyncStatus { synced, pending, syncing, failed }

class SubTask extends Equatable {
  final String id;
  final String title;
  final bool completed;

  const SubTask({
    required this.id,
    required this.title,
    this.completed = false,
  });

  SubTask copyWith({String? id, String? title, bool? completed}) => SubTask(
    id: id ?? this.id,
    title: title ?? this.title,
    completed: completed ?? this.completed,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'completed': completed,
  };

  factory SubTask.fromMap(Map<String, dynamic> map) => SubTask(
    id: (map['id'] is String)
        ? map['id'] as String
        : (map['id']?.toString() ?? ''),
    title: (map['title'] is String)
        ? map['title'] as String
        : (map['title']?.toString() ?? ''),
    completed: map['completed'] is bool
        ? map['completed'] as bool
        : (map['completed'] is String
              ? (map['completed'].toLowerCase() == 'true')
              : (map['completed'] is int ? (map['completed'] != 0) : false)),
  );

  String toJson() => json.encode(toMap());

  factory SubTask.fromJson(String source) =>
      SubTask.fromMap(json.decode(source));

  @override
  List<Object?> get props => [id, title, completed];
}

class Task extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? assignedToId;
  final String? assignedToName;
  final List<SubTask> subTasks;
  final TaskPriority priority;
  final bool completed;
  final String? photoPath;
  final DateTime? deadline;
  final bool isRepeating;
  final String? repeatRule; // e.g. 'daily', 'weekly', 'custom', or cron-like
  final List<int>?
  repeatDays; // for weekly repeats: DateTime.weekday values (1=Mon..7=Sun)
  final bool isHouseholdTask;
  final bool archived;
  // For repeating tasks we record per-occurrence completions as ISO date
  // strings (YYYY-MM-DD). This allows marking a repeating task done for a
  // specific day without mutating the repeating template's `completed` flag.
  final List<String>? completedDates;
  // Sync metadata (local-only fields used to show per-item sync state)
  final SyncStatus syncStatus;
  final String? lastSyncError;
  final DateTime? lastSyncedAt;
  final int? localVersion;
  final int? serverVersion;
  final bool isRetrying;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.assignedToId,
    this.assignedToName,
    this.subTasks = const [],
    this.priority = TaskPriority.medium,
    this.completed = false,
    this.photoPath,
    this.deadline,
    this.isRepeating = false,
    this.repeatRule,
    this.repeatDays,
    this.completedDates,
    this.isHouseholdTask = false,
    this.archived = false,
    this.syncStatus = SyncStatus.synced,
    this.lastSyncError,
    this.lastSyncedAt,
    this.localVersion,
    this.serverVersion,
    this.isRetrying = false,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    String? assignedToId,
    String? assignedToName,
    List<SubTask>? subTasks,
    TaskPriority? priority,
    bool? completed,
    String? photoPath,
    DateTime? deadline,
    bool? isRepeating,
    String? repeatRule,
    List<int>? repeatDays,
    List<String>? completedDates,
    bool? isHouseholdTask,
    SyncStatus? syncStatus,
    String? lastSyncError,
    DateTime? lastSyncedAt,
    int? localVersion,
    int? serverVersion,
    bool? isRetrying,
    bool? archived,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    assignedToId: assignedToId ?? this.assignedToId,
    assignedToName: assignedToName ?? this.assignedToName,
    subTasks: subTasks ?? this.subTasks,
    priority: priority ?? this.priority,
    completed: completed ?? this.completed,
    photoPath: photoPath ?? this.photoPath,
    deadline: deadline ?? this.deadline,
    isRepeating: isRepeating ?? this.isRepeating,
    repeatRule: repeatRule ?? this.repeatRule,
    repeatDays: repeatDays ?? this.repeatDays,
    completedDates: completedDates ?? this.completedDates,
    isHouseholdTask: isHouseholdTask ?? this.isHouseholdTask,
    syncStatus: syncStatus ?? this.syncStatus,
    lastSyncError: lastSyncError ?? this.lastSyncError,
    lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
    localVersion: localVersion ?? this.localVersion,
    serverVersion: serverVersion ?? this.serverVersion,
    isRetrying: isRetrying ?? this.isRetrying,
    archived: archived ?? this.archived,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'assigned_to_id': assignedToId,
    'assigned_to_name': assignedToName,
    'subTasks': subTasks.map((s) => s.toMap()).toList(),
    'priority': priority.index,
    'completed': completed,
    'photoPath': photoPath,
    'deadline': deadline?.toUtc().toIso8601String(),
    'isRepeating': isRepeating,
    'completedDates': completedDates,
    'repeatRule': repeatRule,
    'repeatDays': repeatDays,
    'isHouseholdTask': isHouseholdTask,
    'archived': archived,
    'syncStatus': syncStatus.toString().split('.').last,
    'lastSyncError': lastSyncError,
    'lastSyncedAt': lastSyncedAt?.toUtc().toIso8601String(),
    'localVersion': localVersion,
    'serverVersion': serverVersion,
    'isRetrying': isRetrying,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: (map['id'] is String)
        ? map['id'] as String
        : (map['id']?.toString() ?? ''),
    title: (map['title'] is String)
        ? map['title'] as String
        : (map['title']?.toString() ?? ''),
    description: map['description'] is String
        ? map['description'] as String
        : (map['description']?.toString()),
    assignedToId: map['assigned_to_id'] is String
        ? map['assigned_to_id'] as String
        : (map['assigned_to_id']?.toString()),
    assignedToName: map['assigned_to_name'] is String
        ? map['assigned_to_name'] as String
        : (map['assigned_to_name']?.toString()),
    subTasks: (map['subTasks'] is List)
        ? (map['subTasks'] as List<dynamic>)
              .map((e) {
                try {
                  if (e is Map<String, dynamic>) {
                    return SubTask.fromMap(Map<String, dynamic>.from(e));
                  }
                  if (e is String) {
                    return SubTask.fromMap(
                      Map<String, dynamic>.from(json.decode(e) as Map),
                    );
                  }
                } catch (_) {}
                return null;
              })
              .whereType<SubTask>()
              .toList()
        : [],
    priority: () {
      final p = map['priority'];
      if (p is int && p >= 0 && p < TaskPriority.values.length) {
        return TaskPriority.values[p];
      }
      if (p is String) {
        final idx = int.tryParse(p);
        if (idx != null && idx >= 0 && idx < TaskPriority.values.length) {
          return TaskPriority.values[idx];
        }
        // try matching by name
        final byName = TaskPriority.values.firstWhere(
          (v) => v.toString().split('.').last.toLowerCase() == p.toLowerCase(),
          orElse: () => TaskPriority.medium,
        );
        return byName;
      }
      return TaskPriority.medium;
    }(),
    completed: map['completed'] is bool
        ? map['completed'] as bool
        : (map['completed'] is String
              ? (map['completed'].toLowerCase() == 'true')
              : (map['completed'] is int ? (map['completed'] != 0) : false)),
    completedDates: () {
      final cd = map['completedDates'];
      if (cd is List) return cd.whereType<String>().toList();
      if (cd is String && cd.isNotEmpty) {
        try {
          final parsed = json.decode(cd);
          if (parsed is List) return parsed.whereType<String>().toList();
        } catch (_) {}
      }
      return null;
    }(),
    photoPath: map['photoPath'] is String
        ? map['photoPath'] as String
        : (map['photoPath']?.toString()),
    deadline: () {
      final v = map['deadline'];
      if (v is DateTime) return v;
      // Firestore Timestamp
      try {
        if (v is fs.Timestamp) return v.toDate().toUtc();
      } catch (_) {}
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v).toUtc();
        } catch (_) {}
      }
      return null;
    }(),
    isRepeating: map['isRepeating'] is bool
        ? map['isRepeating'] as bool
        : (map['isRepeating'] is String
              ? (map['isRepeating'].toLowerCase() == 'true')
              : false),
    repeatRule: map['repeatRule'] is String
        ? map['repeatRule'] as String
        : (map['repeatRule']?.toString()),
    repeatDays: () {
      final rd = map['repeatDays'];
      if (rd is List) {
        return rd.whereType<int>().toList();
      }
      if (rd is String && rd.isNotEmpty) {
        try {
          final parsed = json.decode(rd);
          if (parsed is List) return parsed.whereType<int>().toList();
        } catch (_) {}
      }
      return null;
    }(),
    isHouseholdTask: map['isHouseholdTask'] is bool
        ? map['isHouseholdTask'] as bool
        : (map['isHouseholdTask'] is String
              ? (map['isHouseholdTask'].toLowerCase() == 'true')
              : false),
    archived: map['archived'] is bool
        ? map['archived'] as bool
        : (map['archived'] is String
              ? (map['archived'].toLowerCase() == 'true')
              : false),
    syncStatus: () {
      final s = map['syncStatus'];
      if (s is String) {
        final name = s.toLowerCase();
        for (final v in SyncStatus.values) {
          if (v.toString().split('.').last.toLowerCase() == name) return v;
        }
      }
      return SyncStatus.synced;
    }(),
    lastSyncError: map['lastSyncError'] is String
        ? map['lastSyncError'] as String
        : (map['lastSyncError']?.toString()),
    lastSyncedAt: () {
      final v = map['lastSyncedAt'];
      if (v is DateTime) return v;
      // Firestore Timestamp
      try {
        if (v is fs.Timestamp) return v.toDate().toUtc();
      } catch (_) {}
      if (v is String && v.isNotEmpty) {
        try {
          return DateTime.parse(v).toUtc();
        } catch (_) {}
      }
      return null;
    }(),
    localVersion: () {
      final v = map['localVersion'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }(),
    serverVersion: () {
      final v = map['serverVersion'];
      if (v is int) return v;
      if (v is String) return int.tryParse(v);
      return null;
    }(),
    isRetrying: map['isRetrying'] is bool
        ? map['isRetrying'] as bool
        : (map['isRetrying'] is String
              ? (map['isRetrying'].toLowerCase() == 'true')
              : false),
  );

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    assignedToId,
    assignedToName,
    subTasks,
    priority,
    completed,
    photoPath,
    deadline,
    isRepeating,
    repeatRule,
    repeatDays,
    completedDates,
    isHouseholdTask,
    archived,
    syncStatus,
    lastSyncError,
    lastSyncedAt,
    localVersion,
    serverVersion,
    isRetrying,
  ];
}
