// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appName => 'HouseKeepr';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get language => 'Taal';

  @override
  String get languageEnglish => 'Engels';

  @override
  String get languageDutch => 'Nederlands';

  @override
  String get floatingNavTitle => 'Zwevende navigatiebalk';

  @override
  String get floatingNavSubtitle => 'Gebruik een zwevende navigatiebalkstijl';

  @override
  String get dailyNotificationsTitle => 'Dagelijkse meldingen';

  @override
  String get dailyNotificationsSubtitle =>
      'Ontvang een samenvatting aan het begin en einde van de dag';

  @override
  String get startOfDayTime => 'Begin van de dag';

  @override
  String get endOfDayTime => 'Einde van de dag';

  @override
  String get profile => 'Profiel';

  @override
  String get profileSubtitle => 'Beheer je account en gegevens';

  @override
  String get diagnostics => 'Diagnostiek';

  @override
  String get testNotification => 'Testmelding';

  @override
  String get testNotificationSubtitle => 'Stuur nu een testmelding';

  @override
  String get shoppingList => 'Boodschappenlijst';

  @override
  String get noItemsYet => 'Nog geen items. Begin met toevoegen!';

  @override
  String get aisleMode => 'Gangenmodus';

  @override
  String get aisleModeOn => 'Gangenmodus: Aan';

  @override
  String get aisleModeOff => 'Gangenmodus: Uit';

  @override
  String get flatViewOn => 'Vlakke weergave: Aan';

  @override
  String get flatViewOff => 'Vlakke weergave: Uit';

  @override
  String get clearCheckedItems => 'Aangevinkte items wissen';

  @override
  String get forceReload => 'Forceer herladen';

  @override
  String get shoppingListReloaded => 'Boodschappenlijst herladen van server';

  @override
  String failedToReload(String error) {
    return 'Herladen mislukt: $error';
  }

  @override
  String get addItem => 'Item toevoegen...';

  @override
  String get bulkAdd => 'Bulk toevoegen';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get tasks => 'Taken';

  @override
  String get shopping => 'Boodschappen';

  @override
  String get tools => 'Gereedschap';
}
