import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Lightweight abstraction around platform services used by ProfilePage.
/// Implementations are trivial wrappers around Firebase APIs to keep runtime
/// behavior unchanged while allowing tests to inject fakes.
class ProfileApis {
  const ProfileApis({
    this.auth = const _FirebaseAuthApi(),
    this.firestore = const _FirebaseFirestoreApi(),
    this.storage = const _FirebaseStorageApi(),
    this.picker = const _ImagePickerApi(),
    this.useCropper = true,
    this.skipImageProcessing = false,
  });

  final AuthApi auth;
  final FirestoreApi firestore;
  final StorageApi storage;
  final ImagePickerApi picker;
  final bool useCropper;
  final bool skipImageProcessing;
}

/// Auth wrapper
abstract class AuthApi {
  fb.User? get currentUser;
}

class _FirebaseAuthApi implements AuthApi {
  const _FirebaseAuthApi();
  @override
  fb.User? get currentUser => fb.FirebaseAuth.instance.currentUser;
}

/// Firestore wrapper
abstract class FirestoreApi {
  FirestoreCollection collection(String path);
}

class _FirebaseFirestoreApi implements FirestoreApi {
  const _FirebaseFirestoreApi();
  @override
  FirestoreCollection collection(String path) =>
      _FirebaseFirestoreCollection(FirebaseFirestore.instance.collection(path));
}

/// Minimal wrapper interfaces so tests can provide fakes without depending on
/// the concrete firebase types.
abstract class FirestoreCollection {
  FirestoreDocument doc(String id);
}

abstract class FirestoreDocument {
  Future<void> set(Map<String, dynamic> data, {bool merge});
}

class _FirebaseFirestoreCollection implements FirestoreCollection {
  final CollectionReference _inner;
  _FirebaseFirestoreCollection(this._inner);
  @override
  FirestoreDocument doc(String id) =>
      _FirebaseFirestoreDocument(_inner.doc(id));
}

class _FirebaseFirestoreDocument implements FirestoreDocument {
  final DocumentReference _inner;
  _FirebaseFirestoreDocument(this._inner);
  @override
  Future<void> set(Map<String, dynamic> data, {bool merge = false}) =>
      _inner.set(data, SetOptions(merge: merge));
}

/// Storage wrapper
abstract class StorageApi {
  StorageRef ref(String path);
}

abstract class StorageRef {
  Future<void> putData(Uint8List data, [dynamic metadata]);
  Future<String> getDownloadURL();
}

class _FirebaseStorageApi implements StorageApi {
  const _FirebaseStorageApi();
  @override
  StorageRef ref(String path) =>
      _FirebaseStorageRef(FirebaseStorage.instance.ref().child(path));
}

class _FirebaseStorageRef implements StorageRef {
  final Reference _inner;
  _FirebaseStorageRef(this._inner);
  @override
  Future<void> putData(Uint8List data, [dynamic metadata]) =>
      _inner.putData(data, metadata).then((_) => null);
  @override
  Future<String> getDownloadURL() => _inner.getDownloadURL();
}

/// Image picker wrapper
abstract class ImagePickerApi {
  /// Returns a platform-specific picked file object. The object must expose
  /// `.path` and `.readAsBytes()` as used by `ProfilePage`.
  Future<dynamic> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  });
}

class _ImagePickerApi implements ImagePickerApi {
  const _ImagePickerApi();
  @override
  Future<dynamic> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) {
    final picker = ImagePicker();
    return picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }
}
