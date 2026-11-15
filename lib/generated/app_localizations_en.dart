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
  String get accountSection => 'Account';

  @override
  String get viewAccount => 'View Account';

  @override
  String get viewAccountSubtitle => 'View and edit profile details';

  @override
  String get logout => 'Log Out';

  @override
  String get logoutConfirmation => 'Are you sure you want to log out?';

  @override
  String get cancel => 'Cancel';

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

  @override
  String get medicationReminders => 'Medication Reminders';

  @override
  String get pillWidgetTitle => 'Pills';

  @override
  String get daytimeDoses => 'Daytime';

  @override
  String get eveningDoses => 'Evening';

  @override
  String get recentlyDeleted => 'Recently Deleted';

  @override
  String completedCount(int count) {
    return 'Completed ($count)';
  }

  @override
  String inCategory(String category) {
    return 'in $category';
  }

  @override
  String get itemDeleted => 'Item deleted';

  @override
  String namedItemDeleted(String name) {
    return '\"$name\" deleted';
  }

  @override
  String get oneItemCleared => '1 item cleared';

  @override
  String itemsCleared(int count) {
    return '$count items cleared';
  }

  @override
  String get noItemsSubMessage =>
      'Type an item above or use Bulk Add to get started.';

  @override
  String get addProductToDatabase => 'Add Product to Database';

  @override
  String get chooseSectionAndEnterProduct =>
      'Choose a section and enter product names.';

  @override
  String get productNameEn => 'Product Name (EN)';

  @override
  String get productNameEnHint => 'e.g., Apple';

  @override
  String get productNameNlOptional => 'Product Name (NL) - Optional';

  @override
  String get productNameNlHint => 'e.g., Appel';

  @override
  String get pleaseFillRequiredFields => 'Please fill in all required fields';

  @override
  String get productAdded => 'Product added!';

  @override
  String get add => 'Add';

  @override
  String get restoreAll => 'Restore all';

  @override
  String get empty => 'Empty';

  @override
  String get emptyRecentlyDeletedTitle => 'Empty Recently Deleted?';

  @override
  String get emptyRecentlyDeletedSingle =>
      '1 item will be permanently deleted. This cannot be undone.';

  @override
  String emptyRecentlyDeletedMultiple(int count) {
    return '$count items will be permanently deleted. This cannot be undone.';
  }

  @override
  String get deleteForever => 'Delete forever';

  @override
  String get deleteItemForeverTitle => 'Delete item forever?';

  @override
  String deleteItemForeverMessage(String name) {
    return '\"$name\" will be permanently deleted. This cannot be undone.';
  }

  @override
  String get recentlyDeletedRetentionBanner =>
      'Items are permanently deleted after 7 days.';

  @override
  String get noRecentlyDeletedItems => 'No recently deleted items';

  @override
  String get noRecentlyDeletedSubMessage =>
      'Items you delete from your shopping list show up here for 7 days.';

  @override
  String get itemRestored => 'Item restored';

  @override
  String namedItemRestored(String name) {
    return '\"$name\" restored to your list';
  }

  @override
  String get oneItemRestored => '1 item restored';

  @override
  String itemsRestored(int count) {
    return '$count items restored';
  }

  @override
  String get restore => 'Restore';

  @override
  String get unnamedItem => '(unnamed)';

  @override
  String deletedTimeAgo(String time) {
    return 'Deleted $time';
  }

  @override
  String get justNow => 'just now';

  @override
  String minutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String hoursAgo(int count) {
    return '$count h ago';
  }

  @override
  String get oneDayAgo => '1 day ago';

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }

  @override
  String get oneDayLeft => '1 day left';

  @override
  String daysLeft(int count) {
    return '$count days left';
  }

  @override
  String hoursLeft(int count) {
    return '$count h left';
  }

  @override
  String get lessThanHourLeft => 'less than an hour left';

  @override
  String get setQuantityAndUnit => 'Set Quantity & Unit';

  @override
  String get unit => 'Unit';

  @override
  String get none => 'None';

  @override
  String get ok => 'OK';

  @override
  String get changeCategory => 'Change category';

  @override
  String get bulkImportGroceries => 'Bulk Import Groceries';

  @override
  String get bulkImportHint =>
      'e.g.\n2 cartons milk\n1.5 kg apples\n2 cloves garlic\n500g minced meat';

  @override
  String get next => 'Next';

  @override
  String get reviewItems => 'Review Items';

  @override
  String get addAll => 'Add All';

  @override
  String get editItem => 'Edit Item';

  @override
  String get itemName => 'Name';

  @override
  String get itemNameRequired => 'Please enter an item name';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get noteHint => 'e.g., organic, brand, etc.';

  @override
  String get category => 'Category';

  @override
  String get quantity => 'Quantity';

  @override
  String get save => 'Save';

  @override
  String get uncheckAll => 'Uncheck all';

  @override
  String get oneItemUnchecked => '1 item unchecked';

  @override
  String itemsUnchecked(int count) {
    return '$count items unchecked';
  }

  @override
  String get shareList => 'Share List';
}
