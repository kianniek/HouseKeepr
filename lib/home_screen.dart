import 'dart:io';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/features/dashboard/dashboard_page.dart';
import 'package:housekeepr/ui/features/shopping/pages/smart_shopping_list_page.dart';
import 'package:housekeepr/ui/features/tasks/pages/tasks_page.dart';
import 'package:housekeepr/ui/features/tools/pages/tools_library_page.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/settings_repository.dart';
import '../cubits/shopping_cubit.dart';
import '../cubits/task_cubit.dart';
import '../services/app_action_handler.dart';
import '../services/app_haptics.dart';
import '../services/household_service.dart';

enum HomeTab {
  // When updating these, also update the _rebuildPages() method in HomeScreenState to ensure the correct pages are shown for each tab index
  dashboard(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  tasks(Icons.task_alt_outlined, Icons.task_alt, 'Tasks'),
  shopping(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Shopping'),
  tools(Icons.build_outlined, Icons.build, 'Tools');

  final IconData icon;
  final IconData activeIcon;
  final String label;

  const HomeTab(this.icon, this.activeIcon, this.label);
}

class HomeScreen extends StatefulWidget {
  final String? householdId;

  const HomeScreen({super.key, this.householdId});

  /// Notifier that SettingsPage updates so HomeScreen reacts immediately.
  static final floatingNavNotifier = ValueNotifier<bool>(true);

  /// Notifier toggled when a notification asks to open & highlight the
  /// Auto-Balance banner on [TasksPage].
  static final highlightAutoBalanceNotifier = ValueNotifier<int>(0);

  /// Sticky flag set when a notification asks to open the Auto-Balance
  /// preview sheet on [TasksPage] (survives cold-start initialization).
  static final openRebalanceSheetNotifier = ValueNotifier<bool>(false);

  /// Notifier toggled when a shortcut or Share action asks to focus the
  /// quick-add input on [SmartShoppingListPage].
  static final focusShoppingQuickAddNotifier = ValueNotifier<int>(0);

  /// Notifier toggled when a shortcut asks to open the New Task sheet on
  /// [TasksPage].
  static final openNewTaskSheetNotifier = ValueNotifier<int>(0);

  /// Notifier set when another tab (e.g. Dashboard) asks [TasksPage] to
  /// select a specific calendar date.
  static final selectTasksDateNotifier = ValueNotifier<DateTime?>(null);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final _appActionHandler = AppActionHandler();
  bool _updateChecked = false;
  int _currentIndex = 0;
  String? _cachedHouseholdId;
  bool _useFloatingNav = false;
  SharedPreferences? _prefs;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _cachedHouseholdId = widget.householdId;
    _rebuildPages();
    HomeScreen.floatingNavNotifier.addListener(_onFloatingNavChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      if (_cachedHouseholdId == null) {
        _loadHouseholdId();
      }
      _loadFloatingNavPreference();
      _loadLastTab();
      _warmUpData();

      _appActionHandler.init(context);
    });
  }

  Future<void> _warmUpData() async {
    final taskCubit = context.read<TaskCubit>();
    final shoppingCubit = context.read<ShoppingCubit>();

    final taskInit = taskCubit.initializationFuture;
    if (taskInit != null) {
      await taskInit;
    }

    final shoppingInit = shoppingCubit.initializationFuture;
    if (shoppingInit != null) {
      await shoppingInit;
    }

    if (!mounted) return;

    if (taskCubit.state.hasMore) {
      await taskCubit.loadMore();
    }
  }

  void _rebuildPages() {
    final user = FirebaseAuth.instance.currentUser;
    _pages = [
      DashboardPage(currentUser: user, householdId: _cachedHouseholdId),
      TasksPage(currentUser: user, householdId: _cachedHouseholdId),
      const SmartShoppingListPage(),
      ToolsLibraryPage(householdId: _cachedHouseholdId),
    ];
  }

