// import 'package:firebase_core/firebase_core.dart';
// import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:housekeepr/ui/profile_page.dart';
import 'package:housekeepr/cubits/user_cubit.dart';
import 'package:housekeepr/services/profile_apis.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;

void setupFirebaseMocks() {
  TestWidgetsFlutterBinding.ensureInitialized();
}

// Fake implementations
class FakeXFile {
  final Uint8List bytes;
  final String path;
  FakeXFile(this.bytes, this.path);
  Future<Uint8List> readAsBytes() async => bytes;
}

class FakeImagePickerApi implements ImagePickerApi {
  final FakeXFile? file;
  FakeImagePickerApi(this.file);

  @override
  Future<dynamic> pickImage({
    required source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    return file == null ? null : _AsXFile(file!);
  }
}

// Wrapper to match package:image_picker XFile minimal API
class _AsXFile {
  final FakeXFile _f;
  _AsXFile(this._f);
  String get path => _f.path;
  Future<Uint8List> readAsBytes() => _f.readAsBytes();
}

class FakeStorageRef implements StorageRef {
  Uint8List? lastPut;
  String? url;
  FakeStorageRef({this.url});
  @override
  Future<void> putData(Uint8List data, [dynamic metadata]) async {
    lastPut = data;
  }

  @override
  Future<String> getDownloadURL() async =>
      url ?? 'https://example.com/avatar.jpg';
}

class FakeStorageApi implements StorageApi {
  final FakeStorageRef refImpl;
  FakeStorageApi(this.refImpl);
  @override
  StorageRef ref(String path) => refImpl;
}

class FakeAuthApi implements AuthApi {
  final fb.User? _user;
  FakeAuthApi(this._user);
  @override
  fb.User? get currentUser => _user;
}

class FakeFirestoreApi implements FirestoreApi {
  Map<String, Map<String, dynamic>> storage = {};
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

  @override
  Future<Map<String, dynamic>?> get() async => storage[id];
}

void main() {
  setupFirebaseMocks();
  testWidgets('ProfilePage upload flow uses injected apis', (tester) async {
    // Provide a fake user object with minimal API used by ProfilePage
    final fakeUser = _FakeFbUser(
      uid: 'uid1',
      displayName: 'Old',
      photoURL: null,
      email: 'a@b.com',
    );
    final userCubit = UserCubit(fakeUser);

    // Minimal valid PNG (1x1 transparent)
    final pngBytes = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
      0x00,
      0x00,
      0x00,
      0x0D,
      0x49,
      0x48,
      0x44,
      0x52,
      0x00,
      0x00,
      0x00,
      0x01,
      0x00,
      0x00,
      0x00,
      0x01,
      0x08,
      0x06,
      0x00,
      0x00,
      0x00,
      0x1F,
      0x15,
      0xC4,
      0x89,
      0x00,
      0x00,
      0x00,
      0x0A,
      0x49,
      0x44,
      0x41,
      0x54,
      0x78,
      0x9C,
      0x63,
      0x00,
      0x01,
      0x00,
      0x00,
      0x05,
      0x00,
      0x01,
      0x0D,
      0x0A,
      0x2D,
      0xB4,
      0x00,
      0x00,
      0x00,
      0x00,
      0x49,
      0x45,
      0x4E,
      0x44,
      0xAE,
      0x42,
      0x60,
      0x82,
    ]);
    // Use an in-memory fake file; ProfilePage will call readAsBytes()
    final fakeFile = FakeXFile(pngBytes, '');
    final picker = FakeImagePickerApi(fakeFile);

    final storageRef = FakeStorageRef();
    final storageApi = FakeStorageApi(storageRef);
    final firestore = FakeFirestoreApi();
    final authApi = FakeAuthApi(fakeUser);

    final apis = ProfileApis(
      auth: authApi,
      firestore: firestore,
      storage: storageApi,
      picker: picker,
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

    // Tap change photo button
    expect(find.text('Change photo'), findsOneWidget);
    await tester.tap(find.text('Change photo'));
    await tester.pump();
    // Pump frames until the fake storage receives data or we timeout.
    for (var i = 0; i < 50 && storageRef.lastPut == null; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    // After the flow completes, storageRef.lastPut should be set
    expect(storageRef.lastPut, isNotNull);
    // no file cleanup needed for in-memory fake
  });
}

// Minimal fake fb.User used for tests. Only methods/fields used are implemented.
class _FakeFbUser implements fb.User {
  @override
  final String uid;
  @override
  String? displayName;
  @override
  String? photoURL;
  @override
  final String? email;

  _FakeFbUser({required this.uid, this.displayName, this.photoURL, this.email});

  @override
  Future<void> updateProfile({String? displayName, String? photoURL}) async {
    this.displayName = displayName ?? this.displayName;
    this.photoURL = photoURL ?? this.photoURL;
  }

  @override
  Future<void> reload() async {}

  // The rest of fb.User is unimplemented; use noSuchMethod to avoid large surface.
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
