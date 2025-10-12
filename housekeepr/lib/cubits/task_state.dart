part of 'task_cubit.dart';

class TaskState extends Equatable {
  final List<Task> tasks;

  const TaskState({this.tasks = const []});

  factory TaskState.initial() => const TaskState(tasks: []);

  TaskState copyWith({List<Task>? tasks}) =>
      TaskState(tasks: tasks ?? this.tasks);

  @override
  List<Object?> get props => [tasks];
}
