import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Small helper that resolves a user's avatar URL from Firestore and shows
/// either the network image or initials fallback.
class AssigneeAvatar extends StatefulWidget {
  final String? userId;
  final String? displayName;

  /// Optional override for the photo URL. Useful for tests or when the
  /// caller already knows the URL and wants to avoid a Firestore lookup.
  final String? photoUrl;
  final double radius;

  const AssigneeAvatar({
    super.key,
    this.userId,
    this.displayName,
    this.photoUrl,
    this.radius = 16,
  });

  @override
  State<AssigneeAvatar> createState() => _AssigneeAvatarState();
}

class _AssigneeAvatarState extends State<AssigneeAvatar> {
  static final Map<String, Map<String, dynamic>> _cache = {};
  String? _photoUrl;
  Color? _personalColor;
  String? _displayName;
  bool _loadFailed = false;

  @override
  void initState() {
    super.initState();
    _displayName = widget.displayName;
    // Allow callers/tests to provide the photo URL directly. This helps tests
    // avoid depending on Firestore and keeps the existing behavior when
    // photoUrl is not provided.
    if (widget.photoUrl != null) {
      _photoUrl = widget.photoUrl;
    }
    if (widget.userId != null && _cache.containsKey(widget.userId)) {
      final data = _cache[widget.userId]!;
      _photoUrl = data['photoURL'] as String?;
      _personalColor = data['personalColor'] as Color?;
      _displayName = data['displayName'] as String? ?? _displayName;
      _loadFailed = data['loadFailed'] as bool? ?? false;
    }
    if (widget.userId != null && !_cache.containsKey(widget.userId)) {
      FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userId)
          .get()
          .then((doc) {
            final data = doc.data();
            if (data != null) {
              final url = (data['photoURL'] is String)
                  ? data['photoURL'] as String
                  : null;
              final name = (data['displayName'] is String)
                  ? data['displayName'] as String
                  : null;
              Color? col;
              if (data['personalColor'] is int) {
                try {
                  col = Color(data['personalColor'] as int);
                } catch (_) {}
              }
              _cache[widget.userId!] = {
                'photoURL': url,
                'displayName': name,
                'personalColor': col,
                'loadFailed': false,
              };
              if (mounted) {
                setState(() {
                  _photoUrl = url;
                  _personalColor = col;
                  _loadFailed = false;
                  if (name != null) _displayName = name;
                });
              }
            }
          })
          .catchError((_) {});
    }
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    // Validate URL and skip if it previously failed to load.
    final url = _photoUrl?.trim();
    final validUrl =
        url != null &&
        url.isNotEmpty &&
        (Uri.tryParse(url)?.hasAbsolutePath ?? false) &&
        (Uri.tryParse(url)?.scheme == 'https' ||
            Uri.tryParse(url)?.scheme == 'http');

    if (validUrl && !_loadFailed) {
      // Use Image.network with an errorBuilder to detect failures and
      // fall back to initials. We wrap the image in a ClipOval sized to
      // the circle avatar radius so we can control the fallback.
      final size = widget.radius * 2;
      return SizedBox(
        width: size,
        height: size,
        child: ClipOval(
          child: Image.network(
            url,
            fit: BoxFit.cover,
            width: size,
            height: size,
            // While loading, show a placeholder background color.
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return Container(color: _personalColor ?? Colors.grey.shade300);
            },
            errorBuilder: (context, error, stackTrace) {
              // Mark this URL as failed so we don't keep retrying.
              if (widget.userId != null) {
                _cache[widget.userId!] = {
                  'photoURL': _photoUrl,
                  'displayName': _displayName,
                  'personalColor': _personalColor,
                  'loadFailed': true,
                };
              }
              if (mounted) setState(() => _loadFailed = true);
              // Return initials fallback
              final initials = _initials(_displayName ?? widget.displayName);
              return Container(
                color: _personalColor ?? Colors.grey.shade300,
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: widget.radius * 0.9,
                    color: Colors.black87,
                  ),
                ),
              );
            },
          ),
        ),
      );
    }
    final initials = _initials(_displayName ?? widget.displayName);
    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: _personalColor ?? Colors.grey.shade300,
      child: Text(
        initials,
        style: TextStyle(fontSize: widget.radius * 0.9, color: Colors.black87),
      ),
    );
  }
}
