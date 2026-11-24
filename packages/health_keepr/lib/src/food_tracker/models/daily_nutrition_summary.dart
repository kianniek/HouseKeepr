import 'package:flutter/foundation.dart';

import 'meal_log.dart';
import 'meal_type.dart';

/// Aggregated daily calorie, macro, and meal-type summary for a local day.
@immutable
class DailyNutritionSummary {
  const DailyNutritionSummary({
    required this.date,
    required this.dailyKcalGoal,
    required this.totalKcal,
    required this.totalProteinGrams,
    required this.totalCarbsGrams,
    required this.totalFatGrams,
    required this.mealsByType,
    required this.kcalByMealType,
  });

  /// Aggregates [logs] matching [date]'s local calendar day into all 4 [MealType] buckets.
  factory DailyNutritionSummary.fromMealLogs({
    required DateTime date,
    required List<MealLog> logs,
    double dailyKcalGoal = 2000.0,
  }) {
    final localDate = date.toLocal();
    final normalizedDay = DateTime(
      localDate.year,
      localDate.month,
      localDate.day,
    );

    final buckets = <MealType, List<MealLog>>{
      for (final type in MealType.values) type: <MealLog>[],
    };
    final kcalTotals = <MealType, double>{
      for (final type in MealType.values) type: 0.0,
    };

    var totalKcal = 0.0;
    var totalProtein = 0.0;
    var totalCarbs = 0.0;
    var totalFat = 0.0;

    for (final log in logs) {
      if (!log.isOnLocalDate(normalizedDay)) continue;
      buckets[log.mealType]!.add(log);
      kcalTotals[log.mealType] = (kcalTotals[log.mealType] ?? 0.0) + log.kcal;
      totalKcal += log.kcal;
      totalProtein += log.proteinGrams;
      totalCarbs += log.carbsGrams;
      totalFat += log.fatGrams;
    }

    for (final type in MealType.values) {
      buckets[type]!.sort((a, b) {
        final aTime = a.loggedAtLocal;
        final bTime = b.loggedAtLocal;
        if (aTime != null && bTime != null) {
          return aTime.compareTo(bTime);
        }
        if (aTime != null) return -1;
        if (bTime != null) return 1;
        return a.loggedAt.compareTo(b.loggedAt);
      });
    }

    final sanitizedGoal =
        (dailyKcalGoal.isFinite && dailyKcalGoal > 0) ? dailyKcalGoal : 0.0;

    return DailyNutritionSummary(
      date: normalizedDay,
      dailyKcalGoal: sanitizedGoal,
      totalKcal: totalKcal,
      totalProteinGrams: totalProtein,
      totalCarbsGrams: totalCarbs,
      totalFatGrams: totalFat,
      mealsByType: Map<MealType, List<MealLog>>.unmodifiable(<MealType, List<MealLog>>{
        for (final type in MealType.values)
          type: List<MealLog>.unmodifiable(buckets[type]!),
      }),
      kcalByMealType: Map<MealType, double>.unmodifiable(kcalTotals),
    );
  }

  final DateTime date;
  final double dailyKcalGoal;
  final double totalKcal;
  final double totalProteinGrams;
  final double totalCarbsGrams;
  final double totalFatGrams;
  final Map<MealType, List<MealLog>> mealsByType;
  final Map<MealType, double> kcalByMealType;

  /// Remaining calories before reaching [dailyKcalGoal] (negative when over).
  double get remainingKcal => dailyKcalGoal - totalKcal;

  /// Calories above [dailyKcalGoal], or `0.0` if at or under goal.
  double get overageKcal =>
      totalKcal > dailyKcalGoal ? totalKcal - dailyKcalGoal : 0.0;

  /// Clamped progress in `[0.0, 1.0]` toward [dailyKcalGoal].
  double get goalProgress {
    if (!dailyKcalGoal.isFinite || dailyKcalGoal <= 0 || !totalKcal.isFinite) {
      return 0.0;
    }
    final ratio = totalKcal / dailyKcalGoal;
    if (!ratio.isFinite) return totalKcal > 0 ? 1.0 : 0.0;
    return ratio.clamp(0.0, 1.0);
  }

  /// Whether [totalKcal] exceeds a positive [dailyKcalGoal].
  bool get isOverGoal =>
      dailyKcalGoal.isFinite &&
      dailyKcalGoal > 0 &&
      totalKcal.isFinite &&
      totalKcal > dailyKcalGoal;

  /// Total logged meals across all [MealType] buckets.
  int get mealCount => mealsByType.values.fold<int>(
        0,
        (sum, bucket) => sum + bucket.length,
      );

  /// All meals for [type] in chronological order.
  List<MealLog> logsForMealType(MealType type) =>
      mealsByType[type] ?? const <MealLog>[];

  /// Total kcal logged under [type].
  double kcalForMealType(MealType type) => kcalByMealType[type] ?? 0.0;
}
