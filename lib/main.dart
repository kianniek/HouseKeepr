import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:housekeepr/home_screen.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'ui/login_page.dart';
import 'ui/household_create_page.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'cubits/task_cubit.dart';
import 'cubits/shopping_cubit_v2.dart';
import 'cubits/user_cubit.dart';
import 'repositories/task_repository.dart';
import 'repositories/grocery_repository.dart';
import 'firestore/firestore_task_repository.dart';
import 'firestore/firestore_household_task_repository.dart';
import 'firestore/firestore_grocery_repository.dart';
import 'firestore/firestore_household_grocery_repository.dart';
import 'models/task.dart';
import 'models/grocery_item.dart';
import 'repositories/history_repository.dart';
import 'firestore/firestore_history_repository.dart';
import 'services/write_queue.dart';
import 'models/completion_record.dart';
import 'services/firestore_sync_service.dart';
import 'services/household_service.dart';
import 'services/shopping_products_service.dart';
import 'core/settings_repository.dart';
import 'services/notification_service.dart';
import 'services/widget_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  Object? initError;
  try {
    // Prevent duplicate Firebase app initialization
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kIsWeb) {
        await fb.FirebaseAuth.instance.setPersistence(fb.Persistence.LOCAL);
      }
    }
  } on FirebaseException catch (e) {
    // Ignore duplicate app errors
    if (e.code != 'duplicate-app') {
      initError = e;
      debugPrint('Firebase initialization failed: $e');
    }
  } catch (e, st) {
    initError = e;
    debugPrint('Firebase initialization failed: $e\n$st');
  }

  runApp(MyApp(initializationError: initError));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initializationError});
  final Object? initializationError;
  static const Color fallbackSeed = Color.fromARGB(255, 247, 136, 1);

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        final ColorScheme lightScheme =
            lightDynamic ??
            ColorScheme.fromSeed(
              seedColor: fallbackSeed,
              brightness: Brightness.light,
            );
        final ColorScheme darkScheme =
            darkDynamic ??
            ColorScheme.fromSeed(
              seedColor: fallbackSeed,
              brightness: Brightness.dark,
            );

        return MaterialApp(
          scaffoldMessengerKey: scaffoldMessengerKey,
          navigatorKey: navigatorKey,
          title: 'HouseKeepr',
          theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
          darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
          themeMode: ThemeMode.system,
          home: AppRoot(initializationError: initializationError),
        );
      },
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key, this.initializationError});
  final Object? initializationError;

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  fb.User? _user;
  String? _householdId;
  bool _checkingHousehold = false;
  StreamSubscription<fb.User?>? _authSub;
  Object? _initError;
  bool _authListenerAttached = false;
  Timer? _householdStageTimerShort;
  Timer? _householdStageTimerLong;
  String? _householdStageLabel;
  bool _showHouseholdGeneric = false;
  bool _showHouseholdDetailed = false;
  final List<String> _householdStageLog = [];

  @override
  void initState() {
    super.initState();
    _initError = widget.initializationError;
    if (_initError == null) {
      _attachAuthListener();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _householdStageTimerShort?.cancel();
    _householdStageTimerLong?.cancel();
    super.dispose();
  }

  void _startHouseholdStageTimers() {
    _householdStageTimerShort?.cancel();
    _householdStageTimerLong?.cancel();
    _householdStageLabel = null;
    _showHouseholdGeneric = false;
    _showHouseholdDetailed = false;

    _householdStageTimerShort = Timer(const Duration(seconds: 2), () {
      if (!mounted || !_checkingHousehold) return;
      setState(() => _showHouseholdGeneric = true);
    });

    _householdStageTimerLong = Timer(const Duration(seconds: 5), () {
      if (!mounted || !_checkingHousehold) return;
      setState(() => _showHouseholdDetailed = true);
    });
  }

  void _stopHouseholdStageTimers() {
    _householdStageTimerShort?.cancel();
    _householdStageTimerLong?.cancel();
    _householdStageLabel = null;
    _showHouseholdGeneric = false;
    _showHouseholdDetailed = false;
  }

  void _logHouseholdStage(String label) {
    final timestamp = DateTime.now().toIso8601String();
    _householdStageLog.add('$timestamp  $label');
  }

  void _setHouseholdStageLabel(String label) {
    if (!mounted || !_checkingHousehold) return;
    _logHouseholdStage(label);
    setState(() => _householdStageLabel = label);
  }

  void _showHouseholdStageDetails() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Household loading details'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _householdStageLog.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                return Text(_householdStageLog[index]);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  // Consolidated initialization logic
  Future<void> _retryInitialization() async {
    Object? initError;
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e) {
      initError = e;
    }

    setState(() {
      _initError = initError;
    });

    if (initError == null && !_authListenerAttached) {
      _attachAuthListener();
      final current = fb.FirebaseAuth.instance.currentUser;
      if (current != null) _onSignedIn(current);
    }
  }

  void _attachAuthListener() {
    if (_authListenerAttached) return;
    _authListenerAttached = true;
    _authSub = fb.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        setState(() {
          _user = null;
          _householdId = null;
          _checkingHousehold = false;
        });
      } else if (_user == null || _user?.uid != user.uid) {
        _onSignedIn(user);
      }
    });
  }

  void _onSignedIn(fb.User user) async {
    _startHouseholdStageTimers();
    _householdStageLog.clear();
    setState(() {
      _user = user;
      _checkingHousehold = true;
      _householdStageLabel = 'Saving user profile...';
    });
    _logHouseholdStage(
      'Saving user profile for user ${user.uid} (${user.email})',
    );
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
      }, SetOptions(merge: true));

      final hs = HouseholdService(FirebaseFirestore.instance);
      _setHouseholdStageLabel('Fetching household membership...');
      final hid = await hs.findHouseholdForUser(user.uid);
      setState(() {
        _householdId = hid;
        _checkingHousehold = false;
        _stopHouseholdStageTimers();
      });
    } catch (e) {
      debugPrint('Sign-in processing failed: $e');
      setState(() {
        _checkingHousehold = false;
        _stopHouseholdStageTimers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveInitError = _initError;
    if (effectiveInitError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Initialization Error')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('The app failed to initialize Firebase.'),
              const SizedBox(height: 8),
              Text(effectiveInitError.toString()),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _retryInitialization,
                child: const Text('Retry initialization'),
              ),
            ],
          ),
        ),
      );
    }

    if (_user == null) {
      return LoginPage(
        auth: fb.FirebaseAuth.instance,
        googleSignIn: GoogleSignIn(),
        onSignedIn: _onSignedIn,
      );
    }

    if (_checkingHousehold) {
      final stageText = _showHouseholdDetailed
          ? _householdStageLabel
          : (_showHouseholdGeneric ? 'Loading...' : null);
      return Scaffold(
        body: GestureDetector(
          onTap: _showHouseholdStageDetails,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                if (stageText != null) ...[
                  const SizedBox(height: 12),
                  Text(stageText),
                ],
              ],
            ),
          ),
        ),
      );
    }

    if (_householdId == null) {
      return HouseholdCreatePage(
        user: _user!,
        onCreated: (id) => setState(() => _householdId = id),
      );
    }

    return BlocProvider(
      create: (_) => UserCubit(_user),
      child: HouseholdApp(user: _user!, householdId: _householdId!),
    );
  }
}

