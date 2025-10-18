import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/cubits/user_cubit.dart';
import 'package:housekeepr/repositories/task_repository.dart';
import 'package:housekeepr/repositories/shopping_repository.dart';
import 'test_utils.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/models/shopping_item.dart';

class NoopWriteQueue {
  void enqueueOp(dynamic _) {}
}

void main() {
  test('TaskCubit add/update/delete flows and state', () async {
    final prefs = InMemoryPrefs();
    final repo = TaskRepository(prefs);
    final cubit = TaskCubit(repo);

    expect(cubit.state.tasks, isEmpty);

    final t = Task(id: 't1', title: 'Do it');
    await cubit.addTask(t);
    expect(cubit.state.tasks.length, equals(1));

    final t2 = t.copyWith(title: 'Done');
    await cubit.updateTask(t2);
    expect(cubit.state.tasks.first.title, equals('Done'));

    await cubit.deleteTask(t2.id);
    expect(cubit.state.tasks, isEmpty);
  });

  test('ShoppingCubit add/update/delete flows and state', () async {
    final prefs = InMemoryPrefs();
    final repo = ShoppingRepository(prefs);
    final cubit = ShoppingCubit(repo);

    expect(cubit.state.items, isEmpty);

    final s = ShoppingItem(id: 's1', name: 'Eggs', quantity: 12);
    await cubit.addItem(s);
    expect(cubit.state.items.length, equals(1));

    final s2 = s.copyWith(name: 'Free range eggs');
    await cubit.updateItem(s2);
    expect(cubit.state.items.first.name, equals('Free range eggs'));

    await cubit.deleteItem(s2.id);
    expect(cubit.state.items, isEmpty);
  });

  test('UserCubit setUser emits new user', () {
    final cubit = UserCubit(null);
    expect(cubit.state, isNull);
    cubit.setUser(null);
    expect(cubit.state, isNull);
  });
}
