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
import 'cubits/shopping_cubit.dart';
import 'cubits/task_cubit.dart';
import 'cubits/user_cubit.dart';
import 'firebase_options.dart';
import 'firestore/firestore_history_repository.dart';
import 'firestore/firestore_household_grocery_repository.dart';
import 'firestore/firestore_household_task_repository.dart';
import 'firestore/firestore_task_repository.dart';
import 'generated/app_localizations.dart';
import 'models/completion_record.dart';
import 'models/grocery_item.dart';
import 'models/task.dart';
import 'repositories/grocery_repository.dart';
import 'repositories/history_repository.dart';
import 'repositories/local_medication_repository.dart';
import 'repositories/task_repository.dart';
import 'services/app_action_handler.dart';
import 'services/firebase_messaging_service.dart';
import 'services/firestore_sync_service.dart';
import 'services/household_service.dart';
import 'services/notification_service.dart';
import 'services/shopping_products_service.dart';
import 'services/theme_controller.dart';
import 'ui/common/app_theme.dart';
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

  final initialUid = Firebase.apps.isNotEmpty
      ? FirebaseAuth.instance.currentUser?.uid
      : null;
  await ThemeController.instance.load(userId: initialUid);

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
              theme: ThemeData(
                colorScheme: lightScheme,
                useMaterial3: true,
                extensions: const [AppSemanticColors.light],
              ),
              darkTheme: ThemeData(
                colorScheme: darkScheme,
                useMaterial3: true,
                extensions: const [AppSemanticColors.dark],
              ),
              themeMode: controller.themeMode,
              home: AppRoot(initializationError: widget.initializationError),
            );
          },
        );
      },
    );
  }
}

/// Shared stage-progress tracker for startup and household initialization.
/// Escalates from spinner (0–2s) to `'Loading...'` (2–5s) to the current stage
/// label (5s+) and records a timestamped log viewable on tap.
class _StageProgressController extends ChangeNotifier {
  Timer? _shortTimer;
  Timer? _longTimer;
  String? stageLabel;
  bool showGeneric = false;
  bool showDetailed = false;
  final List<String> log = [];

  void start() {
    _shortTimer?.cancel();
    _longTimer?.cancel();
    stageLabel = null;
    showGeneric = false;
    showDetailed = false;

    _shortTimer = Timer(const Duration(seconds: 2), () {
      showGeneric = true;
      notifyListeners();
    });

    _longTimer = Timer(const Duration(seconds: 5), () {
      showDetailed = true;
      notifyListeners();
    });
  }

  void stop() {
    _shortTimer?.cancel();
    _longTimer?.cancel();
    stageLabel = null;
    showGeneric = false;
    showDetailed = false;
    notifyListeners();
  }

  void addLog(String entry) {
    log.add('${DateTime.now().toIso8601String()}  $entry');
  }

  void setStage(String label) {
    addLog(label);
    stageLabel = label;
    notifyListeners();
  }

  void showDetailsDialog(BuildContext context, {required String title}) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: log.length,
              separatorBuilder: (context, index) => const Divider(height: 12),
              itemBuilder: (context, index) => Text(log[index]),
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

  @override
  void dispose() {
    _shortTimer?.cancel();
    _longTimer?.cancel();
    super.dispose();
  }
}

class _StageLoadingScaffold extends StatelessWidget {
  final _StageProgressController controller;
  final String detailsTitle;

  const _StageLoadingScaffold({
    required this.controller,
    required this.detailsTitle,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final stageText = controller.showDetailed
            ? controller.stageLabel
            : (controller.showGeneric ? 'Loading...' : null);
        return Scaffold(
          body: GestureDetector(
            onTap: () =>
                controller.showDetailsDialog(context, title: detailsTitle),
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
  final _stageController = _StageProgressController();

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
    _stageController.dispose();
    super.dispose();
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
    authSub = FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
      unawaited(ThemeController.instance.setUserId(firebaseUser?.uid));
      if (!mounted) return;
      if (firebaseUser == null) {
        setState(() {
          user = null;
          householdId = null;
          checkingHousehold = false;
        });
      } else if (user?.uid != firebaseUser.uid) {
        onSignedIn(firebaseUser);
      }
    });
  }

  void onSignedIn(User user) async {
    _stageController.start();
    _stageController.log.clear();
    setState(() {
      this.user = user;
      checkingHousehold = true;
      _stageController.stageLabel = 'Saving user profile...';
    });
    _stageController.addLog(
      'Saving user profile for user ${user.uid} (${user.email})',
    );
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
      }, SetOptions(merge: true));

