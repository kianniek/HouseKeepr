import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'dart:typed_data';
import 'simple_cropper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubits/user_cubit.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../services/profile_apis.dart';

class ProfilePage extends StatefulWidget {
  final fb.User user;
  final ProfileApis apis;

  /// [apis] is optional and defaults to real Firebase/ImagePicker
  /// implementations. Tests can pass a fake [ProfileApis] to isolate
  /// platform interactions.
  const ProfilePage({
    super.key,
    required this.user,
    this.apis = const ProfileApis(),
  });

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  Color? _selectedColor;
  final TextEditingController _nameCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.user.displayName ?? '';
    // Load color from Firestore if available
    widget.apis.firestore.collection('users').doc(widget.user.uid).get().then((
      data,
    ) {
      if (data != null && data['personalColor'] != null) {
        setState(() {
          _selectedColor = Color(data['personalColor'] as int);
        });
      }
    });
  }

  Future<void> _pickAndUploadPhoto() async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final picked = await widget.apis.picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;
    if (!mounted) return;
    // Optionally crop on non-web platforms using our SimpleCropper
    Uint8List? croppedBytes;
    String? path = picked.path;
    if (!kIsWeb && widget.apis.useCropper) {
      // open simple cropper which returns bytes
      final bytes = await navigator.push(
        MaterialPageRoute(
          builder: (_) => SimpleCropper(imagePath: picked.path),
        ),
      );
      if (!mounted) return;
      if (bytes != null && bytes is Uint8List) {
        croppedBytes = bytes;
      }
    }
    // Ensure widget still mounted before showing modal progress
    if (!mounted) return;
    // Show modal progress
    setState(() => _saving = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final uid = widget.user.uid;
      final ref = widget.apis.storage.ref('users/$uid/profile.jpg');

      Uint8List uploadBytes;
      if (widget.apis.skipImageProcessing) {
        // In tests we may skip decoding/resizing and upload the raw bytes
        final bytes = croppedBytes ?? await picked.readAsBytes();
        if (!mounted) return;
        uploadBytes = bytes;
        await ref.putData(uploadBytes, null);
      } else if (croppedBytes != null) {
        // compress/resize cropped PNG bytes
        final decoded = img.decodeImage(croppedBytes)!;
        final resized = img.copyResize(decoded, width: 800);
        uploadBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
        await ref.putData(
          uploadBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else if (kIsWeb) {
        final bytes = await picked.readAsBytes();
        if (!mounted) return;
        // decode and re-encode to control size
        final decoded = img.decodeImage(bytes)!;
        final resized = img.copyResize(decoded, width: 800);
        uploadBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
        await ref.putData(
          uploadBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      } else {
        // no crop and not web: read file and compress
        if (path == null) return;
        final fileBytes = await File(path).readAsBytes();
        if (!mounted) return;
        final decoded = img.decodeImage(fileBytes)!;
        final resized = img.copyResize(decoded, width: 800);
        uploadBytes = Uint8List.fromList(img.encodeJpg(resized, quality: 85));
        await ref.putData(
          uploadBytes,
          SettableMetadata(contentType: 'image/jpeg'),
        );
      }

      final url = await ref.getDownloadURL();
      // update firebase auth profile and firestore
      await widget.user.updateProfile(
        displayName: widget.user.displayName,
        photoURL: url,
      );
      await widget.apis.firestore.collection('users').doc(uid).set({
        'photoURL': url,
      }, merge: true);
      await widget.user.reload();
      // update app-wide user cubit so other widgets (ProfileMenu) update immediately
      try {
        final refreshed = widget.apis.auth.currentUser;
        if (refreshed != null) {
          try {
            if (!mounted) return;
            final userCubit = context.read<UserCubit?>();
            if (userCubit != null) userCubit.setUser(refreshed);
          } catch (_) {
            // no cubit provided; ignore
          }
        }
      } catch (_) {}
      if (!mounted) return;
      setState(() {});
    } catch (e) {
      if (mounted && messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) navigator.pop();
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _saveProfile() async {
    final name = _nameCtrl.text.trim();
    // widget.user is non-nullable
    // Show modal progress
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() => _saving = true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      await widget.user.updateProfile(
        displayName: name,
        photoURL: widget.user.photoURL,
      );
      await widget.apis.firestore.collection('users').doc(widget.user.uid).set({
        'displayName': name,
        if (_selectedColor != null) 'personalColor': _selectedColor!.value,
      }, merge: true);
      await widget.user.reload();
    } catch (e) {
      if (messenger != null) {
        messenger.showSnackBar(
          SnackBar(content: Text('Failed to save profile: $e')),
        );
      }
    } finally {
      if (mounted) navigator.pop();
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.apis.auth.currentUser ?? widget.user;
    final color = _selectedColor;
    final onColor = color != null
        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
              ? Colors.white
              : Colors.black)
        : Theme.of(context).colorScheme.onSurface;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: color,
        foregroundColor: onColor,
        elevation: 0,
      ),
      body: Container(
        decoration: color != null
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.10), color.withOpacity(0.03)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              )
            : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (user.photoURL != null)
                CircleAvatar(
                  radius: 48,
                  backgroundImage: NetworkImage(user.photoURL!),
                  backgroundColor: color?.withOpacity(0.7),
                )
              else
                CircleAvatar(
                  radius: 48,
                  backgroundColor: color?.withOpacity(0.7) ?? Colors.grey[300],
                  child: const Icon(Icons.person, size: 48),
                ),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: onColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saving ? null : _pickAndUploadPhoto,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Change photo'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'Display name',
                  labelStyle: TextStyle(color: color),
                  filled: color != null,
                  fillColor: color?.withOpacity(0.08),
                  enabledBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: color ?? Colors.grey),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(
                      color: color ?? Colors.blue,
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Personal color:',
                    style: TextStyle(color: color, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _saving ? null : _pickColor,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: color ?? Colors.grey[300],
                      child: color == null
                          ? const Icon(
                              Icons.color_lens,
                              color: Colors.black54,
                              size: 18,
                            )
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                user.email ?? 'No email',
                style: TextStyle(color: color, fontWeight: FontWeight.w500),
              ),
              // Debug: Show current user UID only in debug mode
              if (kDebugMode)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: SelectableText(
                    'UID: ${user.uid}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: onColor,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _saving ? null : _saveProfile,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickColor() async {
    final colors = [
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.grey,
      Colors.blueGrey,
      Colors.black,
    ];
    final selected = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select your personal color'),
        content: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: colors
              .map(
                (color) => GestureDetector(
                  onTap: () => Navigator.of(context).pop(color),
                  child: CircleAvatar(
                    backgroundColor: color,
                    radius: 18,
                    child: _selectedColor == color
                        ? const Icon(Icons.check, color: Colors.white)
                        : null,
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (selected != null) {
      setState(() => _selectedColor = selected);
    }
  }
}