  Future<void> _loadHouseholdId() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final svc = HouseholdService(FirebaseFirestore.instance);
    final householdId = await svc.findHouseholdForUser(user.uid);
    if (mounted) {
      setState(() {
        _cachedHouseholdId = householdId;
        _rebuildPages();
      });
    }
  }

  Future<void> _loadFloatingNavPreference() async {
    _prefs ??= await SharedPreferences.getInstance();
    final settings = SettingsRepository(_prefs!);
    final useFloatingNav = settings.useFloatingNav();
    // Keep the static notifier in sync on first load
    HomeScreen.floatingNavNotifier.value = useFloatingNav;
    if (mounted) {
      setState(() {
        _useFloatingNav = useFloatingNav;
      });
    }
  }

  void _onFloatingNavChanged() {
    if (mounted) {
      setState(() {
        _useFloatingNav = HomeScreen.floatingNavNotifier.value;
      });
    }
  }

  Future<void> _checkForUpdates() async {
    if (_updateChecked) return;
    _updateChecked = true;

    if (kIsWeb || !Platform.isAndroid || !kReleaseMode) return;

    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          if (!mounted) return;
          await InAppUpdate.completeFlexibleUpdate();
        }
      }
    } catch (e, st) {
      debugPrint('In-app update check failed: $e\n$st');
    }
  }

  @override
  void dispose() {
    _appActionHandler.dispose();
    HomeScreen.floatingNavNotifier.removeListener(_onFloatingNavChanged);
    super.dispose();
  }

  void _onNavTap(int index) {
    AppHaptics.instance.segmentTick();
    if (_currentIndex == index) {
      // Already on this tab — scroll its primary scroll view to top
      final controller = PrimaryScrollController.maybeOf(context);
      if (controller != null && controller.hasClients) {
        controller.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }
    setState(() {
      _currentIndex = index;
      _saveLastTab(index);
    });
  }

  Future<void> _loadLastTab() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final idx = _prefs?.getInt('last_home_tab');
      if (idx != null && idx >= 0 && idx < HomeTab.values.length) {
        setState(() => _currentIndex = idx);
      }
    } catch (e) {
      debugPrint('Failed to load last tab: $e');
    }
  }

  Future<void> _saveLastTab(int index) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs?.setInt('last_home_tab', index);
    } catch (e) {
      debugPrint('Failed to save last tab: $e');
    }
  }

  void selectTab(HomeTab tab) {
    _onNavTap(tab.index);
  }

  Widget _buildClassicNav(BuildContext context) {
    return NavigationBar(
      selectedIndex: _currentIndex,
      onDestinationSelected: _onNavTap,
      destinations: HomeTab.values
          .map(
            (tab) => NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.activeIcon),
              label: tab.label,
            ),
          )
          .toList(),
    );
  }

  Widget _buildFloatingNav(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 640;
    final itemCount = HomeTab.values.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                height: 64,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    const indicatorInset = 6.0;

                    return Stack(
                      children: [
                        // Animated pill indicator using AnimatedAlign
                        AnimatedAlign(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.fastOutSlowIn,
                          alignment: Alignment(
                            -1.0 + (_currentIndex * (2.0 / (itemCount - 1))),
                            0.0,
                          ),
                          child: FractionallySizedBox(
                            widthFactor: 1.0 / itemCount,
                            child: Padding(
                              padding: const EdgeInsets.all(indicatorInset),
                              child: Container(
                                height: 64 - (indicatorInset * 2),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondaryContainer,
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Nav items
                        Row(
                          children: HomeTab.values
                              .map(
                                (tab) => Expanded(
                                  child: _buildFloatingNavItem(
                                    tab: tab,
                                    isWide: isWide,
                                    selectedColor:
                                        colorScheme.onSecondaryContainer,
                                    unselectedColor:
                                        colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingNavItem({
    required HomeTab tab,
    required bool isWide,
    required Color selectedColor,
    required Color unselectedColor,
  }) {
    final isSelected = _currentIndex == tab.index;
    final color = isSelected ? selectedColor : unselectedColor;
    final iconData = isSelected ? tab.activeIcon : tab.icon;
    final labelWidget = Text(
      tab.label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    );

    final content = isWide
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: color),
              const SizedBox(width: 8),
              labelWidget,
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(iconData, color: color),
              const SizedBox(height: 4),
              labelWidget,
            ],
          );

    return InkWell(
      onTap: () => _onNavTap(tab.index),
      borderRadius: BorderRadius.circular(30),
      child: Center(child: content),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 640;

    // Wide layout: NavigationRail on the left
    if (isWide) {
      final colorScheme = Theme.of(context).colorScheme;
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: _onNavTap,
              labelType: NavigationRailLabelType.all,
              indicatorColor: colorScheme.secondaryContainer,
              indicatorShape: const StadiumBorder(),
              destinations: HomeTab.values
                  .map(
                    (tab) => NavigationRailDestination(
                      icon: Icon(tab.icon),
                      selectedIcon: Icon(tab.activeIcon),
                      label: Text(tab.label),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: _pages),
            ),
          ],
        ),
      );
    }

    // Narrow layout: bottom nav (floating or classic)
    if (_useFloatingNav) {
      // Use Stack so BackdropFilter can blur the body content beneath it,
      // and add bottom padding so inner FABs aren't hidden behind the pill.
      // Slide away while the IME is visible so inputs reclaim vertical space.
      final mediaData = MediaQuery.of(context);
      final isImeVisible = mediaData.viewInsets.bottom > 0;
      final floatingNavTotalHeight = isImeVisible ? 0.0 : (64.0 + 24.0);
      final bodyWithPadding = MediaQuery(
        data: mediaData.copyWith(
          viewPadding:
              mediaData.viewPadding +
              EdgeInsets.only(bottom: floatingNavTotalHeight),
          padding:
              mediaData.padding +
              EdgeInsets.only(bottom: floatingNavTotalHeight),
        ),
        child: IndexedStack(index: _currentIndex, children: _pages),
      );

      return Scaffold(
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            bodyWithPadding,
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                ignoring: isImeVisible,
                child: AnimatedSlide(
                  offset: isImeVisible ? const Offset(0, 1.5) : Offset.zero,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: isImeVisible ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 160),
                    child: _buildFloatingNav(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: IndexedStack(index: _currentIndex, children: _pages),
      bottomNavigationBar: _buildClassicNav(context),
    );
  }
}
