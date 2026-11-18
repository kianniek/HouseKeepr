import 'package:health_keepr/health_keepr.dart';

/// Represents a single exercise in the OpenGym library (built-in or custom).
class Exercise with HealthRecordMetadata {
  const Exercise({
    required this.id,
    required this.name,
    required this.bodyPart,
    required this.equipment,
    required this.target,
    this.secondaryMuscles = const <String>[],
    this.category = 'strength',
    this.description = '',
    this.instructions = const <String>[],
    this.muscleWeights = const <String, double>{},
    this.isCustom = false,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory Exercise.create({
    String? id,
    required String name,
    required String bodyPart,
    required String equipment,
    required String target,
    List<String> secondaryMuscles = const <String>[],
    String category = 'strength',
    String description = '',
    List<String> instructions = const <String>[],
    Map<String, double> muscleWeights = const <String, double>{},
    bool isCustom = true,
  }) {
    return Exercise(
      id: id ?? HealthRecordMetadata.generateId(),
      name: name,
      bodyPart: bodyPart,
      equipment: equipment,
      target: target,
      secondaryMuscles: secondaryMuscles,
      category: category,
      description: description,
      instructions: instructions,
      muscleWeights: muscleWeights,
      isCustom: isCustom,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    final rawMap = json['muscleMap'];
    final weights = <String, double>{};
    if (rawMap is Map && rawMap['weights'] is Map) {
      final wMap = rawMap['weights'] as Map;
      for (final entry in wMap.entries) {
        final v = entry.value;
        if (v is num) weights[entry.key.toString()] = v.toDouble();
      }
    } else if (json['muscleWeights'] is Map) {
      final wMap = json['muscleWeights'] as Map;
      for (final entry in wMap.entries) {
        final v = entry.value;
        if (v is num) weights[entry.key.toString()] = v.toDouble();
      }
    }

    final secondaryRaw = json['secondaryMuscles'];
    final secondaryMuscles = secondaryRaw is List
        ? <String>[for (final e in secondaryRaw) e.toString()]
        : const <String>[];

    final instructionsRaw = json['instructions'];
    final instructions = instructionsRaw is List
        ? <String>[for (final e in instructionsRaw) e.toString()]
        : const <String>[];

    return Exercise(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      name: (json['name'] as String?) ?? '',
      bodyPart: (json['bodyPart'] as String?) ?? 'full body',
      equipment: (json['equipment'] as String?) ?? 'body weight',
      target: (json['target'] as String?) ?? '',
      secondaryMuscles: secondaryMuscles,
      category: (json['category'] as String?) ?? 'strength',
      description: (json['description'] as String?) ?? '',
      instructions: instructions,
      muscleWeights: weights,
      isCustom: (json['isCustom'] as bool?) ?? false,
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;
  final String name;
  final String bodyPart;
  final String equipment;
  final String target;
  final List<String> secondaryMuscles;
  final String category;
  final String description;
  final List<String> instructions;
  final Map<String, double> muscleWeights;
  final bool isCustom;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  bool get isAssisted =>
      equipment.toLowerCase().contains('assisted') ||
      name.toLowerCase().contains('assisted');

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'name': name,
        'bodyPart': bodyPart,
        'equipment': equipment,
        'target': target,
        'secondaryMuscles': secondaryMuscles,
        'category': category,
        'description': description,
        'instructions': instructions,
        if (muscleWeights.isNotEmpty) 'muscleWeights': muscleWeights,
        'isCustom': isCustom,
      };
}
