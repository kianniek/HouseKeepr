import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:housekeepr/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/locale_provider.dart';
import 'core/settings_repository.dart';
import 'cubits/ping_cubit.dart';
import 'cubits/shopping_cubit.dart';
import 'cubits/task_cubit.dart';
import 'cubits/user_cubit.dart';
import 'firebase_options.dart';
import 'firestore/firestore_history_repository.dart';
import 'firestore/firestore_household_grocery_repository.dart';
import 'firestore/firestore_household_task_repository.dart';
import 'firestore/firestore_ping_repository.dart';
import 'firestore/firestore_task_repository.dart';
import 'generated/app_localizations.dart';
import 'models/completion_record.dart';
import 'models/grocery_item.dart';
import 'models/task.dart';
import 'repositories/grocery_repository.dart';
import 'repositories/history_repository.dart';
import 'repositories/task_repository.dart';
import 'services/firebase_messaging_service.dart';
import 'services/firestore_sync_service.dart';
import 'services/household_service.dart';
import 'services/notification_service.dart';
import 'services/shopping_products_service.dart';
import 'services/theme_controller.dart';
import 'services/widget_service.dart';
import 'services/write_queue.dart';
import 'ui/features/auth/login_page.dart';
import 'ui/features/households/pages/household_create_page.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
final GlobalKey<HomeScreenState> homeScreenKey = GlobalKey<HomeScreenState>();
const bool _isWasm = bool.fromEnvironment('dart.tool.dart2wasm');

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      if (kIsWeb && !_isWasm) {
        try {
          await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
        } catch (e, st) {
          debugPrint(
            'Firebase Auth setPersistence failed; continuing with default persistence: $e\n$st',
          );
        }
      } else if (kIsWeb && _isWasm) {
        debugPrint('Skipping explicit Firebase Auth persistence for WASM.');
      }
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      debugPrint('Firebase initialization failed: $e');
    }
  } catch (e, st) {
    debugPrint('Firebase initialization failed: $e\n$st');
  }

  await ThemeController.instance.load();

  await LocaleProvider.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.initializationError});
  final Object? initializationError;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final controller = ThemeController.instance;

        return AnimatedBuilder(
          animation: Listenable.merge([controller, LocaleProvider.instance]),
          builder: (BuildContext context, Widget? child) {
            final ColorScheme lightScheme = controller.lightScheme;
            final ColorScheme darkScheme = controller.darkScheme;
            final locale = LocaleProvider.instance.locale;

            return MaterialApp(
              scaffoldMessengerKey: scaffoldMessengerKey,
              navigatorKey: navigatorKey,
              title: 'HouseKeepr',
              locale: locale,
              supportedLocales: LocaleProvider.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
              darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
              themeMode: ThemeMode.system,
              home: AppRoot(initializationError: widget.initializationError),
            );
          },
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
  User? user;
  String? householdId;
  bool checkingHousehold = false;
  StreamSubscription<User?>? authSub;
  Object? initError0;
  bool authListenerAttached = false;
  Timer? householdStageTimerShort;
  Timer? householdStageTimerLong;
  String? householdStageLabel;
  bool showHouseholdGeneric = false;
  bool showHouseholdDetailed = false;
  final List<String> householdStageLog = [];

  @override
  void initState() {
    super.initState();
    initError0 = widget.initializationError;
    if (initError0 == null) {
      attachAuthListener();
    }
  }

  @override
  void dispose() {
    authSub?.cancel();
    householdStageTimerShort?.cancel();
    householdStageTimerLong?.cancel();
    super.dispose();
  }

  void startHouseholdStageTimers() {
    householdStageTimerShort?.cancel();
    householdStageTimerLong?.cancel();
    householdStageLabel = null;
    showHouseholdGeneric = false;
    showHouseholdDetailed = false;

    householdStageTimerShort = Timer(const Duration(seconds: 2), () {
      if (!mounted || !checkingHousehold) return;
      setState(() => showHouseholdGeneric = true);
    });

    householdStageTimerLong = Timer(const Duration(seconds: 5), () {
      if (!mounted || !checkingHousehold) return;
      setState(() => showHouseholdDetailed = true);
    });
  }

  void stopHouseholdStageTimers() {
    householdStageTimerShort?.cancel();
    householdStageTimerLong?.cancel();
    householdStageLabel = null;
    showHouseholdGeneric = false;
    showHouseholdDetailed = false;
  }

  void logHouseholdStage(String label) {
    final timestamp = DateTime.now().toIso8601String();
    householdStageLog.add('$timestamp  $label');
  }

  void setHouseholdStageLabel(String label) {
    if (!mounted || !checkingHousehold) return;
    logHouseholdStage(label);
    setState(() => householdStageLabel = label);
  }

  void showHouseholdStageDetails() {
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
              itemCount: householdStageLog.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) {
                return Text(householdStageLog[index]);
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
  Future<void> retryInitialization() async {
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
      initError0 = initError;
    });

    if (initError == null && !authListenerAttached) {
      attachAuthListener();
      final current = FirebaseAuth.instance.currentUser;
      if (current != null) onSignedIn(current);
    }
  }

  void attachAuthListener() {
    if (authListenerAttached) return;
    authListenerAttached = true;
    authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        setState(() {
          user = null;
          householdId = null;
          checkingHousehold = false;
        });
      } else if (this.user?.uid != user.uid) {
        onSignedIn(user);
      }
    });
  }

  void onSignedIn(User user) async {
    startHouseholdStageTimers();
    householdStageLog.clear();
    setState(() {
      this.user = user;
      checkingHousehold = true;
      householdStageLabel = 'Saving user profile...';
    });
    logHouseholdStage(
      'Saving user profile for user ${user.uid} (${user.email})',
    );
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
      }, SetOptions(merge: true));

      final hs = HouseholdService(FirebaseFirestore.instance);
      setHouseholdStageLabel('Fetching household membership...');
      final hid = await hs.findHouseholdForUser(user.uid);
      setState(() {
        householdId = hid;
        checkingHousehold = false;
        stopHouseholdStageTimers();
      });
    } catch (e) {
      debugPrint('Sign-in processing failed: $e');
      setState(() {
        checkingHousehold = false;
        stopHouseholdStageTimers();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveInitError = initError0;
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
                onPressed: retryInitialization,
                child: const Text('Retry initialization'),
              ),
            ],
          ),
        ),
      );
    }

    if (user == null) {
      return LoginPage(
        auth: FirebaseAuth.instance,
        googleSignIn: GoogleSignIn(),
        onSignedIn: onSignedIn,
      );
    }

    if (checkingHousehold) {
      final stageText = showHouseholdDetailed
          ? householdStageLabel
          : (showHouseholdGeneric ? 'Loading...' : null);
      return Scaffold(
        body: GestureDetector(
          onTap: showHouseholdStageDetails,
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

    if (householdId == null) {
      return HouseholdCreatePage(
        user: user!,
        onCreated: (id) => setState(() => householdId = id),
      );
    }

    return BlocProvider(
      create: (_) => UserCubit(user),
      child: HouseholdApp(user: user!, householdId: householdId!),
    );
  }
}

class _HouseholdInitData {
  final TaskCubit taskCubit;
  final ShoppingCubit shoppingCubit;
  final PingCubit pingCubit;
  final FirestoreSyncService syncService;
  final GroceryRepository groceryRepository;

  _HouseholdInitData({
    required this.taskCubit,
    required this.shoppingCubit,
    required this.pingCubit,
    required this.syncService,
    required this.groceryRepository,
  });
}

class _HouseholdAppContent extends StatefulWidget {
  final User user;
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
  StreamSubscription? shoppingWidgetSub;
  late MethodChannel widgetActionChannel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Listen to ShoppingCubit and push changes to the widget with debounce
    final shoppingCubit = context.read<ShoppingCubit>();
    shoppingWidgetSub = shoppingCubit.stream.listen((state) {
      WidgetService.instance.updateWidgetImmediate(state.items);
    });

    // Set up widget action channel
    widgetActionChannel = const MethodChannel('housekeepr/widget_actions');
    checkWidgetAction();

    // Process any pending toggles from the widget on startup
    processPendingToggles();
  }

  Future<void> checkWidgetAction() async {
    try {
      final result = await widgetActionChannel.invokeMethod<String>(
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
      processPendingToggles();
      checkWidgetAction();
    }

    if (mounted) {
      final items = context.read<ShoppingCubit>().state.items;
      WidgetService.instance.updateWidgetImmediate(items);
    }
  }

  Future<void> processPendingToggles() async {
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
    shoppingWidgetSub?.cancel();
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
  final User user;
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
  late Future<_HouseholdInitData> initFuture;
  Timer? initStageTimerShort;
  Timer? initStageTimerLong;
  String? initStageLabel;
  bool showInitGeneric = false;
  bool showInitDetailed = false;
  final List<String> initStageLog = [];

  @override
  void initState() {
    super.initState();
    startInitStageTimers();
    initFuture = initialize().whenComplete(stopInitStageTimers);
  }

  @override
  void dispose() {
    initStageTimerShort?.cancel();
    initStageTimerLong?.cancel();
    super.dispose();
  }

  void startInitStageTimers() {
    initStageTimerShort?.cancel();
    initStageTimerLong?.cancel();
    initStageLabel = null;
    showInitGeneric = false;
    showInitDetailed = false;

    initStageTimerShort = Timer(const Duration(seconds: 2), () {
      if (!mounted) return;
      setState(() => showInitGeneric = true);
    });

    initStageTimerLong = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() => showInitDetailed = true);
    });
  }

  void stopInitStageTimers() {
    initStageTimerShort?.cancel();
    initStageTimerLong?.cancel();
    if (!mounted) return;
    setState(() {
      initStageLabel = null;
      showInitGeneric = false;
      showInitDetailed = false;
    });
  }

  void setInitStageLabel(String label) {
    if (!mounted) return;
    final timestamp = DateTime.now().toIso8601String();
    initStageLog.add('$timestamp  $label');
    setState(() => initStageLabel = label);
  }

  void showInitStageDetails() {
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
              itemCount: initStageLog.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) {
                return Text(initStageLog[index]);
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

  void openTasksTab() {
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

  Future<void> maybeRequestNotificationPermissions(
    SettingsRepository settingsRepo,
  ) async {
    if (settingsRepo.notificationPermissionPrompted()) return;
    await NotificationService.instance.requestPermissions();
    await settingsRepo.setNotificationPermissionPrompted(true);
  }

  Future<_HouseholdInitData> initialize() async {
    initStageLog.clear();
    setInitStageLabel('Loading local preferences...');
    final prefs = await SharedPreferences.getInstance();
    setInitStageLabel('Opening local storage...');
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox('tasks'),
      Hive.openBox('tasks_meta'),
      Hive.openBox('groceries'),
      Hive.openBox('groceries_meta'),
      Hive.openBox('history'),
    ]);

    final settingsRepo = SettingsRepository(prefs);

    setInitStageLabel('Initializing notifications...');
    await NotificationService.instance.init(
      prefs,
      scaffoldKey: scaffoldMessengerKey,
      onOpenTasks: openTasksTab,
    );
    await maybeRequestNotificationPermissions(settingsRepo);
    await NotificationService.instance.checkAndFireDueReminders();
    setInitStageLabel('Initializing shopping products...');
    await ShoppingProductsService.instance.init(prefs);
    final taskCubit = TaskCubit(TaskRepository(prefs), settings: settingsRepo);
    final shoppingCubit = ShoppingCubit(GroceryRepository());

    setInitStageLabel('Initializing home widget...');
    await WidgetService.instance.init();
    await shoppingCubit.initializationFuture;
    await WidgetService.instance.updateWidgetImmediate(
      shoppingCubit.state.items,
    );

    FirebaseMessagingService.instance.init(
      shoppingCubit: shoppingCubit,
      householdId: widget.householdId,
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

    final pingCubit = PingCubit();
    final pingRepo = FirestorePingRepository(
      FirebaseFirestore.instance,
      householdId: widget.householdId,
    );
    pingCubit.setRepository(pingRepo, widget.user.uid);

    final syncService = FirestoreSyncService(FirebaseFirestore.instance);
    setInitStageLabel('Starting sync service...');
    await syncService.start(
      widget.user.uid,
      taskCubit,
      shoppingCubit,
      householdId: widget.householdId,
    );

    return _HouseholdInitData(
      taskCubit: taskCubit,
      shoppingCubit: shoppingCubit,
      pingCubit: pingCubit,
      syncService: syncService,
      groceryRepository: shoppingCubit.repository,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_HouseholdInitData>(
      future: initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          final stageText = showInitDetailed
              ? initStageLabel
              : (showInitGeneric ? 'Loading...' : null);
          return Scaffold(
            body: GestureDetector(
              onTap: showInitStageDetails,
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
                      startInitStageTimers();
                      setState(() {
                        initFuture = initialize().whenComplete(
                          stopInitStageTimers,
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
            BlocProvider<PingCubit>.value(value: data.pingCubit),
          ],
          child: RepositoryProvider<FirestoreSyncService>.value(
            value: data.syncService,
            child: _HouseholdAppContent(
              user: widget.user,
              syncService: data.syncService,
              groceryRepository: data.groceryRepository,
            ),
          ),
        );
      },
    );
  }
}