class _HouseholdInitData {
  final TaskCubit taskCubit;
  final ShoppingCubit shoppingCubit;
  final FirestoreSyncService syncService;
  final GroceryRepository groceryRepository;

  _HouseholdInitData({
    required this.taskCubit,
    required this.shoppingCubit,
    required this.syncService,
    required this.groceryRepository,
  });
}

class _HouseholdAppContent extends StatefulWidget {
  final fb.User user;
  final FirestoreSyncService syncService;
  final GroceryRepository groceryRepository;

  const _HouseholdAppContent({
    required this.user,
    required this.syncService,
    required this.groceryRepository,
  });

  @override
  State<_HouseholdAppContent> createState() => _HouseholdAppContentState();
}

class _HouseholdAppContentState extends State<_HouseholdAppContent>
    with WidgetsBindingObserver {
  StreamSubscription? _shoppingWidgetSub;
  late MethodChannel _widgetActionChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to ShoppingCubit and push changes to the widget with debounce
    final shoppingCubit = context.read<ShoppingCubit>();
    _shoppingWidgetSub = shoppingCubit.stream.listen((state) {
      WidgetService.instance.updateWidget(state.items);
    });

    // Set up widget action channel
    _widgetActionChannel = const MethodChannel('housekeepr/widget_actions');
    _checkWidgetAction();

    // Process any pending toggles from the widget on startup
    _processPendingToggles();
  }

  Future<void> _checkWidgetAction() async {
    try {
      final result = await _widgetActionChannel.invokeMethod<String>(
        'getWidgetAction',
      );
      if (result == 'open_shopping' && mounted) {
        final homeScreenState = homeScreenKey.currentState;
        homeScreenState?.selectTab(HomeTab.shopping);
      }
    } catch (e) {
      debugPrint('Error checking widget action: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _processPendingToggles();
      _checkWidgetAction();
    }
  }

  Future<void> _processPendingToggles() async {
    final pendingIds = await WidgetService.instance.processPendingToggles();
    if (pendingIds.isEmpty || !mounted) return;
    final shoppingCubit = context.read<ShoppingCubit>();
    for (final id in pendingIds) {
      await shoppingCubit.toggleItem(id);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shoppingWidgetSub?.cancel();
    WidgetService.instance.dispose();
    widget.syncService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return HomeScreen(key: homeScreenKey);
  }
}

class HouseholdApp extends StatefulWidget {
  final fb.User user;
  final String householdId;
  const HouseholdApp({
    super.key,
    required this.user,
    required this.householdId,
  });

  @override
  State<HouseholdApp> createState() => _HouseholdAppState();
}

class _HouseholdAppState extends State<HouseholdApp> {
  late Future<_HouseholdInitData> _initFuture;
  Timer? _initStageTimerShort;
  Timer? _initStageTimerLong;
  String? _initStageLabel;
  bool _showInitGeneric = false;
  bool _showInitDetailed = false;
  final List<String> _initStageLog = [];

  @override
  void initState() {
    super.initState();
    _startInitStageTimers();
    _initFuture = _initialize().whenComplete(_stopInitStageTimers);
  }

  @override
  void dispose() {
    _initStageTimerShort?.cancel();
    _initStageTimerLong?.cancel();
    super.dispose();
  }

  void _startInitStageTimers() {
    _initStageTimerShort?.cancel();
    _initStageTimerLong?.cancel();
    _initStageLabel = null;
    _showInitGeneric = false;
    _showInitDetailed = false;

    _initStageTimerShort = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => _showInitGeneric = true);
    });

    _initStageTimerLong = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => _showInitDetailed = true);
    });
  }

  void _stopInitStageTimers() {
    _initStageTimerShort?.cancel();
    _initStageTimerLong?.cancel();
    if (!mounted) return;
    setState(() {
      _initStageLabel = null;
      _showInitGeneric = false;
      _showInitDetailed = false;
    });
  }

  void _setInitStageLabel(String label) {
    if (!mounted) return;
    final timestamp = DateTime.now().toIso8601String();
    _initStageLog.add('$timestamp  $label');
    setState(() => _initStageLabel = label);
  }

  void _showInitStageDetails() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Initialization details'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _initStageLog.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, index) {
                return Text(_initStageLog[index]);
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _openTasksTab() {
    final homeState = homeScreenKey.currentState;
    if (homeState != null) {
      homeState.selectTab(HomeTab.tasks);
      return;
    }
    final navState = navigatorKey.currentState;
    if (navState != null) {
      navState.popUntil((route) => route.isFirst);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeScreenKey.currentState?.selectTab(HomeTab.tasks);
    });
  }

  Future<void> _maybeRequestNotificationPermissions(
    SettingsRepository settingsRepo,
  ) async {
    if (settingsRepo.notificationPermissionPrompted()) return;
    await NotificationService.instance.requestPermissions();
    await settingsRepo.setNotificationPermissionPrompted(true);
  }

  Future<_HouseholdInitData> _initialize() async {
    _initStageLog.clear();
    _setInitStageLabel('Loading local preferences...');
    final prefs = await SharedPreferences.getInstance();
    _setInitStageLabel('Opening local storage...');
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox('tasks'),
      Hive.openBox('tasks_meta'),
      Hive.openBox('groceries'),
      Hive.openBox('groceries_meta'),
      Hive.openBox('history'),
    ]);

    final settingsRepo = SettingsRepository(prefs);

    // Migration and Service initialization...
    _setInitStageLabel('Initializing notifications...');
    await NotificationService.instance.init(
      prefs,
      scaffoldKey: scaffoldMessengerKey,
      onOpenTasks: _openTasksTab,
    );
    await _maybeRequestNotificationPermissions(settingsRepo);
    await NotificationService.instance.checkAndFireDueReminders();
    _setInitStageLabel('Initializing shopping products...');
    await ShoppingProductsService.instance.init(prefs);
    final taskCubit = TaskCubit(TaskRepository(prefs), settings: settingsRepo);
    final shoppingCubit = ShoppingCubit(GroceryRepository());

    // Initialize widget service and push initial data
    _setInitStageLabel('Initializing home widget...');
    await WidgetService.instance.init();
    await shoppingCubit.initializationFuture;
    await WidgetService.instance.updateWidgetImmediate(
      shoppingCubit.state.items,
    );

    final remoteTask = FirestoreTaskRepository(
      FirebaseFirestore.instance,
      userId: widget.user.uid,
    );
    final remoteHouseholdTask = FirestoreHouseholdTaskRepository(
      FirebaseFirestore.instance,
      householdId: widget.householdId,
    );
    final remoteHouseholdShopping = FirestoreHouseholdGroceryRepository(
      FirebaseFirestore.instance,
      householdId: widget.householdId,
    );

    taskCubit.setRemoteRepository(remoteTask);

    final historyRepo = HistoryRepository();
    final remoteHistory = FirestoreHistoryRepository(
      FirebaseFirestore.instance,
      userId: widget.user.uid,
    );
    final writeQueue = WriteQueue(prefs);
    writeQueue.setUserId(widget.user.uid);

    writeQueue.attachOpBuilder(
      (op) => () async {
        switch (op.type) {
          case QueueOpType.saveTask:
            final task = Task.fromMap(op.payload!);
            task.householdId != null
                ? await remoteHouseholdTask.saveTask(task)
                : await remoteTask.saveTask(task);
            break;
          case QueueOpType.deleteTask:
            final prev = op.payload?['_previous'];
            (prev is Map && prev['householdId'] != null)
                ? await remoteHouseholdTask.deleteTask(op.id)
                : await remoteTask.deleteTask(op.id);
            break;
          case QueueOpType.saveShopping:
          case QueueOpType.deleteShopping:
            // Deprecated shopping ops
            debugPrint('Dropping legacy shopping op: ${op.type}');
            break;
          case QueueOpType.saveGrocery:
            await remoteHouseholdShopping.saveItem(
              GroceryItem.fromMap(op.payload!.cast<String, dynamic>()),
            );
            break;
          case QueueOpType.deleteGrocery:
            await remoteHouseholdShopping.deleteItem(op.id);
            break;
          case QueueOpType.saveHistory:
            await remoteHistory.saveRecord(
              CompletionRecord.fromMap(op.payload!.cast<String, dynamic>()),
            );
            break;
          case QueueOpType.deleteHistory:
            await remoteHistory.deleteRecord(op.id);
            break;
        }
      },
    );

    taskCubit.attachWriteQueueAndHistory(writeQueue, historyRepo);
    shoppingCubit.attachWriteQueue(writeQueue);

    final syncService = FirestoreSyncService(FirebaseFirestore.instance);
    _setInitStageLabel('Starting sync service...');
    await syncService.start(
      widget.user.uid,
      taskCubit,
      shoppingCubit,
      householdId: widget.householdId,
    );

    return _HouseholdInitData(
      taskCubit: taskCubit,
      shoppingCubit: shoppingCubit,
      syncService: syncService,
      groceryRepository: shoppingCubit.repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HouseholdInitData>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          final stageText = _showInitDetailed
              ? _initStageLabel
              : (_showInitGeneric ? 'Loading...' : null);
          return Scaffold(
            body: GestureDetector(
              onTap: _showInitStageDetails,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(),
                    if (stageText != null) ...[
                      const SizedBox(height: 12),
                      Text(stageText),
                    ],
                  ],
                ),
              ),
            ),
          );
        }
        if (snap.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Initialization error'),
                  const SizedBox(height: 8),
                  Text(snap.error.toString()),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      _startInitStageTimers();
                      setState(() {
                        _initFuture = _initialize().whenComplete(
                          _stopInitStageTimers,
                        );
                      });
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        final data = snap.data!;
        return MultiBlocProvider(
          providers: [
            BlocProvider<TaskCubit>.value(value: data.taskCubit),
            BlocProvider<ShoppingCubit>.value(value: data.shoppingCubit),
          ],
          child: _HouseholdAppContent(
            user: widget.user,
            syncService: data.syncService,
            groceryRepository: data.groceryRepository,
          ),
        );
      },
    );
  }
}
