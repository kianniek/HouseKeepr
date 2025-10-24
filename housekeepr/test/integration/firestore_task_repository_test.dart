import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:housekeepr/firestore/firestore_task_repository.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FirestoreTaskRepository integration (emulator)', () {
    FirebaseFirestore? firestore;
    var emulatorAvailable = false;

    setUpAll(() async {
      // If FIRESTORE_EMULATOR_HOST is not provided, skip emulator tests.
      final host = const String.fromEnvironment(
        'FIRESTORE_EMULATOR_HOST',
        defaultValue: '',
      );
      if (host.isEmpty) {
        emulatorAvailable = false;
        debugPrint(
          'FIRESTORE_EMULATOR_HOST not set; skipping emulator integration tests.',
        );
        return;
      }

      // Validate host:port and test connectivity before attempting to initialize
      final parts = host.split(':');
      if (parts.length != 2) {
        emulatorAvailable = false;
        debugPrint(
          'FIRESTORE_EMULATOR_HOST invalid (expected host:port): $host',
        );
        return;
      }

      final int? port = int.tryParse(parts[1]);
      if (port == null) {
        emulatorAvailable = false;
        debugPrint('FIRESTORE_EMULATOR_HOST has invalid port: $host');
        return;
      }

      // Helper to quickly test TCP connectivity to an emulator host/port.
      Future<bool> isHostOpen(
        String host,
        int port, {
        Duration timeout = const Duration(seconds: 2),
      }) async {
        try {
          final socket = await Socket.connect(host, port, timeout: timeout);
          socket.destroy();
          return true;
        } catch (_) {
          return false;
        }
      }

      final reachable = await isHostOpen(
        parts[0],
        port,
        timeout: const Duration(seconds: 2),
      );
      if (!reachable) {
        emulatorAvailable = false;
        debugPrint(
          'Firestore emulator not reachable at $host; skipping integration tests.',
        );
        return;
      }

      // Try to initialize Firebase now that the emulator appears reachable.
      try {
        await Firebase.initializeApp(
          options: FirebaseOptions(
            apiKey: 'fake',
            appId: '1:fake:fake',
            messagingSenderId: '0',
            projectId: const String.fromEnvironment(
              'FIREBASE_PROJECT_ID',
              defaultValue: 'demo-project',
            ),
          ),
        );

        firestore = FirebaseFirestore.instance;
        emulatorAvailable = true;

        // Configure the firestore instance to use emulator if present.
        try {
          if (parts.length == 2 && firestore != null) {
            firestore!.useFirestoreEmulator(parts[0], port);
          }
        } catch (_) {}
      } catch (e) {
        emulatorAvailable = false;
        debugPrint('Firebase.initializeApp() failed during setUpAll: $e');
      }
    });

    // (helper declared and used inside setUpAll)

    test('save/load task preserves deadline and repeatDays', () async {
      // Skip if Firestore doesn't appear to be available (emulator not running)
      if (!emulatorAvailable || firestore == null) {
        debugPrint(
          'Firestore emulator not initialized; skipping integration test',
        );
        return;
      }

      final userId = 'integration-test-user';
      final repo = FirestoreTaskRepository(firestore!, userId: userId);

      // Create a deterministic task
      final t = Task(
        id: 't1',
        title: 'Integration Test Task',
        description: 'deadline + repeatDays check',
        assignedToId: 'u1',
        assignedToName: 'Tester',
        priority: TaskPriority.high,
        deadline: DateTime.utc(2025, 10, 21, 15, 30),
        isRepeating: true,
        repeatRule: 'weekly',
        repeatDays: [1, 3, 5],
        isHouseholdTask: false,
      );

      // Save
      await repo.saveTask(t);

      // Load and assert
      final tasks = await repo.loadTasks();
      final found = tasks.firstWhere((e) => e.id == 't1');

      expect(found.title, t.title);
      // deadline should be parsed and preserved (UTC)
      expect(found.deadline?.toUtc(), equals(t.deadline?.toUtc()));
      expect(found.repeatDays, equals(t.repeatDays));
    });
  });
}
