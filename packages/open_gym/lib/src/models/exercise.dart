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
      isCustom: isCustom,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      name: (json['name'] as String?) ?? '',
      bodyPart: (json['bodyPart'] as String?) ?? 'full body',
      equipment: (json['equipment'] as String?) ?? 'body weight',
      target: (json['target'] as String?) ?? '',
      secondaryMuscles: (json['secondaryMuscles'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
      category: (json['category'] as String?) ?? 'strength',
      description: (json['description'] as String?) ?? '',
      instructions: (json['instructions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>[],
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
  final bool isCustom;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

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
        'isCustom': isCustom,
      };
}
