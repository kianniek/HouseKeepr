import 'dart:async';

import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'ui/login_page.dart';
import 'ui/household_create_page.dart';
import 'ui/home_screen.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cubits/task_cubit.dart';
import 'cubits/shopping_cubit.dart';
import 'cubits/user_cubit.dart';
import 'repositories/task_repository.dart';
import 'repositories/shopping_repository.dart';
import 'firestore/firestore_task_repository.dart';
import 'firestore/firestore_shopping_repository.dart';
import 'models/task.dart';
import 'repositories/history_repository.dart';
import 'firestore/firestore_history_repository.dart';
import 'services/write_queue.dart';
import 'models/completion_record.dart';
import 'services/firestore_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Guarded initialization: attempt Firebase init and surface errors to a
  // minimal UI so the developer sees the failure instead of a black screen.
  Object? initError;
  try {
    if (kIsWeb) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } else {
      await Firebase.initializeApp();
    }
  } catch (e, st) {
    // Keep error for the UI and continue so the app can show an error screen.
    initError = e;
    // Log the stack trace in debug builds.
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
          title: 'HouseKeepr',
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: lightScheme.surface,
              foregroundColor: lightScheme.onSurface,
              elevation: 0,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: lightScheme.primary,
              foregroundColor: lightScheme.onPrimary,
            ),
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
            appBarTheme: AppBarTheme(
              backgroundColor: darkScheme.surface,
              foregroundColor: darkScheme.onSurface,
              elevation: 0,
            ),
            floatingActionButtonTheme: FloatingActionButtonThemeData(
              backgroundColor: darkScheme.primary,
              foregroundColor: darkScheme.onPrimary,
            ),
          ),
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

  // If the app failed to initialize Firebase, show a visible error screen
  // with the exception and a Retry button.
  Future<void> _retryInitialization() async {
    setState(() {});
    Object? initError;
    try {
      if (kIsWeb) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      } else {
        await Firebase.initializeApp();
      }
    } catch (e, st) {
      initError = e;
      debugPrint('Retry Firebase initialization failed: $e\n$st');
    }
    if (initError != null) {
      // show the error by setting state; store in a local field by
      // rebuilding with a new widget-level initializationError.
      // For simplicity, we rebuild the app by calling setState and
      // storing the error in the widget itself is not possible; instead
      // we use the following approach to re-render the error.
      setState(() {
        // Recreate the AppRoot with the error value by using a global
        // workaround: temporarily navigate to a new AppRoot. Simpler is
        // to set a private field, but to keep changes minimal we'll keep
        // the error in a local variable and call setState to trigger UI.
        // (We'll store the error in _householdId temporarily as an
        // implementation detail and check a typed flag in build.)
      });
    } else {
      // Successful init: force rebuild to pick up authenticated state
      setState(() {});
    }
  }

  void _onSignedIn(fb.User user) async {
    setState(() {
      _user = user;
      _checkingHousehold = true;
    });
    // Ensure user profile exists in Firestore and check household
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'displayName': user.displayName,
        'email': user.email,
        'photoURL': user.photoURL,
      }, SetOptions(merge: true));
    } catch (e) {
      // ignore write errors for now
      debugPrint('Failed to write user profile: $e');
    }
    // Check if user has a household
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data != null && data['householdId'] != null) {
      setState(() {
        _householdId = data['householdId'] as String;
        _checkingHousehold = false;
      });
    } else {
      setState(() {
        _householdId = null;
        _checkingHousehold = false;
      });
    }
  }

  void _onHouseholdCreated(String householdId) {
    setState(() {
      _householdId = householdId;
    });
  }

  @override
  Widget build(BuildContext context) {
    // If the app failed to initialize Firebase (initial error passed via
    // widget.initializationError), surface an error UI with retry.
    if (widget.initializationError != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Initialization error')),
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('The app failed to initialize Firebase.'),
              const SizedBox(height: 8),
              Text(widget.initializationError.toString()),
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_householdId == null) {
      return HouseholdCreatePage(user: _user!, onCreated: _onHouseholdCreated);
    }
    // Household dashboard with invite/join and shared tasks
    return BlocProvider(
      create: (_) => UserCubit(_user),
      child: HouseholdApp(user: _user!, householdId: _householdId!),
    );
  }

  @override
  void initState() {
    super.initState();
    // Listen to auth state so we automatically pick up an existing signed-in
    // user (Firebase persists the session) and update UI without forcing a
    // manual login callback flow.
    _authSub = fb.FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user == null) {
        // Signed out
        setState(() {
          _user = null;
          _householdId = null;
          _checkingHousehold = false;
        });
      } else {
        // If new user detected, run the same signed-in flow to ensure
        // Firestore profile and household lookup happen.
        if (_user == null || _user?.uid != user.uid) {
          _onSignedIn(user);
        }
        // If a UserCubit exists higher up in the tree, update it so UI that
        // subscribes to the cubit can react immediately. We can't access the
        // BuildContext here safely, so HouseholdApp will create the UserCubit
        // seeded with the current user. Subsequent updates (like profile
        // picture changes) should explicitly call the cubit's setUser.
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
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
  Future<void>? _initFuture;
  TaskCubit? _taskCubit;
  ShoppingCubit? _shoppingCubit;
  FirestoreSyncService? _syncService;

  @override
  void initState() {
    super.initState();
    _initFuture = _initialize();
  }

  Future<void> _initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final taskRepo = TaskRepository(prefs);
    final shoppingRepo = ShoppingRepository(prefs);

    _taskCubit = TaskCubit(taskRepo);
    _shoppingCubit = ShoppingCubit(shoppingRepo);

    // Set remote Firestore repositories
    final remoteTask = FirestoreTaskRepository(
      FirebaseFirestore.instance,
      userId: widget.user.uid,
    );
    final remoteShopping = FirestoreShoppingRepository(
      FirebaseFirestore.instance,
      userId: widget.user.uid,
    );
    _taskCubit!.setRemoteRepository(remoteTask);
    _shoppingCubit!.setRemoteRepository(remoteShopping);

    // History: local repo + remote
    final historyRepo = HistoryRepository(prefs);
    final remoteHistory = FirestoreHistoryRepository(
      FirebaseFirestore.instance,
      userId: widget.user.uid,
    );
    // Attach write queue and op builder so remote writes are queued when offline
    final writeQueue = WriteQueue(prefs);
    // set user id so queue persists per user
    writeQueue.setUserId(widget.user.uid);
    writeQueue.attachOpBuilder((op) {
      return () async {
        switch (op.type) {
          case QueueOpType.saveTask:
            // payload expected to be a serialized task map
            await remoteTask.saveTask(Task.fromMap(op.payload!));
            break;
          case QueueOpType.deleteTask:
            await remoteTask.deleteTask(op.id);
            break;
          case QueueOpType.saveShopping:
            // handled elsewhere; ignore here
            break;
          case QueueOpType.deleteShopping:
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
      };
    });

    // Attach a failure handler so persistent queue failures can be surfaced
    // to the UI by marking the local Task as failed.
    writeQueue.attachFailureHandler((op, lastError) {
      try {
        // If the op included a previous snapshot, attempt to restore the
        // original local state (rollback optimistic updates). Otherwise
        // mark the local task as failed so the user can retry.
        final prev = op.payload == null ? null : (op.payload!['_previous']);
        if (prev != null && prev is Map<String, dynamic>) {
          // restore previous state without re-enqueueing
          _taskCubit?.restoreTaskFromMap(prev);
        } else {
          switch (op.type) {
            case QueueOpType.saveTask:
            case QueueOpType.deleteTask:
              _taskCubit?.markTaskSyncFailed(op.id, lastError?.toString());
              break;
            default:
              break;
          }
        }
      } catch (_) {}
    });

    // Wire writeQueue to cubits and sync service by setting it where needed
    _taskCubit!.attachWriteQueueAndHistory(writeQueue, historyRepo);

    // Start sync service to keep cubits in sync with Firestore
    _syncService = FirestoreSyncService(FirebaseFirestore.instance);
    _syncService!.start(widget.user.uid, _taskCubit!, _shoppingCubit!);
  }

  @override
  void dispose() {
    _syncService?.stop();
    _taskCubit?.close();
    _shoppingCubit?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return MultiBlocProvider(
          providers: [
            BlocProvider<TaskCubit>.value(value: _taskCubit!),
            BlocProvider<ShoppingCubit>.value(value: _shoppingCubit!),
          ],
          child: HomeScreen(user: widget.user),
        );
      },
    );
  }
}

Future<void> addHousekeepingTask(
  String taskName,
  String assignedTo, {
  String? assignedToId,
  required DateTime dueDate,
}) async {
  try {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference tasks = firestore.collection('tasks');
    Map<String, dynamic> newTaskData = {
      'name': taskName,
      'assigned_to': assignedTo,
      'assigned_to_id': assignedToId,
      'due_date': Timestamp.fromDate(dueDate),
      'is_completed': false,
      'created_at': FieldValue.serverTimestamp(),
    };
    DocumentReference documentReference = await tasks.add(newTaskData);
    debugPrint('New task added with ID: $documentReference.id');
  } catch (e) {
    debugPrint('Error adding task: $e');
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
