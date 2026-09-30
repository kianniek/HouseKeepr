import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/ui/features/tools/widgets/coffee_picker_page.dart';

class AppActionHandler {
  static final AppActionHandler _instance = AppActionHandler._internal();
  factory AppActionHandler() => _instance;
  AppActionHandler._internal();

  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void init(BuildContext context) {
    _appLinks = AppLinks();

    // 1. Handle deep link when the app was launched from terminated state
    _appLinks.getInitialLink().then((uri) {
      if (uri != null && context.mounted) {
        _processUri(context, uri);
      }
    });

    // 2. Handle deep link when the app is in background/foreground
    _linkSubscription = _appLinks.uriLinkStream.listen(
      (uri) {
        if (context.mounted) {
          _processUri(context, uri);
        }
      },
      onError: (err) {
        debugPrint('AppActionHandler deep link error: $err');
      },
    );
  }

  void _processUri(BuildContext context, Uri uri) {
    debugPrint('Received App Action URI: $uri');

    if (uri.scheme != 'housekeepr') return;

    final path = uri.path;
    final queryParams = uri.queryParameters;

    if (uri.host == 'shopping' && path == '/add') {
      final itemName = queryParams['item_name'];
      if (itemName != null && itemName.isNotEmpty) {
        _addShoppingItem(context, itemName);
      }
    } else if (uri.host == 'tasks' && path == '/add') {
      final taskName = queryParams['task_name'];
      if (taskName != null && taskName.isNotEmpty) {
        _createTask(context, taskName);
      }
    } else if (uri.host == 'coffee' && path.startsWith('/recipe/')) {
      final recipeId = path.substring('/recipe/'.length);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CoffeePickerPage(recipeId: recipeId)),
      );
    }
  }

  void _addShoppingItem(BuildContext context, String itemName) {
    final shoppingCubit = context.read<ShoppingCubit>();
    shoppingCubit.addItem(itemName);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added "$itemName" to shopping list via Assistant'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _createTask(
    BuildContext context,
    String taskTitle, {
    String? taskDescription,
  }) {
    final taskCubit = context.read<TaskCubit>();
    final now = DateTime.now();

    final newTask = Task(
      id: now.millisecondsSinceEpoch.toString(),
      title: taskTitle,
      description: taskDescription,
      completed: false,
      isHouseholdTask: true,
    );

    taskCubit.addTask(newTask);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created task "$taskTitle" via Assistant'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
