import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A Bento card container that remembers its non-loading height (in memory and
/// [SharedPreferences]) so subsequent loading states maintain the previous
/// height and smoothly animate any size change once loading completes.
class StableLoadingCard extends StatefulWidget {
  final String storageKey;
  final bool isLoading;
  final double minHeight;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;
  final Widget child;

  const StableLoadingCard({
    super.key,
    required this.storageKey,
    required this.isLoading,
    required this.child,
    this.minHeight = 180,
    this.padding = const EdgeInsets.all(18),
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.onTap,
  });

  /// Clears the in-memory height cache (intended for tests).
  @visibleForTesting
  static void clearMemoryCache() => _StableLoadingCardState._memoryCache.clear();

  @override
  State<StableLoadingCard> createState() => _StableLoadingCardState();
}

class _StableLoadingCardState extends State<StableLoadingCard> {
  static final Map<String, double> _memoryCache = <String, double>{};

  final GlobalKey _containerKey = GlobalKey();
  double? _storedHeight;

  @override
  void initState() {
    super.initState();
    _storedHeight = _memoryCache[widget.storageKey];
    _loadPersistedHeight();
    _scheduleHeightCapture();
  }

  @override
  void didUpdateWidget(covariant StableLoadingCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.storageKey != widget.storageKey) {
      _storedHeight = _memoryCache[widget.storageKey];
      _loadPersistedHeight();
    }
    if (!oldWidget.isLoading && widget.isLoading) {
      _captureHeightNow();
    }
    if (!widget.isLoading) {
      _scheduleHeightCapture();
    }
  }

  Future<void> _loadPersistedHeight() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getDouble(widget.storageKey);
      if (!mounted || saved == null || saved < widget.minHeight) return;
      if (_storedHeight == null) {
        _memoryCache[widget.storageKey] = saved;
        setState(() {
          _storedHeight = saved;
        });
      }
    } catch (_) {
      // Ignore SharedPreferences errors in constrained environments.
    }
  }

  void _captureHeightNow() {
    final renderBox =
        _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    _recordHeight(renderBox.size.height);
  }

  void _scheduleHeightCapture() {
    if (widget.isLoading) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.isLoading) return;
      _captureHeightNow();
    });
  }

  void _recordHeight(double height) {
    if (height < widget.minHeight) return;
    final previous = _storedHeight;
    if (previous != null && (previous - height).abs() < 0.5) return;

    _memoryCache[widget.storageKey] = height;
    _storedHeight = height;
    _persistHeight(height);
  }

  Future<void> _persistHeight(double height) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(widget.storageKey, height);
    } catch (_) {
      // Ignore SharedPreferences errors in constrained environments.
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final effectiveMinHeight = widget.isLoading
        ? math.max(widget.minHeight, _storedHeight ?? widget.minHeight)
        : widget.minHeight;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: widget.borderRadius,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: Container(
            key: _containerKey,
            constraints: BoxConstraints(minHeight: effectiveMinHeight),
            padding: widget.padding,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: widget.borderRadius,
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
