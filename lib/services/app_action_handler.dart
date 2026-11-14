import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/ui/features/profile/pages/widget_settings_page.dart';
import 'package:housekeepr/ui/features/tools/pages/medication_reminders_page.dart';
import 'package:housekeepr/ui/features/tools/widgets/coffee_picker_page.dart';

class AppActionHandler {
  static final AppActionHandler _instance = AppActionHandler._internal();
  factory AppActionHandler() => _instance;
  AppActionHandler._internal();

  static const _widgetActionsChannel = MethodChannel(
    'housekeepr/widget_actions',
  );

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

    // 3. Handle Android APPWIDGET_CONFIGURE launch context
    checkWidgetConfigContext(context);
  }

  Future<void> checkWidgetConfigContext(BuildContext context) async {
    try {
      final result = await _widgetActionsChannel
          .invokeMapMethod<String, dynamic>('getWidgetConfigContext');
      if (result == null || !context.mounted) return;
      final isWidgetConfig = result['isWidgetConfig'] == true;
      final appWidgetId = result['appWidgetId'] as int?;
      final section = result['section'] as String?;
      if (!isWidgetConfig || appWidgetId == null) return;

      final Widget page = switch (section) {
        'pill' => PillWidgetSettingsPage(appWidgetId: appWidgetId),
        'shopping' => ShoppingWidgetSettingsPage(appWidgetId: appWidgetId),
        'coffee' => CoffeeWidgetSettingsPage(appWidgetId: appWidgetId),
        _ => WidgetSettingsPage(appWidgetId: appWidgetId),
      };
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } catch (e) {
      debugPrint('Error checking widget config context: $e');
    }
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
    } else if (uri.host == 'medications') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MedicationRemindersPage()),
      );
    } else if (uri.host == 'widget-settings') {
      final appWidgetId = int.tryParse(queryParams['appWidgetId'] ?? '');
      final Widget page = switch (path) {
        '/pill' => PillWidgetSettingsPage(appWidgetId: appWidgetId),
        '/shopping' => ShoppingWidgetSettingsPage(appWidgetId: appWidgetId),
        '/coffee' => CoffeeWidgetSettingsPage(appWidgetId: appWidgetId),
        _ => WidgetSettingsPage(appWidgetId: appWidgetId),
      };
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
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
