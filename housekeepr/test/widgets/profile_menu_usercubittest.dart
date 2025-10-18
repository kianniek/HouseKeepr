import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/profile_menu.dart';
import 'package:housekeepr/cubits/user_cubit.dart';

// Minimal fake user object with the fields ProfileMenu needs.
class FakeUser {
  final String? photoURL;
  final String? email;
  FakeUser({this.photoURL, this.email});
}

void main() {
  testWidgets('ProfileMenu reflects UserCubit changes (avatar propagation)', (
    tester,
  ) async {
    // Start with null user in cubit
    final userCubit = UserCubit(null);

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<UserCubit>.value(
          value: userCubit,
          child: const Scaffold(body: ProfileMenu()),
        ),
      ),
    );

    // Initially no user -> CircleAvatar should show Icon
    expect(find.byIcon(Icons.person), findsOneWidget);

    // Now update cubit with a fake user that has a photoURL. Because ProfileMenu
    // expects an fb.User type, we'll provide a dynamic object that has the same
    // properties accessed (photoURL and email). The Bloc type is fb.User?, but
    // Dart's runtime typing allows passing a dynamic here in tests.
    final dynamic u = FakeUser(
      photoURL: 'https://example.com/avatar.png',
      email: 'a@b.com',
    );
    userCubit.setUser(u);
    await tester.pumpAndSettle();

    // After update the Icon should be gone and a CircleAvatar with NetworkImage used.
    expect(find.byIcon(Icons.person), findsNothing);
    final avatar = find.byType(CircleAvatar);
    expect(avatar, findsOneWidget);
  });
}
