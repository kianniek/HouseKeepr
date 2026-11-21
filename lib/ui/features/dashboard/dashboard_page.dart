import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../cubits/task_cubit.dart';
import '../../../../home_screen.dart';
import '../../../../models/task.dart';
import '../../../../services/app_haptics.dart';
import '../../common/app_theme.dart';
import '../../common/widgets/undo_toast.dart';
import '../profile/pages/settings_page.dart';
import '../tasks/pages/tasks_page.dart';
import '../tasks/utils/task_date_utils.dart';
import '../tasks/widgets/task_detail_sheet.dart';
import 'models/dashboard_layout_store.dart';
import 'widgets/calendar_widget.dart';
import 'widgets/editable_bento_tile.dart';
import 'widgets/medication_widget.dart';
import 'widgets/shopping_list_widget.dart';
import 'widgets/weather_card.dart';

class DashboardPage extends StatefulWidget {
  final fb.User? currentUser;
  final String? householdId;
  final SharedPreferences? preferences;

  const DashboardPage({
    super.key,
    this.currentUser,
    this.householdId,
    this.preferences,
  });

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage>
    with SingleTickerProviderStateMixin {
  late final DashboardLayoutStore _layoutStore;
  late final AnimationController _jiggleController;
  List<DashboardWidgetId> _order = List<DashboardWidgetId>.from(
    DashboardWidgetId.values,
  );
  Set<DashboardWidgetId> _hidden = <DashboardWidgetId>{};
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _layoutStore = DashboardLayoutStore(prefs: widget.preferences);
    _jiggleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 140),
    );
    _loadLayout();
  }

  @override
  void dispose() {
    _jiggleController.dispose();
    super.dispose();
  }

  Future<void> _loadLayout() async {
    final layout = await _layoutStore.load();
    if (!mounted) return;
    setState(() {
      _order = layout.order;
      _hidden = layout.hidden;
    });
  }

  void _enterEditMode() {
    if (_isEditing) return;
    AppHaptics.instance.confirm();
    setState(() => _isEditing = true);
    if (!MediaQuery.disableAnimationsOf(context)) {
      _jiggleController.repeat(reverse: true);
    }
  }

  void _exitEditMode() {
    if (!_isEditing) return;
    _jiggleController.stop();
    _jiggleController.value = 0.5;
    setState(() => _isEditing = false);
  }

  Future<void> _reorderWidget(
    DashboardWidgetId dragged,
    DashboardWidgetId target,
  ) async {
    final oldIndex = _order.indexOf(dragged);
    final newIndex = _order.indexOf(target);
    if (oldIndex == -1 || newIndex == -1 || oldIndex == newIndex) return;

    AppHaptics.instance.confirm();
    final updated = List<DashboardWidgetId>.from(_order);
    updated.removeAt(oldIndex);
    updated.insert(newIndex, dragged);
    setState(() => _order = updated);
    await _layoutStore.saveOrder(updated);
  }

  Future<void> _hideWidget(DashboardWidgetId id) async {
    if (_hidden.contains(id)) return;
    AppHaptics.instance.toggleOff();
    final updated = Set<DashboardWidgetId>.from(_hidden)..add(id);
    setState(() => _hidden = updated);
    await _layoutStore.saveHidden(updated);
  }

  Future<void> _restoreWidget(DashboardWidgetId id) async {
    if (!_hidden.contains(id)) return;
    AppHaptics.instance.confirm();
    final updated = Set<DashboardWidgetId>.from(_hidden)..remove(id);
    setState(() => _hidden = updated);
    await _layoutStore.saveHidden(updated);
  }

  Widget _buildBentoWidget(BuildContext context, DashboardWidgetId id) {
    switch (id) {
      case DashboardWidgetId.weather:
        return const WeatherCard();
      case DashboardWidgetId.calendar:
        return _buildCalendarCard(context);
      case DashboardWidgetId.shopping:
        return const ShoppingListWidget();
      case DashboardWidgetId.medications:
        return const MedicationWidget();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final userName =
        widget.currentUser?.displayName?.split(' ').first ??
        widget.currentUser?.email?.split('@').first ??
        'User';

    return PopScope(
      canPop: !_isEditing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isEditing) {
          _exitEditMode();
        }
      },
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'House Keepr',
                          style: textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Welcome back, $userName 👋',
                          style: textTheme.bodyMedium,
                        ),
                      ],
                    ),
                    if (_isEditing)
                      FilledButton.tonal(
                        onPressed: _exitEditMode,
                        child: const Text('Done'),
                      )
                    else
                      Container(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.settings_outlined),
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsPage(),
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),

              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    0,
                    16,
                    24 + MediaQuery.paddingOf(context).bottom,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Bento Grid Layout
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columnWidth = (constraints.maxWidth - 16) / 2;
                          final visibleOrder = _order
                              .where((id) => !_hidden.contains(id))
                              .toList();
                          final hiddenOrder = _order
                              .where((id) => _hidden.contains(id))
                              .toList();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Full-width Daily Progress Bento Box (pinned)
                              _buildDailyProgressCard(context),
                              const SizedBox(height: 16),

                              if (visibleOrder.isEmpty && !_isEditing)
                                _buildEmptyWidgetsCard(context)
                              else if (visibleOrder.isNotEmpty)
                                _buildTwoColumnGrid(
                                  context,
                                  ids: visibleOrder,
                                  itemBuilder: (id, index) => EditableBentoTile(
                                    key: ValueKey('bento_${id.name}'),
                                    id: id,
                                    index: index,
                                    cardWidth: columnWidth,
                                    isEditing: _isEditing,
                                    jiggleAnimation: _jiggleController,
                                    onEnterEditMode: _enterEditMode,
                                    onRemove: () => _hideWidget(id),
                                    onReorder: _reorderWidget,
                                    child: _buildBentoWidget(context, id),
                                  ),
                                ),

                              if (_isEditing && hiddenOrder.isNotEmpty) ...[
                                const SizedBox(height: 24),
                                Text(
                                  'Hidden widgets · Tap to restore',
                                  style: textTheme.labelMedium?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _buildTwoColumnGrid(
                                  context,
                                  ids: hiddenOrder,
                                  itemBuilder: (id, _) => HiddenBentoTile(
                                    key: ValueKey('hidden_${id.name}'),
                                    id: id,
                                    onRestore: () => _restoreWidget(id),
                                    child: _buildBentoWidget(context, id),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTwoColumnGrid(
    BuildContext context, {
    required List<DashboardWidgetId> ids,
    required Widget Function(DashboardWidgetId id, int index) itemBuilder,
  }) {
    final leftItems = <Widget>[];
    final rightItems = <Widget>[];

    for (var i = 0; i < ids.length; i++) {
      final tile = itemBuilder(ids[i], i);
      if (i.isEven) {
        if (leftItems.isNotEmpty) leftItems.add(const SizedBox(height: 16));
        leftItems.add(tile);
      } else {
        if (rightItems.isNotEmpty) rightItems.add(const SizedBox(height: 16));
        rightItems.add(tile);
      }
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: leftItems,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: rightItems,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWidgetsCard(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Column(
        children: [
          Text(
            'No widgets on dashboard',
            style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _enterEditMode,
            icon: const Icon(Icons.tune, size: 18),
            label: const Text('Customize'),
          ),
        ],
      ),
    );
  }

  void _openTodayTasks(BuildContext context, DateTime today) {
    final homeState = context.findAncestorStateOfType<HomeScreenState>();
    if (homeState != null) {
      HomeScreen.selectTasksDateNotifier.value = today;
      homeState.selectTab(HomeTab.tasks);
      return;
    }

    final taskCubit = context.read<TaskCubit>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BlocProvider.value(
          value: taskCubit,
          child: TasksPage(
            householdId: widget.householdId,
            currentUser: widget.currentUser,
            initialSelectedDate: today,
          ),
        ),
      ),
    );
  }

  Future<void> _completeNextUpTask(
    BuildContext context,
    Task task,
    DateTime today,
  ) async {
    final cubit = context.read<TaskCubit>();
    final todayStr = DateTime.now().toUtc().toIso8601String().split('T')[0];
    final displayTitle = sanitizeTaskTitle(task.title);

    AppHaptics.instance.confirm();
    if (task.isRepeating) {
      await cubit.completeOccurrence(task.id, todayStr);
    } else {
      await cubit.updateTask(task.copyWith(completed: true));
    }

    if (!context.mounted) return;
    showUndoToast(
      context,
      message: 'Completed "$displayTitle"',
      icon: Icons.check_circle_outline,
      onUndo: () {
        if (task.isRepeating) {
          cubit.uncompleteOccurrence(task.id, todayStr);
        } else {
          cubit.updateTask(task.copyWith(completed: false));
        }
      },
    );
  }

  Widget _buildDailyProgressCard(BuildContext context) {
    return BlocBuilder<TaskCubit, TaskState>(
      builder: (context, state) {
        final theme = Theme.of(context);
        final scheme = theme.colorScheme;
        final textTheme = theme.textTheme;
        final semantic = AppSemanticColors.of(context);
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);

        final todayTasks = <Task>[];
        final overdueTasks = <Task>[];

        for (final t in state.tasks) {
          if (t.archived) continue;
          if (doesTaskOccurOnDate(t, today, now: now)) {
            todayTasks.add(t);
            continue;
          }
          if (!isTaskCompletedOnDate(t, today)) {
            final due = effectiveDueDate(t, now: now);
            if (due != null && isOverdue(due, now: now)) {
              overdueTasks.add(t);
            }
          }
        }

        final completedToday = todayTasks
            .where((t) => isTaskCompletedOnDate(t, today))
            .length;
        final totalToday = todayTasks.length;
        final remainingToday = totalToday - completedToday;
        final percentage = totalToday > 0
            ? ((completedToday / totalToday) * 100).round()
            : 0;

        final incompleteToday =
            todayTasks.where((t) => !isTaskCompletedOnDate(t, today)).toList()
              ..sort((a, b) => b.priority.index.compareTo(a.priority.index));
        overdueTasks.sort(
          (a, b) => b.priority.index.compareTo(a.priority.index),
        );

        final Task? nextUpTask = incompleteToday.isNotEmpty
            ? incompleteToday.first
            : (overdueTasks.isNotEmpty ? overdueTasks.first : null);
        final bool nextUpIsOverdue =
            incompleteToday.isEmpty && overdueTasks.isNotEmpty;

        final String subtitleText;
        if (totalToday == 0) {
          subtitleText = overdueTasks.isNotEmpty
              ? 'No tasks due today · ${overdueTasks.length} overdue'
              : 'No tasks scheduled for today';
        } else if (remainingToday > 0) {
          subtitleText =
              '$completedToday of $totalToday done · $remainingToday left';
        } else {
          subtitleText = 'All $totalToday tasks done for today! 🎉';
        }

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Daily Progress',
                              style: textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: scheme.onPrimaryContainer,
                              ),
                            ),
                            if (overdueTasks.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: semantic.warningContainer,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  '${overdueTasks.length} overdue',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: semantic.onWarningContainer,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subtitleText,
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onPrimaryContainer.withValues(
                              alpha: 0.85,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () => _openTodayTasks(context, today),
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text('View Today\'s Tasks'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 88,
                    height: 88,
                    child: TweenAnimationBuilder<double>(
                      key: ValueKey('$percentage-$totalToday'),
                      tween: Tween<double>(
                        begin: 0,
                        end: totalToday > 0 ? percentage / 100 : 0,
                      ),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeOutCubic,
                      builder: (context, value, child) {
                        final animatedPercent = (value * 100).round();
                        return Stack(
                          children: [
                            Center(
                              child: SizedBox(
                                width: 88,
                                height: 88,
                                child: CircularProgressIndicator(
                                  value: value,
                                  strokeWidth: 8,
                                  backgroundColor: scheme.onPrimaryContainer
                                      .withValues(alpha: 0.16),
                                  strokeCap: StrokeCap.round,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    scheme.onPrimaryContainer,
                                  ),
                                ),
                              ),
                            ),
                            Center(
                              child: (totalToday > 0 && remainingToday == 0)
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 32,
                                      color: scheme.onPrimaryContainer,
                                    )
                                  : Text(
                                      totalToday > 0
                                          ? '$animatedPercent%'
                                          : '—',
                                      style: textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        color: scheme.onPrimaryContainer,
                                      ),
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (nextUpTask != null) ...[
                const SizedBox(height: 14),
                Material(
                  color: scheme.surface.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => showTaskDetailSheet(
                      context,
                      nextUpTask,
                      householdId: widget.householdId,
                      currentUser: widget.currentUser,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () =>
                                _completeNextUpTask(context, nextUpTask, today),
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(2),
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: scheme.onPrimaryContainer,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  nextUpIsOverdue ? 'Overdue' : 'Next up',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: nextUpIsOverdue
                                        ? semantic.onWarningContainer
                                        : scheme.onPrimaryContainer.withValues(
                                            alpha: 0.75,
                                          ),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  sanitizeTaskTitle(nextUpTask.title),
                                  softWrap: true,
                                  style: textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: scheme.onPrimaryContainer,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (nextUpTask.room != null &&
                              nextUpTask.room!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                nextUpTask.room!,
                                style: textTheme.labelSmall?.copyWith(
                                  color: scheme.onPrimaryContainer,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarCard(BuildContext context) {
    return const CalendarWidget();
  }
}
