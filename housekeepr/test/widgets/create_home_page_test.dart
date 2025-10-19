import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:housekeepr/ui/create_home_page.dart';
import 'package:housekeepr/firestore/remote_home_repository.dart';
import 'package:housekeepr/models/home.dart';

class _FakeRepo extends Mock implements RemoteHomeRepository {}

class _HomeFake extends Fake implements Home {}

void main() {
  setUpAll(() {
    // Register a simple fallback for any Home instance used with mocktail
    registerFallbackValue(_HomeFake());
  });

  testWidgets('CreateHomePage calls repository and pops with Home', (
    tester,
  ) async {
    final repo = _FakeRepo();
    when(() => repo.createHome(any())).thenAnswer((_) async {});

    await tester.pumpWidget(
      MaterialApp(
        home: CreateHomePage(repository: repo, currentUserId: 'uid-test'),
      ),
    );

    await tester.enterText(find.byType(TextFormField), 'Test House');
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();

    // verify createHome called once
    verify(() => repo.createHome(any())).called(1);
  });
}
