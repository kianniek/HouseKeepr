import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:health_keepr/health_keepr.dart';
import 'package:housekeepr/core/grocery_parser.dart';
import 'package:housekeepr/cubits/shopping_cubit.dart';
import 'package:housekeepr/cubits/task_cubit.dart';
import 'package:housekeepr/generated/app_localizations.dart';
import 'package:housekeepr/home_screen.dart';
import 'package:housekeepr/main.dart';
import 'package:housekeepr/models/task.dart';
import 'package:housekeepr/services/app_haptics.dart';
import 'package:housekeepr/services/notification_service.dart';
import 'package:housekeepr/services/recipe_import_service.dart';
import 'package:housekeepr/ui/common/widgets/bulk_import_confirmation_dialog.dart';
import 'package:housekeepr/ui/common/widgets/bulk_import_dialog.dart';
import 'package:housekeepr/ui/features/profile/pages/widget_settings_page.dart';
import 'package:housekeepr/ui/features/shopping/widgets/recipe_import_dialog.dart';
import 'package:housekeepr/ui/features/tasks/widgets/task_add_dialog.dart';
import 'package:housekeepr/ui/features/tools/pages/medication_reminders_page.dart';
import 'package:housekeepr/ui/features/tools/widgets/coffee_picker_page.dart';

enum ShareTargetAction {
  recipeUrl,
  shoppingBulk,
  shoppingSingle,
  createTask,
  askUser,
}

class ShareRoutingPlan {
  final ShareTargetAction action;
  final String? extractedUrl;
  final List<String> lines;
  final String? taskTitle;
  final String? taskDescription;

  const ShareRoutingPlan({
    required this.action,
    this.extractedUrl,
    this.lines = const <String>[],
    this.taskTitle,
    this.taskDescription,
  });
}

class AppActionHandler {
  static final AppActionHandler _instance = AppActionHandler._internal();
  factory AppActionHandler() => _instance;
  AppActionHandler._internal();

  static const _widgetActionsChannel = MethodChannel(
    'housekeepr/widget_actions',
  );
  static const _shareIntentsChannel = MethodChannel('housekeepr/share_intents');
  static final RegExp _urlRegex = RegExp(
    r'https?://[^\s<>()]+',
    caseSensitive: false,
  );

  AppLinks? _appLinks;
  StreamSubscription<Uri>? _linkSubscription;
  BuildContext? _hostContext;
  bool _shareHandlerRegistered = false;

  void init(BuildContext context) {
    _hostContext = context;
    _appLinks ??= AppLinks();

    // 1. Handle deep link when the app was launched from terminated state
    _appLinks!.getInitialLink().then((uri) {
      if (uri != null && context.mounted) {
        _processUri(context, uri);
      }
    });

    // 2. Handle deep link when the app is in background/foreground
    _linkSubscription?.cancel();
    _linkSubscription = _appLinks!.uriLinkStream.listen(
      (uri) {
        final ctx = _hostContext;
        if (ctx != null && ctx.mounted) {
          _processUri(ctx, uri);
        }
      },
      onError: (err) {
        debugPrint('AppActionHandler deep link error: $err');
      },
    );

    // 3. Handle Android APPWIDGET_CONFIGURE launch context
    checkWidgetConfigContext(context);

    // 4. Handle inbound ACTION_SEND share intents & direct share targets
    _initShareIntents(context);
  }

  void _initShareIntents(BuildContext context) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    if (!_shareHandlerRegistered) {
      _shareHandlerRegistered = true;
      _shareIntentsChannel.setMethodCallHandler((call) async {
        if (call.method == 'onShareReceived' && call.arguments is Map) {
          final ctx = _hostContext;
          if (ctx == null || !ctx.mounted) return;
          final map = Map<String, dynamic>.from(call.arguments as Map);
          final text = map['text'] as String?;
          if (text == null || text.trim().isEmpty) return;
          await handleSharedText(
            ctx,
            text: text,
            subject: map['subject'] as String?,
            shortcutId: map['shortcutId'] as String?,
          );
        }
      });
    }

