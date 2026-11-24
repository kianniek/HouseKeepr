import 'package:flutter/foundation.dart';

import '../../contracts/health_record_metadata.dart';
import 'meal_type.dart';
import 'nutrition_food.dart';

/// Persisted meal entry stored locally under `moduleId = 'food_tracker'`.
@immutable
class MealLog with HealthRecordMetadata {
  const MealLog({
    required this.id,
    required this.foodName,
    this.foodId,
    required this.mealType,
    required this.servingGrams,
    required this.kcal,
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.loggedAt,
    this.healthConnectId,
    required this.updatedAt,
    required this.isSynced,
  });

  /// Creates a new [MealLog] with generated UUID v4 [id] and UTC timestamps.
  factory MealLog.create({
    required String foodName,
    String? foodId,
    required MealType mealType,
    required double servingGrams,
    required double kcal,
    required double proteinGrams,
    required double carbsGrams,
    required double fatGrams,
    DateTime? loggedAt,
    String? healthConnectId,
  }) {
    final nowIso = HealthRecordMetadata.nowUtcIso();
    final loggedIso = (loggedAt ?? DateTime.now()).toUtc().toIso8601String();
    return MealLog(
      id: HealthRecordMetadata.generateId(),
      foodName: foodName.trim(),
      foodId: foodId,
      mealType: mealType,
      servingGrams: _sanitizeNonNegativeFinite(servingGrams),
      kcal: _sanitizeNonNegativeFinite(kcal),
      proteinGrams: _sanitizeNonNegativeFinite(proteinGrams),
      carbsGrams: _sanitizeNonNegativeFinite(carbsGrams),
      fatGrams: _sanitizeNonNegativeFinite(fatGrams),
      loggedAt: loggedIso,
      healthConnectId: healthConnectId,
      updatedAt: nowIso,
      isSynced: false,
    );
  }

  /// Creates a [MealLog] scaled from a [NutritionFood] profile.
  factory MealLog.fromNutritionFood({
    required NutritionFood food,
    required MealType mealType,
    double? servingGrams,
    DateTime? loggedAt,
    String? healthConnectId,
  }) {
    final grams =
        (servingGrams != null && servingGrams.isFinite && servingGrams > 0)
            ? servingGrams
            : food.defaultServingGrams;
    final macros = food.macrosForGrams(grams);
    return MealLog.create(
      foodName: food.name,
      foodId: food.id.isEmpty ? null : food.id,
      mealType: mealType,
      servingGrams: _sanitizeNonNegativeFinite(macros.servingGrams),
      kcal: _sanitizeNonNegativeFinite(macros.kcal),
      proteinGrams: _sanitizeNonNegativeFinite(macros.proteinGrams),
      carbsGrams: _sanitizeNonNegativeFinite(macros.carbsGrams),
      fatGrams: _sanitizeNonNegativeFinite(macros.fatGrams),
      loggedAt: loggedAt,
      healthConnectId: healthConnectId,
    );
  }

  factory MealLog.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final id = (rawId is String && rawId.isNotEmpty)
        ? rawId
        : HealthRecordMetadata.generateId();
    final rawUpdatedAt = json['updatedAt'];
    final updatedAt = (rawUpdatedAt is String && rawUpdatedAt.isNotEmpty)
        ? rawUpdatedAt
        : HealthRecordMetadata.nowUtcIso();
    final rawLoggedAt = json['loggedAt'];
    final loggedAt = (rawLoggedAt is String && rawLoggedAt.isNotEmpty)
        ? rawLoggedAt
        : updatedAt;
    final rawFoodName = json['foodName'];
    final rawFoodId = json['foodId'];
    final rawMealType = json['mealType'];
    final rawHealthConnectId = json['healthConnectId'];
    final rawIsSynced = json['isSynced'];

