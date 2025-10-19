import 'dart:convert';

import 'package:equatable/equatable.dart';

enum TaskPriority { low, medium, high, urgent }

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
    this.isHouseholdTask = false,
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
    bool? isHouseholdTask,
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
    isHouseholdTask: isHouseholdTask ?? this.isHouseholdTask,
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
    'repeatRule': repeatRule,
    'repeatDays': repeatDays,
    'isHouseholdTask': isHouseholdTask,
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
    photoPath: map['photoPath'] is String
        ? map['photoPath'] as String
        : (map['photoPath']?.toString()),
    deadline: () {
      final v = map['deadline'];
      if (v is DateTime) return v;
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
    isHouseholdTask,
  ];
}
