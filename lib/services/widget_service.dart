import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:home_widget/home_widget.dart';
import '../models/grocery_item.dart';

/// Service that bridges Flutter's ShoppingCubit state to the Android home-screen
/// widget via [home_widget].
///
/// Call [updateWidget] whenever the grocery list changes.
/// Call [processPendingToggles] on app resume to reconcile any toggles
/// the user made from the widget while the app was backgrounded.
class WidgetService {
  WidgetService._();
  static final WidgetService instance = WidgetService._();

  static bool get _isAndroid =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static bool get _isIOS =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  /// Debounce timer (300 ms) to avoid rapid sequential writes.
  Timer? _debounceTimer;
  static const _debounceDuration = Duration(milliseconds: 300);

  /// The Android widget provider class name (fully qualified).
  static const _androidWidgetName = 'ShoppingListWidget';

  /// Key used in SharedPreferences / HomeWidget data store.
  static const _dataKey = 'shopping_list_data';
  static const _pendingTogglesKey = 'pending_toggles';

  /// Initialize home_widget configuration.
  Future<void> init() async {
    // `home_widget` is not implemented on web/desktop; avoid calling it there.
    // App Group ID is only relevant on iOS.
    if (!_isIOS) return;
    try {
      await HomeWidget.setAppGroupId('group.com.kianhamidi.housekeepr');
    } catch (e) {
      debugPrint('WidgetService: failed to init home_widget: $e');
    }
  }

  /// Push the current grocery items to the widget data store with a 300 ms
  /// debounce. Subsequent calls within the window replace the pending write.
  void updateWidget(List<GroceryItem> items) {
    if (!_isAndroid) return;
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDuration, () async {
      await _writeAndRefresh(items);
    });
  }

  /// Immediately push items and refresh the widget (skips debounce).
  Future<void> updateWidgetImmediate(List<GroceryItem> items) async {
    if (!_isAndroid) return;
    _debounceTimer?.cancel();
    await _writeAndRefresh(items);
  }

  Future<void> _writeAndRefresh(List<GroceryItem> items) async {
    if (!_isAndroid) return;
    try {
      // Serialize the items to a JSON array of lightweight maps.
      final widgetData = items
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'quantity': item.quantity,
              'checked': item.checked,
              'createdAt': item.createdAt.toIso8601String(),
              'checkedAt': item.checkedAt?.toIso8601String(),
            },
          )
          .toList();

      final jsonString = json.encode(widgetData);
      await HomeWidget.saveWidgetData<String>(_dataKey, jsonString);

      // Tell Android to refresh the widget.
      await HomeWidget.updateWidget(androidName: _androidWidgetName);
    } catch (e) {
      debugPrint('WidgetService: failed to update widget: $e');
    }
  }

  /// Read any pending toggle actions that the widget performed while the app
  /// was in the background, and return their item IDs.
  ///
  /// After reading, the pending list is cleared.
  Future<List<String>> processPendingToggles() async {
    if (!_isAndroid) return [];
    try {
      final data = await HomeWidget.getWidgetData<String>(_pendingTogglesKey);
      if (data == null || data.isEmpty) return [];

      // Clear the pending toggles.
      await HomeWidget.saveWidgetData<String>(_pendingTogglesKey, '');

      // Split comma-separated IDs.
      return data.split(',').where((id) => id.isNotEmpty).toList();
    } catch (e) {
      debugPrint('WidgetService: failed to process pending toggles: $e');
      return [];
    }
  }

  /// Cancel any pending debounce timer (e.g. on dispose).
  void dispose() {
    _debounceTimer?.cancel();
    _debounceTimer = null;
  }
}
