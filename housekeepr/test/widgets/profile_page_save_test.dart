import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/profile_page.dart';
import 'package:housekeepr/cubits/user_cubit.dart';
import 'package:housekeepr/services/profile_apis.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

// Minimal fake fb.User
class _FakeFbUser implements fb.User {
  @override
  final String uid;
  @override
  String? displayName;

  @override
  String? photoURL;
  @override
  String? email;

  _FakeFbUser({required this.uid, this.displayName, this.photoURL, this.email});

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    this.displayName = displayName ?? this.displayName;
    this.photoURL = photoURL ?? this.photoURL;
  }

  @override
  Future<void> reload() async {}

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Fake Firestore backing storage
class FakeFirestoreApi implements FirestoreApi {
  final Map<String, Map<String, dynamic>> storage = {};
  @override
  FirestoreCollection collection(String path) => _FakeCollection(storage);
}

class _FakeCollection implements FirestoreCollection {
  final Map<String, Map<String, dynamic>> storage;
  _FakeCollection(this.storage);
  @override
  FirestoreDocument doc(String id) => _FakeDoc(storage, id);
}

class _FakeDoc implements FirestoreDocument {
  final Map<String, Map<String, dynamic>> storage;
  final String id;
  _FakeDoc(this.storage, this.id);
  @override
  Future<void> set(Map<String, dynamic> data, {bool merge = false}) async {
    storage[id] = {...?storage[id], ...data};
  }
}

class FakeAuthApi implements AuthApi {
  final fb.User? _user;
  FakeAuthApi(this._user);
  @override
  fb.User? get currentUser => _user;
}

void main() {
  testWidgets('ProfilePage save updates firestore and user profile', (
    tester,
  ) async {
    final fakeUser = _FakeFbUser(
      uid: 'u1',
      displayName: 'Old',
      photoURL: null,
      email: 'a@b.com',
    );
    final userCubit = UserCubit(fakeUser);

    final firestore = FakeFirestoreApi();
    final authApi = FakeAuthApi(fakeUser);
    final apis = ProfileApis(
      auth: authApi,
      firestore: firestore,
      storage: const _NoopStorageApi(),
      picker: const _NoopPicker(),
      useCropper: false,
      skipImageProcessing: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider<UserCubit>.value(
          value: userCubit,
          child: ProfilePage(user: fakeUser, apis: apis),
        ),
      ),
    );

    // Ensure display name is initially the user's name
    expect(find.widgetWithText(TextField, 'Old'), findsOneWidget);

    // Enter a new name
    await tester.enterText(find.byType(TextField), 'New Name');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // Firestore should have an entry for the user with displayName
    expect(firestore.storage['u1']?['displayName'], 'New Name');
    // The fake user's displayName should be updated after updateProfile/reload
    expect(fakeUser.displayName, 'New Name');
  });
}

// No-op implementations to satisfy ProfileApis types for this test
class _NoopStorageApi implements StorageApi {
  const _NoopStorageApi();
  @override
  StorageRef ref(String path) => throw UnimplementedError();
}

class _NoopPicker implements ImagePickerApi {
  const _NoopPicker();
  @override
  Future<dynamic> pickImage({
    required source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async => null;
}
