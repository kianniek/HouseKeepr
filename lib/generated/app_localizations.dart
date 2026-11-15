import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('nl'),
  ];

  /// The app name
  ///
  /// In en, this message translates to:
  /// **'HouseKeepr'**
  String get appName;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Preferences section header in settings
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesSection;

  /// Notifications section header in settings
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsSection;

  /// Home screen widgets settings tile title
  ///
  /// In en, this message translates to:
  /// **'Home Screen Widgets'**
  String get homeScreenWidgetsTitle;

  /// Home screen widgets settings tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Customize Pill Reminder, Shopping List & Coffee widgets'**
  String get homeScreenWidgetsSubtitle;

  /// Language setting label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// English language label
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Dutch language label
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get languageDutch;

  /// Floating nav toggle label
  ///
  /// In en, this message translates to:
  /// **'Floating pill navigation'**
  String get floatingNavTitle;

  /// Floating nav toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Use a floating navigation bar style'**
  String get floatingNavSubtitle;

  /// Daily notifications toggle label
  ///
  /// In en, this message translates to:
  /// **'Daily notifications'**
  String get dailyNotificationsTitle;

  /// Daily notifications toggle subtitle
  ///
  /// In en, this message translates to:
  /// **'Receive a summary at start and end of day'**
  String get dailyNotificationsSubtitle;

  /// Start of day time picker label
  ///
  /// In en, this message translates to:
  /// **'Start of day time'**
  String get startOfDayTime;

  /// End of day time picker label
  ///
  /// In en, this message translates to:
  /// **'End of day time'**
  String get endOfDayTime;

  /// Profile list tile label
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// Profile list tile subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage your account and data'**
  String get profileSubtitle;

  /// Account section header in settings
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountSection;

  /// View account title
  ///
  /// In en, this message translates to:
  /// **'View Account'**
  String get viewAccount;

  /// View account subtitle
  ///
  /// In en, this message translates to:
  /// **'View and edit profile details'**
  String get viewAccountSubtitle;

  /// Logout button title
  ///
  /// In en, this message translates to:
  /// **'Log Out'**
  String get logout;

  /// Logout confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out?'**
  String get logoutConfirmation;

  /// Error message shown when logout fails
  ///
  /// In en, this message translates to:
  /// **'Failed to logout: {error}'**
  String failedToLogout(String error);

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Diagnostics section label
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get diagnostics;

  /// Test notification label
  ///
  /// In en, this message translates to:
  /// **'Test notification'**
  String get testNotification;

  /// Test notification subtitle
  ///
  /// In en, this message translates to:
  /// **'Send a test notification now'**
  String get testNotificationSubtitle;

  /// Shopping list page title
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get shoppingList;

  /// Empty shopping list message
  ///
  /// In en, this message translates to:
  /// **'No items yet. Start adding!'**
  String get noItemsYet;

  /// Aisle mode toggle label
  ///
  /// In en, this message translates to:
  /// **'Aisle Mode'**
  String get aisleMode;

  /// Aisle mode on label
  ///
  /// In en, this message translates to:
  /// **'Aisle Mode: On'**
  String get aisleModeOn;

  /// Aisle mode off label
  ///
  /// In en, this message translates to:
  /// **'Aisle Mode: Off'**
  String get aisleModeOff;

  /// Flat view on label
  ///
  /// In en, this message translates to:
  /// **'Flat View: On'**
  String get flatViewOn;

  /// Flat view off label
  ///
  /// In en, this message translates to:
  /// **'Flat View: Off'**
  String get flatViewOff;

  /// Clear checked items menu item
  ///
  /// In en, this message translates to:
  /// **'Clear Checked Items'**
  String get clearCheckedItems;

  /// Force reload menu item
  ///
  /// In en, this message translates to:
  /// **'Force Reload'**
  String get forceReload;

  /// Success message after force reload
  ///
  /// In en, this message translates to:
  /// **'Shopping list reloaded from server'**
  String get shoppingListReloaded;

  /// Error message after failed force reload
  ///
  /// In en, this message translates to:
  /// **'Failed to reload: {error}'**
  String failedToReload(String error);

  /// Shopping list item input hint
  ///
  /// In en, this message translates to:
  /// **'Add item...'**
  String get addItem;

  /// Bulk add tooltip
  ///
  /// In en, this message translates to:
  /// **'Bulk Add'**
  String get bulkAdd;

  /// Dashboard tab label
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// Tasks tab label
  ///
  /// In en, this message translates to:
  /// **'Tasks'**
  String get tasks;

  /// Shopping tab label
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get shopping;

  /// Tools tab label
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get tools;

  /// Medication reminders tool title
  ///
  /// In en, this message translates to:
  /// **'Medication Reminders'**
  String get medicationReminders;

  /// Widget header title in English
  ///
  /// In en, this message translates to:
  /// **'Pills'**
  String get pillWidgetTitle;

  /// Morning/daytime dose section
  ///
  /// In en, this message translates to:
  /// **'Daytime'**
  String get daytimeDoses;

  /// Evening/night dose section
  ///
  /// In en, this message translates to:
  /// **'Evening'**
  String get eveningDoses;

  /// Recently deleted page and menu title
  ///
  /// In en, this message translates to:
  /// **'Recently Deleted'**
  String get recentlyDeleted;

  /// Completed items section header
  ///
  /// In en, this message translates to:
  /// **'Completed ({count})'**
  String completedCount(int count);

  /// Suffix showing active category in quick add
  ///
  /// In en, this message translates to:
  /// **'in {category}'**
  String inCategory(String category);

  /// Undo toast message when unnamed item deleted
  ///
  /// In en, this message translates to:
  /// **'Item deleted'**
  String get itemDeleted;

  /// Undo toast message when named item deleted
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" deleted'**
  String namedItemDeleted(String name);

  /// Undo toast when 1 checked item cleared
  ///
  /// In en, this message translates to:
  /// **'1 item cleared'**
  String get oneItemCleared;

  /// Undo toast when multiple checked items cleared
  ///
  /// In en, this message translates to:
  /// **'{count} items cleared'**
  String itemsCleared(int count);

  /// Empty shopping list sub-message
  ///
  /// In en, this message translates to:
  /// **'Type an item above or use Bulk Add to get started.'**
  String get noItemsSubMessage;

  /// Title for add product dialog
  ///
  /// In en, this message translates to:
  /// **'Add Product to Database'**
  String get addProductToDatabase;

  /// Helper text in add product dialog
  ///
  /// In en, this message translates to:
  /// **'Choose a section and enter product names.'**
  String get chooseSectionAndEnterProduct;

  /// English product name field label
  ///
  /// In en, this message translates to:
  /// **'Product Name (EN)'**
  String get productNameEn;

  /// English product name hint
  ///
  /// In en, this message translates to:
  /// **'e.g., Apple'**
  String get productNameEnHint;

  /// Dutch product name field label
  ///
  /// In en, this message translates to:
  /// **'Product Name (NL) - Optional'**
  String get productNameNlOptional;

  /// Dutch product name hint
  ///
  /// In en, this message translates to:
  /// **'e.g., Appel'**
  String get productNameNlHint;

  /// Validation message in add product dialog
  ///
  /// In en, this message translates to:
  /// **'Please fill in all required fields'**
  String get pleaseFillRequiredFields;

  /// Confirmation snackbar when product added
  ///
  /// In en, this message translates to:
  /// **'Product added!'**
  String get productAdded;

  /// Generic Add button label
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// Restore all recently deleted items
  ///
  /// In en, this message translates to:
  /// **'Restore all'**
  String get restoreAll;

  /// Empty recently deleted list action
  ///
  /// In en, this message translates to:
  /// **'Empty'**
  String get empty;

  /// Confirmation dialog title for emptying trash
  ///
  /// In en, this message translates to:
  /// **'Empty Recently Deleted?'**
  String get emptyRecentlyDeletedTitle;

  /// Confirmation text for 1 item
  ///
  /// In en, this message translates to:
  /// **'1 item will be permanently deleted. This cannot be undone.'**
  String get emptyRecentlyDeletedSingle;

  /// Confirmation text for multiple items
  ///
  /// In en, this message translates to:
  /// **'{count} items will be permanently deleted. This cannot be undone.'**
  String emptyRecentlyDeletedMultiple(int count);

  /// Permanent delete button/label
  ///
  /// In en, this message translates to:
  /// **'Delete forever'**
  String get deleteForever;

  /// Confirmation dialog title for single permanent delete
  ///
  /// In en, this message translates to:
  /// **'Delete item forever?'**
  String get deleteItemForeverTitle;

  /// Confirmation dialog body for single permanent delete
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" will be permanently deleted. This cannot be undone.'**
  String deleteItemForeverMessage(String name);

  /// Retention banner in recently deleted page
  ///
  /// In en, this message translates to:
  /// **'Items are permanently deleted after 7 days.'**
  String get recentlyDeletedRetentionBanner;

  /// Empty state title in recently deleted page
  ///
  /// In en, this message translates to:
  /// **'No recently deleted items'**
  String get noRecentlyDeletedItems;

  /// Empty state subtitle in recently deleted page
  ///
  /// In en, this message translates to:
  /// **'Items you delete from your shopping list show up here for 7 days.'**
  String get noRecentlyDeletedSubMessage;

  /// Undo toast when unnamed item restored
  ///
  /// In en, this message translates to:
  /// **'Item restored'**
  String get itemRestored;

  /// Undo toast when named item restored
  ///
  /// In en, this message translates to:
  /// **'\"{name}\" restored to your list'**
  String namedItemRestored(String name);

  /// Undo toast when 1 item restored
  ///
  /// In en, this message translates to:
  /// **'1 item restored'**
  String get oneItemRestored;

  /// Undo toast when multiple items restored
  ///
  /// In en, this message translates to:
  /// **'{count} items restored'**
  String itemsRestored(int count);

  /// Restore button tooltip
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// Fallback label for unnamed item
  ///
  /// In en, this message translates to:
  /// **'(unnamed)'**
  String get unnamedItem;

  /// Relative deletion timestamp
  ///
  /// In en, this message translates to:
  /// **'Deleted {time}'**
  String deletedTimeAgo(String time);

  /// Relative time: just now
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// Relative time: minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(int count);

  /// Relative time: hours ago
  ///
  /// In en, this message translates to:
  /// **'{count} h ago'**
  String hoursAgo(int count);

  /// Relative time: 1 day ago
  ///
  /// In en, this message translates to:
  /// **'1 day ago'**
  String get oneDayAgo;

  /// Relative time: days ago
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// Retention countdown: 1 day left
  ///
  /// In en, this message translates to:
  /// **'1 day left'**
  String get oneDayLeft;

  /// Retention countdown: days left
  ///
  /// In en, this message translates to:
  /// **'{count} days left'**
  String daysLeft(int count);

  /// Retention countdown: hours left
  ///
  /// In en, this message translates to:
  /// **'{count} h left'**
  String hoursLeft(int count);

  /// Retention countdown: less than an hour left
  ///
  /// In en, this message translates to:
  /// **'less than an hour left'**
  String get lessThanHourLeft;

  /// Quantity picker dialog title
  ///
  /// In en, this message translates to:
  /// **'Set Quantity & Unit'**
  String get setQuantityAndUnit;

  /// Unit dropdown label
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get unit;

  /// No unit selected option
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get none;

  /// OK button label
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// Category picker dialog title
  ///
  /// In en, this message translates to:
  /// **'Change category'**
  String get changeCategory;

  /// Bulk import dialog title
  ///
  /// In en, this message translates to:
  /// **'Bulk Import Groceries'**
  String get bulkImportGroceries;

  /// Bulk import text field hint
  ///
  /// In en, this message translates to:
  /// **'e.g.\n2 cartons milk\n1.5 kg apples\n2 cloves garlic\n500g minced meat'**
  String get bulkImportHint;

  /// Next button label
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Bulk import confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Review Items'**
  String get reviewItems;

  /// Add all items button label
  ///
  /// In en, this message translates to:
  /// **'Add All'**
  String get addAll;

  /// Edit shopping item dialog title
  ///
  /// In en, this message translates to:
  /// **'Edit Item'**
  String get editItem;

  /// Item name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get itemName;

  /// Validation error when item name is empty
  ///
  /// In en, this message translates to:
  /// **'Please enter an item name'**
  String get itemNameRequired;

  /// Optional note field label
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// Hint for item note field
  ///
  /// In en, this message translates to:
  /// **'e.g., organic, brand, etc.'**
  String get noteHint;

  /// Category field label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// Quantity field label
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// Save button label
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Uncheck all completed items action
  ///
  /// In en, this message translates to:
  /// **'Uncheck all'**
  String get uncheckAll;

  /// Undo toast when 1 completed item is unchecked
  ///
  /// In en, this message translates to:
  /// **'1 item unchecked'**
  String get oneItemUnchecked;

  /// Undo toast when multiple completed items are unchecked
  ///
  /// In en, this message translates to:
  /// **'{count} items unchecked'**
  String itemsUnchecked(int count);

  /// Share shopping list menu item
  ///
  /// In en, this message translates to:
  /// **'Share List'**
  String get shareList;

  /// Button or dialog title to import a recipe from a URL
  ///
  /// In en, this message translates to:
  /// **'Import Recipe'**
  String get importRecipe;

  /// Hint text for recipe URL input
  ///
  /// In en, this message translates to:
  /// **'Paste a recipe link (e.g. ah.nl, jumbo.com, ...)'**
  String get recipeUrlHint;

  /// Button label to fetch and parse recipe URL
  ///
  /// In en, this message translates to:
  /// **'Fetch Recipe'**
  String get fetchRecipe;

  /// Loading label while fetching recipe webpage
  ///
  /// In en, this message translates to:
  /// **'Fetching recipe...'**
  String get fetchingRecipe;

  /// Label for recipe title field
  ///
  /// In en, this message translates to:
  /// **'Recipe name'**
  String get recipeTitleLabel;

  /// Servings count label
  ///
  /// In en, this message translates to:
  /// **'{count} servings'**
  String servingsCount(int count);

  /// Confirm button to add recipe and ingredients to shopping list
  ///
  /// In en, this message translates to:
  /// **'Add Recipe'**
  String get addRecipe;

  /// Section header for recipe parent containers
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get recipesSectionTitle;

  /// Tooltip for button to open original recipe URL
  ///
  /// In en, this message translates to:
  /// **'Open recipe'**
  String get openRecipeLink;

  /// Checked out of total ingredients counter
  ///
  /// In en, this message translates to:
  /// **'{checked}/{total}'**
  String recipeIngredientsProgress(int checked, int total);

  /// Undo toast message when a recipe container is deleted
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String recipeDeleted(String name);

  /// Error message when recipe import fails
  ///
  /// In en, this message translates to:
  /// **'Could not import recipe: {error}'**
  String recipeImportFailed(String error);

  /// Select all ingredients toggle
  ///
  /// In en, this message translates to:
  /// **'Select all'**
  String get selectAllIngredients;

  /// Fallback button when recipe URL returns 403 or fails
  ///
  /// In en, this message translates to:
  /// **'Paste ingredients manually'**
  String get pasteIngredientsManually;

  /// Hint for manual ingredient paste field
  ///
  /// In en, this message translates to:
  /// **'Paste the recipe\'s ingredients here, one per line'**
  String get pasteIngredientsHint;

  /// Button to parse manually pasted ingredients
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get parseIngredients;

  /// Button in WebView extractor to parse the loaded recipe page
  ///
  /// In en, this message translates to:
  /// **'Extract Recipe'**
  String get extractRecipe;

  /// Button to open recipe URL in in-app WebView
  ///
  /// In en, this message translates to:
  /// **'Open in browser view'**
  String get openInWebView;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
