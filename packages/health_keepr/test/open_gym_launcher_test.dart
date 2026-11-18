import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:health_keepr/health_keepr.dart';

class _FakeHealthDataStore implements HealthDataStore {
  @override
  Future<void> clearModuleData(String moduleId) async {}

  @override
  Future<void> close() async {}

  @override
  Future<void> deleteRecord(
    String moduleId,
    String collection,
    String id,
  ) async {}

  @override
  Future<List<Map<String, dynamic>>> readCollection(
    String moduleId,
    String collection,
  ) async => <Map<String, dynamic>>[];

  @override
  Future<Map<String, dynamic>?> readRecord(
    String moduleId,
    String collection,
    String id,
  ) async => null;

  @override
  Future<void> upsertRecord(
    String moduleId,
    String collection,
    Map<String, dynamic> record,
  ) async {}
}

void main() {
  testWidgets('OpenGymInstallDialog shows live status and download progress', (
    tester,
  ) async {
    final controller = StreamController<DeferredInstallProgress>.broadcast();
    var cancelled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenGymInstallDialog(
            progressStream: controller.stream,
            onCancel: () {
              cancelled = true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Installing OpenGym'), findsOneWidget);
    expect(find.text('Connecting to Google Play...'), findsOneWidget);
    expect(find.text('0:00'), findsOneWidget);

    controller.add(
      const DeferredInstallProgress(
        moduleName: 'openGym',
        status: 'pending',
      ),
    );
    await tester.pump();
    expect(find.text('Waiting in Google Play queue...'), findsOneWidget);

    controller.add(
      const DeferredInstallProgress(
        moduleName: 'openGym',
        status: 'downloading',
        bytesDownloaded: 5 * 1024 * 1024,
        totalBytesToDownload: 10 * 1024 * 1024,
      ),
    );
    await tester.pump();
    expect(find.text('Downloading OpenGym...'), findsOneWidget);
    expect(find.text('5.0 MB / 10.0 MB (50%)'), findsOneWidget);

    final indicator = tester.widget<LinearProgressIndicator>(
      find.byType(LinearProgressIndicator),
    );
    expect(indicator.value, closeTo(0.5, 0.01));

    controller.add(
      const DeferredInstallProgress(
        moduleName: 'openGym',
        status: 'installing',
      ),
    );
    await tester.pump();
    expect(find.text('Installing OpenGym module...'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(cancelled, isTrue);

    await controller.close();
  });

  testWidgets('OpenGymInstallDialog shows stall hint when no progress occurs', (
    tester,
  ) async {
    final controller = StreamController<DeferredInstallProgress>.broadcast();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OpenGymInstallDialog(
            progressStream: controller.stream,
            onCancel: () {},
            stallThreshold: const Duration(seconds: 3),
          ),
        ),
      ),
    );

    expect(find.textContaining('Taking longer than usual'), findsNothing);

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('0:03'), findsOneWidget);
    expect(find.textContaining('Taking longer than usual'), findsOneWidget);

    // Progress resumes -> stall hint clears.
    controller.add(
      const DeferredInstallProgress(
        moduleName: 'openGym',
        status: 'downloading',
        bytesDownloaded: 1024 * 1024,
        totalBytesToDownload: 4 * 1024 * 1024,
      ),
    );
    await tester.pump();
    expect(find.textContaining('Taking longer than usual'), findsNothing);

    await controller.close();
  });

  testWidgets('OpenGymLauncher.launch handles cancel without throwing', (
    tester,
  ) async {
    final completer = Completer<void>();
    final progress = StreamController<DeferredInstallProgress>.broadcast();
    var cancelCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                OpenGymLauncher.launch(
                  context,
                  _FakeHealthDataStore(),
                  libraryLoader: () => completer.future,
                  progressStream: progress.stream,
                  onCancelInstall: () async {
                    cancelCalled = true;
                  },
                );
              },
              child: const Text('Launch'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await tester.pump();
    expect(find.text('Installing OpenGym'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(cancelCalled, isTrue);
    expect(find.text('Installing OpenGym'), findsNothing);

    // Late completion after cancel should be a no-op.
    completer.complete();
    await tester.pumpAndSettle();
    expect(OpenGymLauncher.isLoaded, isFalse);

    await progress.close();
  });

  testWidgets('OpenGymLauncher.launch shows error snackbar on failure', (
    tester,
  ) async {
    final completer = Completer<void>();
    final progress = StreamController<DeferredInstallProgress>.broadcast();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () {
                OpenGymLauncher.launch(
                  context,
                  _FakeHealthDataStore(),
                  libraryLoader: () => completer.future,
                  progressStream: progress.stream,
                );
              },
              child: const Text('Launch'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Launch'));
    await tester.pump();
    expect(find.text('Installing OpenGym'), findsOneWidget);

    completer.completeError(Exception('Network error'));
    await tester.pumpAndSettle();

    expect(find.text('Installing OpenGym'), findsNothing);
    expect(find.textContaining('Failed to install OpenGym'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await progress.close();
  });
}