    return MealLog(
      id: id,
      foodName: (rawFoodName is String ? rawFoodName : '').trim(),
      foodId: rawFoodId is String ? rawFoodId : null,
      mealType: MealType.fromString(rawMealType is String ? rawMealType : null),
      servingGrams: _readDouble(json['servingGrams']),
      kcal: _readDouble(json['kcal']),
      proteinGrams: _readDouble(json['proteinGrams']),
      carbsGrams: _readDouble(json['carbsGrams']),
      fatGrams: _readDouble(json['fatGrams']),
      loggedAt: loggedAt,
      healthConnectId: rawHealthConnectId is String ? rawHealthConnectId : null,
      updatedAt: updatedAt,
      isSynced: rawIsSynced is bool ? rawIsSynced : false,
    );
  }

  @override
  final String id;
  final String foodName;
  final String? foodId;
  final MealType mealType;
  final double servingGrams;
  final double kcal;
  final double proteinGrams;
  final double carbsGrams;
  final double fatGrams;
  final String loggedAt;
  final String? healthConnectId;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  /// Parses [loggedAt] in local time, or `null` if invalid.
  DateTime? get loggedAtLocal => DateTime.tryParse(loggedAt)?.toLocal();

  /// Returns `true` if [loggedAt] falls on the same local calendar day as [date].
  bool isOnLocalDate(DateTime date) {
    final local = loggedAtLocal;
    if (local == null) return false;
    final target = date.toLocal();
    return local.year == target.year &&
        local.month == target.month &&
        local.day == target.day;
  }

  /// Returns an updated copy with [updatedAt] refreshed by default.
  MealLog copyWith({
    String? id,
    String? foodName,
    String? foodId,
    bool clearFoodId = false,
    MealType? mealType,
    double? servingGrams,
    double? kcal,
    double? proteinGrams,
    double? carbsGrams,
    double? fatGrams,
    String? loggedAt,
    String? healthConnectId,
    bool clearHealthConnectId = false,
    String? updatedAt,
    bool? isSynced,
  }) {
    final String resolvedUpdatedAt;
    if (updatedAt != null) {
      resolvedUpdatedAt = updatedAt;
    } else {
      final now = DateTime.now().toUtc();
      final previous = DateTime.tryParse(this.updatedAt)?.toUtc();
      if (previous != null && !now.isAfter(previous)) {
        resolvedUpdatedAt =
            previous.add(const Duration(microseconds: 1)).toIso8601String();
      } else {
        resolvedUpdatedAt = now.toIso8601String();
      }
    }

    return MealLog(
      id: id ?? this.id,
      foodName: foodName ?? this.foodName,
      foodId: clearFoodId ? null : (foodId ?? this.foodId),
      mealType: mealType ?? this.mealType,
      servingGrams: servingGrams != null
          ? _sanitizeNonNegativeFinite(servingGrams)
          : this.servingGrams,
      kcal: kcal != null ? _sanitizeNonNegativeFinite(kcal) : this.kcal,
      proteinGrams: proteinGrams != null
          ? _sanitizeNonNegativeFinite(proteinGrams)
          : this.proteinGrams,
      carbsGrams: carbsGrams != null
          ? _sanitizeNonNegativeFinite(carbsGrams)
          : this.carbsGrams,
      fatGrams: fatGrams != null
          ? _sanitizeNonNegativeFinite(fatGrams)
          : this.fatGrams,
      loggedAt: loggedAt ?? this.loggedAt,
      healthConnectId: clearHealthConnectId
          ? null
          : (healthConnectId ?? this.healthConnectId),
      updatedAt: resolvedUpdatedAt,
      isSynced: isSynced ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'foodName': foodName,
        if (foodId != null) 'foodId': foodId,
        'mealType': mealType.name,
        'servingGrams': servingGrams,
        'kcal': kcal,
        'proteinGrams': proteinGrams,
        'carbsGrams': carbsGrams,
        'fatGrams': fatGrams,
        'loggedAt': loggedAt,
        if (healthConnectId != null) 'healthConnectId': healthConnectId,
      };

  static double _sanitizeNonNegativeFinite(double value) {
    if (value.isNaN || value <= 0) return 0.0;
    return value.isFinite ? value : double.maxFinite;
  }

  static double _readDouble(Object? raw) {
    if (raw is num) {
      final value = raw.toDouble();
      return (value.isFinite && value > 0) ? value : 0.0;
    }
    if (raw is String) {
      final parsed = double.tryParse(raw.trim());
      if (parsed != null && parsed.isFinite && parsed > 0) return parsed;
    }
    return 0.0;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MealLog &&
        other.id == id &&
        other.foodName == foodName &&
        other.foodId == foodId &&
        other.mealType == mealType &&
        other.servingGrams == servingGrams &&
        other.kcal == kcal &&
        other.proteinGrams == proteinGrams &&
        other.carbsGrams == carbsGrams &&
        other.fatGrams == fatGrams &&
        other.loggedAt == loggedAt &&
        other.healthConnectId == healthConnectId &&
        other.updatedAt == updatedAt &&
        other.isSynced == isSynced;
  }

  @override
  int get hashCode => Object.hash(
        id,
        foodName,
        foodId,
        mealType,
        servingGrams,
        kcal,
        proteinGrams,
        carbsGrams,
        fatGrams,
        loggedAt,
        healthConnectId,
        updatedAt,
        isSynced,
      );
}
