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
    id: map['id'] as String,
    title: map['title'] as String,
    completed: map['completed'] as bool? ?? false,
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
  final List<SubTask> subTasks;
  final TaskPriority priority;
  final bool completed;
  final String? photoPath;

  const Task({
    required this.id,
    required this.title,
    this.description,
    this.subTasks = const [],
    this.priority = TaskPriority.medium,
    this.completed = false,
    this.photoPath,
  });

  Task copyWith({
    String? id,
    String? title,
    String? description,
    List<SubTask>? subTasks,
    TaskPriority? priority,
    bool? completed,
    String? photoPath,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description ?? this.description,
    subTasks: subTasks ?? this.subTasks,
    priority: priority ?? this.priority,
    completed: completed ?? this.completed,
    photoPath: photoPath ?? this.photoPath,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'description': description,
    'subTasks': subTasks.map((s) => s.toMap()).toList(),
    'priority': priority.index,
    'completed': completed,
    'photoPath': photoPath,
  };

  factory Task.fromMap(Map<String, dynamic> map) => Task(
    id: map['id'] as String,
    title: map['title'] as String,
    description: map['description'] as String?,
    subTasks:
        (map['subTasks'] as List<dynamic>?)
            ?.map((e) => SubTask.fromMap(Map<String, dynamic>.from(e)))
            .toList() ??
        [],
    priority: TaskPriority.values[(map['priority'] as int?) ?? 1],
    completed: map['completed'] as bool? ?? false,
    photoPath: map['photoPath'] as String?,
  );

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) => Task.fromMap(json.decode(source));

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    subTasks,
    priority,
    completed,
    photoPath,
  ];
}
