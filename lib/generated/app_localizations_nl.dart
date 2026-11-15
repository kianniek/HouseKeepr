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
  String get accountSection => 'Account';

  @override
  String get viewAccount => 'Account bekijken';

  @override
  String get viewAccountSubtitle => 'Profielgegevens bekijken en bewerken';

  @override
  String get logout => 'Uitloggen';

  @override
  String get logoutConfirmation => 'Weet je zeker dat je wilt uitloggen?';

  @override
  String get cancel => 'Annuleren';

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

  @override
  String get medicationReminders => 'Medicatie herinneringen';

  @override
  String get pillWidgetTitle => 'Pillen';

  @override
  String get daytimeDoses => 'Overdag';

  @override
  String get eveningDoses => 'Avond';

  @override
  String get recentlyDeleted => 'Onlangs verwijderd';

  @override
  String completedCount(int count) {
    return 'Voltooid ($count)';
  }

  @override
  String inCategory(String category) {
    return 'in $category';
  }

  @override
  String get itemDeleted => 'Item verwijderd';

  @override
  String namedItemDeleted(String name) {
    return '\"$name\" verwijderd';
  }

  @override
  String get oneItemCleared => '1 item gewist';

  @override
  String itemsCleared(int count) {
    return '$count items gewist';
  }

  @override
  String get noItemsSubMessage =>
      'Typ hierboven een item of gebruik Bulk toevoegen om te beginnen.';

  @override
  String get addProductToDatabase => 'Product toevoegen aan database';

  @override
  String get chooseSectionAndEnterProduct =>
      'Kies een sectie en voer productnamen in.';

  @override
  String get productNameEn => 'Productnaam (EN)';

  @override
  String get productNameEnHint => 'bijv. Apple';

  @override
  String get productNameNlOptional => 'Productnaam (NL) - Optioneel';

  @override
  String get productNameNlHint => 'bijv. Appel';

  @override
  String get pleaseFillRequiredFields => 'Vul alle verplichte velden in';

  @override
  String get productAdded => 'Product toegevoegd!';

  @override
  String get add => 'Toevoegen';

  @override
  String get restoreAll => 'Alles herstellen';

  @override
  String get empty => 'Legen';

  @override
  String get emptyRecentlyDeletedTitle => 'Onlangs verwijderd legen?';

  @override
  String get emptyRecentlyDeletedSingle =>
      '1 item wordt permanent verwijderd. Dit kan niet ongedaan worden gemaakt.';

  @override
  String emptyRecentlyDeletedMultiple(int count) {
    return '$count items worden permanent verwijderd. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get deleteForever => 'Definitief verwijderen';

  @override
  String get deleteItemForeverTitle => 'Item definitief verwijderen?';

  @override
  String deleteItemForeverMessage(String name) {
    return '\"$name\" wordt permanent verwijderd. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get recentlyDeletedRetentionBanner =>
      'Items worden na 7 dagen permanent verwijderd.';

  @override
  String get noRecentlyDeletedItems => 'Geen onlangs verwijderde items';

  @override
  String get noRecentlyDeletedSubMessage =>
      'Items die je van je boodschappenlijst verwijdert verschijnen hier 7 dagen.';

  @override
  String get itemRestored => 'Item hersteld';

  @override
  String namedItemRestored(String name) {
    return '\"$name\" hersteld naar je lijst';
  }

  @override
  String get oneItemRestored => '1 item hersteld';

  @override
  String itemsRestored(int count) {
    return '$count items hersteld';
  }

  @override
  String get restore => 'Herstellen';

  @override
  String get unnamedItem => '(naamloos)';

  @override
  String deletedTimeAgo(String time) {
    return 'Verwijderd: $time';
  }

  @override
  String get justNow => 'zojuist';

  @override
  String minutesAgo(int count) {
    return '$count min geleden';
  }

  @override
  String hoursAgo(int count) {
    return '$count u geleden';
  }

  @override
  String get oneDayAgo => '1 dag geleden';

  @override
  String daysAgo(int count) {
    return '$count dagen geleden';
  }

  @override
  String get oneDayLeft => 'Nog 1 dag';

  @override
  String daysLeft(int count) {
    return 'Nog $count dagen';
  }

  @override
  String hoursLeft(int count) {
    return 'Nog $count u';
  }

  @override
  String get lessThanHourLeft => 'minder dan een uur over';

  @override
  String get setQuantityAndUnit => 'Aantal en eenheid instellen';

  @override
  String get unit => 'Eenheid';

  @override
  String get none => 'Geen';

  @override
  String get ok => 'OK';

  @override
  String get changeCategory => 'Categorie wijzigen';

  @override
  String get bulkImportGroceries => 'Boodschappen bulk importeren';

  @override
  String get bulkImportHint =>
      'bijv.\n2 pakken melk\n1,5 kg appels\n2 tenen knoflook\n500g gehakt';

  @override
  String get next => 'Volgende';

  @override
  String get reviewItems => 'Items controleren';

  @override
  String get addAll => 'Alles toevoegen';

  @override
  String get editItem => 'Item bewerken';

  @override
  String get itemName => 'Naam';

  @override
  String get itemNameRequired => 'Voer een itemnaam in';

  @override
  String get noteOptional => 'Notitie (optioneel)';

  @override
  String get noteHint => 'bijv. biologisch, merk, enz.';

  @override
  String get category => 'Categorie';

  @override
  String get quantity => 'Aantal';

  @override
  String get save => 'Opslaan';

  @override
  String get uncheckAll => 'Alles uitvinken';

  @override
  String get oneItemUnchecked => '1 item uitgevinkt';

  @override
  String itemsUnchecked(int count) {
    return '$count items uitgevinkt';
  }

  @override
  String get shareList => 'Lijst delen';
}
