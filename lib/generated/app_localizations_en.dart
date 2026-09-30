// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'HouseKeepr';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageDutch => 'Dutch';

  @override
  String get floatingNavTitle => 'Floating pill navigation';

  @override
  String get floatingNavSubtitle => 'Use a floating navigation bar style';

  @override
  String get dailyNotificationsTitle => 'Daily notifications';

  @override
  String get dailyNotificationsSubtitle =>
      'Receive a summary at start and end of day';

  @override
  String get startOfDayTime => 'Start of day time';

  @override
  String get endOfDayTime => 'End of day time';

  @override
  String get profile => 'Profile';

  @override
  String get profileSubtitle => 'Manage your account and data';

  @override
  String get diagnostics => 'Diagnostics';

  @override
  String get testNotification => 'Test notification';

  @override
  String get testNotificationSubtitle => 'Send a test notification now';

  @override
  String get shoppingList => 'Shopping List';

  @override
  String get noItemsYet => 'No items yet. Start adding!';

  @override
  String get aisleMode => 'Aisle Mode';

  @override
  String get aisleModeOn => 'Aisle Mode: On';

  @override
  String get aisleModeOff => 'Aisle Mode: Off';

  @override
  String get flatViewOn => 'Flat View: On';

  @override
  String get flatViewOff => 'Flat View: Off';

  @override
  String get clearCheckedItems => 'Clear Checked Items';

  @override
  String get forceReload => 'Force Reload';

  @override
  String get shoppingListReloaded => 'Shopping list reloaded from server';

  @override
  String failedToReload(String error) {
    return 'Failed to reload: $error';
  }

  @override
  String get addItem => 'Add item...';

  @override
  String get bulkAdd => 'Bulk Add';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get tasks => 'Tasks';

  @override
  String get shopping => 'Shopping';

  @override
  String get tools => 'Tools';
}
