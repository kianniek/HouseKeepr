import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';
import 'ui/login_page.dart';
import 'ui/household_create_page.dart';
import 'ui/household_dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HouseKeepr',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 247, 136, 1),
        ),
      ),
      home: const AppRoot(),
    );
  }
}

class AppRoot extends StatefulWidget {
  const AppRoot({super.key});

  @override
  State<AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<AppRoot> {
  fb.User? _user;
  String? _householdId;
  bool _checkingHousehold = false;

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
      print('Failed to write user profile: $e');
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
    return HouseholdDashboardPage(householdId: _householdId!, user: _user!);
  }
}

Future<void> addHousekeepingTask(
  String taskName,
  String assignedTo,
  DateTime dueDate,
) async {
  try {
    FirebaseFirestore firestore = FirebaseFirestore.instance;
    CollectionReference tasks = firestore.collection('tasks');
    Map<String, dynamic> newTaskData = {
      'name': taskName,
      'assigned_to': assignedTo,
      'due_date': Timestamp.fromDate(dueDate),
      'is_completed': false,
      'created_at': FieldValue.serverTimestamp(),
    };
    DocumentReference documentReference = await tasks.add(newTaskData);
    print('New task added with ID: \\${documentReference.id}');
  } catch (e) {
    print('Error adding task: \\${e}');
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
