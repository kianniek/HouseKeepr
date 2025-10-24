import 'dart:io';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:housekeepr/firestore/firestore_task_repository.dart';
import 'package:housekeepr/models/task.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('FirestoreTaskRepository integration (emulator) - device', () {
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

      try {
        // Initialize with minimal options if necessary; on device the
        // generated firebase_options.dart should also work if present.
        await Firebase.initializeApp();
        firestore = FirebaseFirestore.instance;
        emulatorAvailable = true;

        // If FIRESTORE_EMULATOR_HOST is set, configure the firestore
        // instance to use emulator (older SDKs/compatibility).
        try {
          if (host.isNotEmpty && firestore != null) {
            if (parts.length == 2) {
              firestore!.useFirestoreEmulator(parts[0], port);
            }
          }
        } catch (_) {}
      } catch (e) {
        emulatorAvailable = false;
        debugPrint('Firebase.initializeApp() failed during setUpAll: $e');
      }
    });

    testWidgets('save/load task preserves deadline and repeatDays', (
      tester,
    ) async {
      if (!emulatorAvailable || firestore == null) {
        debugPrint(
          'Firestore emulator not initialized; skipping integration test',
        );
        return;
      }

      final userId = 'integration-test-user';
      final repo = FirestoreTaskRepository(firestore!, userId: userId);

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

      await repo.saveTask(t);

      final tasks = await repo.loadTasks();
      final found = tasks.firstWhere((e) => e.id == 't1');

      expect(found.title, t.title);
      expect(found.deadline?.toUtc(), equals(t.deadline?.toUtc()));
      expect(found.repeatDays, equals(t.repeatDays));
    });
  });
}