    unawaited(_checkPendingShare(context));
  }

  Future<void> _checkPendingShare(BuildContext context) async {
    try {
      final result = await _shareIntentsChannel
          .invokeMapMethod<String, dynamic>('getPendingShare');
      if (result == null || !context.mounted) return;
      final text = result['text'] as String?;
      if (text == null || text.trim().isEmpty) return;
      await handleSharedText(
        context,
        text: text,
        subject: result['subject'] as String?,
        shortcutId: result['shortcutId'] as String?,
      );
    } catch (e) {
      debugPrint('Error checking pending share intent: $e');
    }
  }

  /// Extracts the first `http://` or `https://` URL from arbitrary shared text,
  /// stripping trailing sentence punctuation.
  @visibleForTesting
  static String? extractFirstUrl(String text) {
    final match = _urlRegex.firstMatch(text);
    if (match == null) return null;
    var candidate = match.group(0)!;
    while (candidate.isNotEmpty &&
        RegExp(r'[.,;:!?\)\]]').hasMatch(candidate[candidate.length - 1])) {
      candidate = candidate.substring(0, candidate.length - 1);
    }
    return RecipeImportService.isRecipeUrl(candidate) ? candidate : null;
  }

  /// Pure classification helper for inbound `ACTION_SEND` text shares.
  @visibleForTesting
  static ShareRoutingPlan classifyShareInput({
    required String text,
    String? subject,
    String? shortcutId,
  }) {
    final trimmed = text.trim();
    final lines = trimmed
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final extractedUrl = extractFirstUrl(trimmed);
    final trimmedSubject = subject?.trim();

    final inferredTitle = (trimmedSubject != null && trimmedSubject.isNotEmpty)
        ? trimmedSubject
        : (lines.isNotEmpty ? lines.first : trimmed);
    final String? inferredDescription;
    if (trimmedSubject != null && trimmedSubject.isNotEmpty) {
      inferredDescription = trimmed.isNotEmpty ? trimmed : null;
    } else if (lines.length > 1) {
      inferredDescription = lines.skip(1).join('\n');
    } else if (extractedUrl != null && inferredTitle != extractedUrl) {
      inferredDescription = extractedUrl;
    } else {
      inferredDescription = null;
    }

    if (shortcutId == 'quick_add_shopping') {
      if (extractedUrl != null) {
        return ShareRoutingPlan(
          action: ShareTargetAction.recipeUrl,
          extractedUrl: extractedUrl,
          lines: lines,
          taskTitle: inferredTitle,
          taskDescription: inferredDescription,
        );
      }
      if (lines.length >= 2) {
        return ShareRoutingPlan(
          action: ShareTargetAction.shoppingBulk,
          lines: lines,
          taskTitle: inferredTitle,
          taskDescription: inferredDescription,
        );
      }
      return ShareRoutingPlan(
        action: ShareTargetAction.shoppingSingle,
        lines: lines.isEmpty ? <String>[trimmed] : lines,
        taskTitle: inferredTitle,
        taskDescription: inferredDescription,
      );
    }

    if (shortcutId == 'quick_add_task') {
      return ShareRoutingPlan(
        action: ShareTargetAction.createTask,
        extractedUrl: extractedUrl,
        lines: lines,
        taskTitle: inferredTitle,
        taskDescription: inferredDescription,
      );
    }

    return ShareRoutingPlan(
      action: ShareTargetAction.askUser,
      extractedUrl: extractedUrl,
      lines: lines,
      taskTitle: inferredTitle,
      taskDescription: inferredDescription,
    );
  }

  Future<void> handleSharedText(
    BuildContext context, {
    required String text,
    String? subject,
    String? shortcutId,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !context.mounted) return;

    final plan = classifyShareInput(
      text: trimmed,
      subject: subject,
      shortcutId: shortcutId,
    );

    if (plan.action == ShareTargetAction.askUser) {
      final l10n = AppLocalizations.of(context);
      final chosenTarget = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (sheetCtx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  l10n.shareActionTitle,
                  style: Theme.of(sheetCtx).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: Icon(
                  plan.extractedUrl != null
                      ? Icons.restaurant_menu
                      : Icons.shopping_cart_outlined,
                ),
                title: Text(
                  plan.extractedUrl != null
                      ? l10n.shareImportRecipe
                      : l10n.shareToShoppingList,
                ),
                subtitle: Text(
                  plan.extractedUrl ?? trimmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(sheetCtx, 'quick_add_shopping'),
              ),
              ListTile(
                leading: const Icon(Icons.task_alt),
                title: Text(l10n.shareCreateTask),
                subtitle: Text(
                  plan.taskTitle ?? trimmed,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.pop(sheetCtx, 'quick_add_task'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
      if (chosenTarget == null || !context.mounted) return;
      await handleSharedText(
        context,
        text: trimmed,
        subject: subject,
        shortcutId: chosenTarget,
      );
      return;
    }

    navigatorKey.currentState?.popUntil((route) => route.isFirst);
    if (!context.mounted) return;

    switch (plan.action) {
      case ShareTargetAction.recipeUrl:
        homeScreenKey.currentState?.selectTab(HomeTab.shopping);
        final cubit = context.read<ShoppingCubit>();
        final result = await showRecipeImportDialog(
          context,
          initialUrl: plan.extractedUrl,
        );
        if (result == null || !context.mounted) return;
        await cubit.addRecipe(
          title: result.title,
          url: result.url,
          sourceName: result.sourceName,
          servings: result.servings,
          imageUrl: result.imageUrl,
          ingredients: result.ingredients,
        );
        AppHaptics.instance.confirm();
      case ShareTargetAction.shoppingBulk:
        homeScreenKey.currentState?.selectTab(HomeTab.shopping);
        final cubit = context.read<ShoppingCubit>();
        final parsedItems = await showBulkImportDialog(
          context,
          initialText: plan.lines.join('\n'),
        );
        if (parsedItems == null || parsedItems.isEmpty || !context.mounted) {
          return;
        }
        final confirmed = await showBulkImportConfirmationDialog(
          context,
          parsedItems,
        );
        if (confirmed == null || confirmed.isEmpty || !context.mounted) return;
        await cubit.addItems(confirmed);
        AppHaptics.instance.confirm();
      case ShareTargetAction.shoppingSingle:
        homeScreenKey.currentState?.selectTab(HomeTab.shopping);
        final rawLine = plan.lines.isNotEmpty ? plan.lines.first : trimmed;
        final parsed = GroceryParser.parseLine(rawLine);
        if (parsed.name.isEmpty) return;
        context.read<ShoppingCubit>().addItem(
          parsed.name,
          note: parsed.note,
          quantity: parsed.hasExplicitQuantity ? parsed.quantity : null,
          unit: parsed.hasExplicitQuantity ? parsed.unit : null,
          category: parsed.category,
        );
        AppHaptics.instance.confirm();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${parsed.name}" to shopping list'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      case ShareTargetAction.createTask:
        homeScreenKey.currentState?.selectTab(HomeTab.tasks);
        await showTaskAddEditDialog(
          context,
          initialTitle: plan.taskTitle,
          initialDescription: plan.taskDescription,
        );
      case ShareTargetAction.askUser:
        break;
    }
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

      final Widget page = _buildWidgetSettingsPage(section, appWidgetId);
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
    } catch (e) {
      debugPrint('Error checking widget config context: $e');
    }
  }

  Widget _buildWidgetSettingsPage(String? section, int? appWidgetId) {
    return switch (section) {
      'pill' => PillWidgetSettingsPage(appWidgetId: appWidgetId),
      'shopping' => ShoppingWidgetSettingsPage(appWidgetId: appWidgetId),
      'coffee' => CoffeeWidgetSettingsPage(appWidgetId: appWidgetId),
      _ => WidgetSettingsPage(appWidgetId: appWidgetId),
    };
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
    } else if (uri.host == 'shopping' && path == '/quick-add') {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      homeScreenKey.currentState?.selectTab(HomeTab.shopping);
      HomeScreen.focusShoppingQuickAddNotifier.value++;
    } else if (uri.host == 'tasks' && path == '/add') {
      final taskName = queryParams['task_name'];
      if (taskName != null && taskName.isNotEmpty) {
        _createTask(context, taskName);
      }
    } else if (uri.host == 'tasks' && path == '/new') {
      navigatorKey.currentState?.popUntil((route) => route.isFirst);
      homeScreenKey.currentState?.selectTab(HomeTab.tasks);
      HomeScreen.openNewTaskSheetNotifier.value++;
    } else if (uri.host == 'coffee' && path.startsWith('/recipe/')) {
      final recipeId = path.substring('/recipe/'.length);
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CoffeePickerPage(recipeId: recipeId)),
      );
    } else if (uri.host == 'medications') {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const MedicationRemindersPage()),
      );
    } else if (uri.host == 'opengym') {
      final autoStartNext = path == '/start-next';
      final openActive = path == '/active';
      launchOpenGym(
        context,
        autoStartNextWorkout: autoStartNext,
        openActiveWorkout: openActive,
      );
    } else if (uri.host == 'widget-settings') {
      final appWidgetId = int.tryParse(queryParams['appWidgetId'] ?? '');
      final section = path.startsWith('/') ? path.substring(1) : path;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _buildWidgetSettingsPage(section, appWidgetId),
        ),
      );
    }
  }

  Future<void> launchOpenGym(
    BuildContext context, {
    bool autoStartNextWorkout = false,
    bool openActiveWorkout = false,
  }) async {
    final store = LocalHealthDataStore();
    if (OpenGymLauncher.isOpen) {
      await OpenGymLauncher.launch(
        context,
        store,
        autoStartNextWorkout: autoStartNextWorkout,
        openActiveWorkout: openActiveWorkout,
        notificationScheduler: NotificationService.instance,
      );
      return;
    }
    try {
      await OpenGymLauncher.launch(
        context,
        store,
        autoStartNextWorkout: autoStartNextWorkout,
        openActiveWorkout: openActiveWorkout,
        notificationScheduler: NotificationService.instance,
      );
    } finally {
      await store.close();
    }
  }

  void _addShoppingItem(BuildContext context, String itemName) {
    final shoppingCubit = context.read<ShoppingCubit>();
    shoppingCubit.addItem(itemName);
    AppHaptics.instance.confirm();

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
    AppHaptics.instance.confirm();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Created task "$taskTitle" via Assistant'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void dispose() {
    _linkSubscription?.cancel();
    _hostContext = null;
  }
}
