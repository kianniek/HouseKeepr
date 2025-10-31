part of 'task_cubit.dart';

class TaskState extends Equatable {
  final List<Task> tasks;
  final bool hasMore;

  const TaskState({this.tasks = const [], this.hasMore = false});

  factory TaskState.initial() => const TaskState(tasks: []);

  TaskState copyWith({List<Task>? tasks, bool? hasMore}) =>
      TaskState(tasks: tasks ?? this.tasks, hasMore: hasMore ?? this.hasMore);

  @override
  List<Object?> get props => [tasks];
}