      final hs = HouseholdService(FirebaseFirestore.instance);
      if (mounted && checkingHousehold) {
        _stageController.setStage('Fetching household membership...');
      }
      final hid = await hs.findHouseholdForUser(user.uid);
      setState(() {
        householdId = hid;
        checkingHousehold = false;
        _stageController.stop();
      });
    } catch (e) {
      debugPrint('Sign-in processing failed: $e');
      setState(() {
        checkingHousehold = false;
        _stageController.stop();
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
      return _StageLoadingScaffold(
        controller: _stageController,
        detailsTitle: 'Household loading details',
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
  final User user;
  final String householdId;
  final FirestoreSyncService syncService;
  final GroceryRepository groceryRepository;

  const _HouseholdAppContent({
    required this.user,
    required this.householdId,
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
      _syncPillWidgetOnResume();
      checkWidgetAction();
      AppActionHandler().checkWidgetConfigContext(context);
    }

    if (mounted) {
      final items = context.read<ShoppingCubit>().state.items;
      WidgetService.instance.updateWidgetImmediate(items);
    }
  }

  Future<void> _syncPillWidgetOnResume() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.reload();
      final repo = LocalMedicationRepository(prefs: prefs);
      await WidgetService.instance.processPendingPillToggles(repo);
      final summary = await repo.getWidgetSummary(DateTime.now());
      await WidgetService.instance.updateMedicationWidget(summary);
    } catch (_) {}
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
    return HomeScreen(key: homeScreenKey, householdId: widget.householdId);
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
  final _stageController = _StageProgressController();

  @override
  void initState() {
    super.initState();
    _stageController.start();
    initFuture = initialize().whenComplete(() {
      if (mounted) _stageController.stop();
    });
  }

  @override
  void dispose() {
    _stageController.dispose();
    super.dispose();
  }

  void _setInitStageLabel(String label) {
    if (!mounted) return;
    _stageController.setStage(label);
  }

  void _openTab(HomeTab tab) {
    final homeState = homeScreenKey.currentState;
    if (homeState != null) {
      homeState.selectTab(tab);
      return;
    }
    final navState = navigatorKey.currentState;
    if (navState != null) {
      navState.popUntil((route) => route.isFirst);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      homeScreenKey.currentState?.selectTab(tab);
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
    _stageController.log.clear();
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

    _setInitStageLabel('Initializing notifications...');
    await NotificationService.instance.init(
      prefs,
      scaffoldKey: scaffoldMessengerKey,
      onOpenTasks: () => _openTab(HomeTab.tasks),
      onOpenTasksRebalance: () {
        _openTab(HomeTab.tasks);
        HomeScreen.highlightAutoBalanceNotifier.value++;
      },
      onOpenMedications: () => _openTab(HomeTab.tools),
      userId: widget.user.uid,
    );
    await maybeRequestNotificationPermissions(settingsRepo);
    await NotificationService.instance.checkAndFireDueReminders();
    _setInitStageLabel('Initializing shopping products...');
    await ShoppingProductsService.instance.init(prefs);
    final taskCubit = TaskCubit(TaskRepository(prefs), settings: settingsRepo);
    final shoppingCubit = ShoppingCubit(GroceryRepository());

    _setInitStageLabel('Initializing home widget...');
    await WidgetService.instance.init();
    await shoppingCubit.initializationFuture;
    await WidgetService.instance.updateWidgetImmediate(
      shoppingCubit.state.items,
    );
    final medicationRepo = LocalMedicationRepository(prefs: prefs);
    await WidgetService.instance.processPendingPillToggles(medicationRepo);
    final pillSummary = await medicationRepo.getWidgetSummary(DateTime.now());
    await WidgetService.instance.updateMedicationWidget(pillSummary);

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
      future: initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _StageLoadingScaffold(
            controller: _stageController,
            detailsTitle: 'Initialization details',
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
                      _stageController.start();
                      setState(() {
                        initFuture = initialize().whenComplete(() {
                          if (mounted) _stageController.stop();
                        });
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
          child: RepositoryProvider<FirestoreSyncService>.value(
            value: data.syncService,
            child: _HouseholdAppContent(
              user: widget.user,
              householdId: widget.householdId,
              syncService: data.syncService,
              groceryRepository: data.groceryRepository,
            ),
          ),
        );
      },
    );
  }
}
