import 'package:shared_preferences/shared_preferences.dart';

/// Persistent settings for HouseKeepr's Android home-screen widgets.
class WidgetSettings {
  final bool pillHideUnusedToggles;
  final String pillWidgetTitle;
  final bool pillShowDoseCount;
  final bool shoppingHideChecked;
  final bool shoppingShowItemCount;
  final bool coffeeIncludeCustomRecipes;
  final bool coffeeShowSubtitle;

  const WidgetSettings({
    this.pillHideUnusedToggles = false,
    this.pillWidgetTitle = 'Pillen',
    this.pillShowDoseCount = false,
    this.shoppingHideChecked = false,
    this.shoppingShowItemCount = true,
    this.coffeeIncludeCustomRecipes = true,
    this.coffeeShowSubtitle = true,
  });

  WidgetSettings copyWith({
    bool? pillHideUnusedToggles,
    String? pillWidgetTitle,
    bool? pillShowDoseCount,
    bool? shoppingHideChecked,
    bool? shoppingShowItemCount,
    bool? coffeeIncludeCustomRecipes,
    bool? coffeeShowSubtitle,
  }) {
    return WidgetSettings(
      pillHideUnusedToggles:
          pillHideUnusedToggles ?? this.pillHideUnusedToggles,
      pillWidgetTitle: pillWidgetTitle ?? this.pillWidgetTitle,
      pillShowDoseCount: pillShowDoseCount ?? this.pillShowDoseCount,
      shoppingHideChecked: shoppingHideChecked ?? this.shoppingHideChecked,
      shoppingShowItemCount:
          shoppingShowItemCount ?? this.shoppingShowItemCount,
      coffeeIncludeCustomRecipes:
          coffeeIncludeCustomRecipes ?? this.coffeeIncludeCustomRecipes,
      coffeeShowSubtitle: coffeeShowSubtitle ?? this.coffeeShowSubtitle,
    );
  }
}

/// Reads and writes [WidgetSettings] to [SharedPreferences].
class WidgetSettingsRepository {
  static const String pillHideUnusedTogglesKey = 'pill_hide_unused_toggles_v1';
  static const String pillWidgetTitleKey = 'pill_widget_title_v1';
  static const String pillShowDoseCountKey = 'pill_show_dose_count_v1';
  static const String shoppingHideCheckedKey = 'shopping_hide_checked_v1';
  static const String shoppingShowItemCountKey = 'shopping_show_item_count_v1';
  static const String coffeeIncludeCustomRecipesKey =
      'coffee_include_custom_recipes_v1';
  static const String coffeeShowSubtitleKey = 'coffee_show_subtitle_v1';

  final SharedPreferences prefs;

  const WidgetSettingsRepository(this.prefs);

  WidgetSettings load() {
    return WidgetSettings(
      pillHideUnusedToggles: prefs.getBool(pillHideUnusedTogglesKey) ?? false,
      pillWidgetTitle: prefs.getString(pillWidgetTitleKey) ?? 'Pillen',
      pillShowDoseCount: prefs.getBool(pillShowDoseCountKey) ?? false,
      shoppingHideChecked: prefs.getBool(shoppingHideCheckedKey) ?? false,
      shoppingShowItemCount: prefs.getBool(shoppingShowItemCountKey) ?? true,
      coffeeIncludeCustomRecipes:
          prefs.getBool(coffeeIncludeCustomRecipesKey) ?? true,
      coffeeShowSubtitle: prefs.getBool(coffeeShowSubtitleKey) ?? true,
    );
  }

  Future<void> save(WidgetSettings settings) async {
    await Future.wait([
      prefs.setBool(pillHideUnusedTogglesKey, settings.pillHideUnusedToggles),
      prefs.setString(pillWidgetTitleKey, settings.pillWidgetTitle),
      prefs.setBool(pillShowDoseCountKey, settings.pillShowDoseCount),
      prefs.setBool(shoppingHideCheckedKey, settings.shoppingHideChecked),
      prefs.setBool(shoppingShowItemCountKey, settings.shoppingShowItemCount),
      prefs.setBool(
        coffeeIncludeCustomRecipesKey,
        settings.coffeeIncludeCustomRecipes,
      ),
      prefs.setBool(coffeeShowSubtitleKey, settings.coffeeShowSubtitle),
    ]);
  }
}
