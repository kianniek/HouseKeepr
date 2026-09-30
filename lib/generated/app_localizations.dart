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
