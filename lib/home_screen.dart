import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb, kReleaseMode;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:housekeepr/ui/smart_shopping_list_page.dart';
import 'package:housekeepr/ui/tasks_page.dart';
import 'package:housekeepr/ui/dashboard_page.dart';
import 'package:housekeepr/ui/tools_library_page.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../cubits/task_cubit.dart';
import '../cubits/shopping_cubit_v2.dart';
import '../core/settings_repository.dart';
import '../services/household_service.dart';

enum HomeTab {
  // When updating these, also update the _rebuildPages() method in HomeScreenState to ensure the correct pages are shown for each tab index
  dashboard(Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
  tasks(Icons.task_alt_outlined, Icons.task_alt, 'Taken'),
  shopping(Icons.shopping_cart_outlined, Icons.shopping_cart, 'Boodschappen'),
  tools(Icons.build_outlined, Icons.build, 'Tools');

  final IconData icon;
  final IconData activeIcon;
  final String label;

  const HomeTab(this.icon, this.activeIcon, this.label);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  /// Notifier that SettingsPage updates so HomeScreen reacts immediately.
  static final floatingNavNotifier = ValueNotifier<bool>(true);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  bool _updateChecked = false;
  int _currentIndex = 0;
  String? _cachedHouseholdId;
  bool _useFloatingNav = true;
  SharedPreferences? _prefs;
  late List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _rebuildPages();
    HomeScreen.floatingNavNotifier.addListener(_onFloatingNavChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdates();
      _loadHouseholdId();
      _loadFloatingNavPreference();
      _loadLastTab();
      _warmUpData();
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
      const ToolsLibraryPage(),
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
    HomeScreen.floatingNavNotifier.removeListener(_onFloatingNavChanged);
    super.dispose();
  }

  void _onNavTap(int index) {
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
    final colorScheme = Theme.of(context).colorScheme;

    return BottomNavigationBar(
      currentIndex: _currentIndex,
      onTap: _onNavTap,
      selectedItemColor: colorScheme.primary,
      unselectedItemColor: colorScheme.onSurfaceVariant,
      items: HomeTab.values
          .map(
            (tab) => BottomNavigationBarItem(
              icon: Icon(tab.icon),
              activeIcon: Icon(tab.activeIcon),
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
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ui.ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
              child: Container(
                height: 64,
                constraints: const BoxConstraints(maxWidth: 400),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainer.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
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
      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
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
      const floatingNavTotalHeight = 64.0 + 24.0; // nav height + bottom padding
      final mediaData = MediaQuery.of(context);
      final bodyWithPadding = MediaQuery(
        data: mediaData.copyWith(
          viewPadding:
              mediaData.viewPadding +
              const EdgeInsets.only(bottom: floatingNavTotalHeight),
          padding:
              mediaData.padding +
              const EdgeInsets.only(bottom: floatingNavTotalHeight),
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
              child: _buildFloatingNav(context),
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
