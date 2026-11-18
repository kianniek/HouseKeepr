import 'package:health_keepr/health_keepr.dart';

/// A single week inside a multi-week training [Programme].
class ProgrammeWeek {
  const ProgrammeWeek({
    required this.weekNumber,
    this.isDeload = false,
    this.targetRpe,
    this.liftPercentages = const <String, double>{},
  });

  factory ProgrammeWeek.fromJson(Map<String, dynamic> json) {
    final rawPcts = json['liftPercentages'] as Map? ?? const <String, dynamic>{};
    final parsedPcts = <String, double>{};
    for (final entry in rawPcts.entries) {
      if (entry.value is num) {
        parsedPcts[entry.key.toString()] = (entry.value as num).toDouble();
      }
    }
    return ProgrammeWeek(
      weekNumber: (json['weekNumber'] as num?)?.toInt() ?? 1,
      isDeload: (json['isDeload'] as bool?) ?? false,
      targetRpe: (json['targetRpe'] as num?)?.toDouble(),
      liftPercentages: parsedPcts,
    );
  }

  final int weekNumber;
  final bool isDeload;
  final double? targetRpe;
  final Map<String, double> liftPercentages;

  ProgrammeWeek copyWith({
    int? weekNumber,
    bool? isDeload,
    double? targetRpe,
    bool clearTargetRpe = false,
    Map<String, double>? liftPercentages,
  }) {
    return ProgrammeWeek(
      weekNumber: weekNumber ?? this.weekNumber,
      isDeload: isDeload ?? this.isDeload,
      targetRpe: clearTargetRpe ? null : (targetRpe ?? this.targetRpe),
      liftPercentages: liftPercentages ?? this.liftPercentages,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'weekNumber': weekNumber,
        'isDeload': isDeload,
        if (targetRpe != null) 'targetRpe': targetRpe,
        if (liftPercentages.isNotEmpty) 'liftPercentages': liftPercentages,
      };
}

/// A training programme mapping weekdays (1=Mon .. 7=Sun) to
/// [WorkoutTemplate] IDs, with optional multi-week block progression.
class Programme with HealthRecordMetadata {
  const Programme({
    required this.id,
    required this.name,
    this.description = '',
    required this.weekdayToTemplateId,
    this.isActive = false,
    this.weeks = const <ProgrammeWeek>[],
    this.currentWeek = 1,
    this.isPaused = false,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory Programme.create({
    required String name,
    String description = '',
    required Map<int, String> weekdayToTemplateId,
    bool isActive = true,
    List<ProgrammeWeek> weeks = const <ProgrammeWeek>[],
    int currentWeek = 1,
    bool isPaused = false,
  }) {
    return Programme(
      id: HealthRecordMetadata.generateId(),
      name: name,
      description: description,
      weekdayToTemplateId: weekdayToTemplateId,
      isActive: isActive,
      weeks: weeks,
      currentWeek: currentWeek,
      isPaused: isPaused,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory Programme.fromJson(Map<String, dynamic> json) {
    final rawSchedule = json['weekdayToTemplateId'] as Map? ?? const {};
    final parsed = <int, String>{};
    for (final entry in rawSchedule.entries) {
      final day = int.tryParse(entry.key.toString());
      if (day != null && entry.value is String) {
        parsed[day] = entry.value as String;
      }
    }
    final rawWeeks = json['weeks'] as List<dynamic>? ?? const <dynamic>[];
    return Programme(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      name: (json['name'] as String?) ?? 'Programme',
      description: (json['description'] as String?) ?? '',
      weekdayToTemplateId: parsed,
      isActive: (json['isActive'] as bool?) ?? false,
      weeks: rawWeeks
          .map(
            (w) => ProgrammeWeek.fromJson(Map<String, dynamic>.from(w as Map)),
          )
          .toList(),
      currentWeek: (json['currentWeek'] as num?)?.toInt() ?? 1,
      isPaused: (json['isPaused'] as bool?) ?? false,
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;
  final String name;
  final String description;
  final Map<int, String> weekdayToTemplateId;
  final bool isActive;
  final List<ProgrammeWeek> weeks;
  final int currentWeek;
  final bool isPaused;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  Programme copyWith({
    String? name,
    String? description,
    Map<int, String>? weekdayToTemplateId,
    bool? isActive,
    List<ProgrammeWeek>? weeks,
    int? currentWeek,
    bool? isPaused,
  }) {
    return Programme(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      weekdayToTemplateId: weekdayToTemplateId ?? this.weekdayToTemplateId,
      isActive: isActive ?? this.isActive,
      weeks: weeks ?? this.weeks,
      currentWeek: currentWeek ?? this.currentWeek,
      isPaused: isPaused ?? this.isPaused,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'name': name,
        'description': description,
        'weekdayToTemplateId': weekdayToTemplateId
            .map((k, v) => MapEntry<String, String>(k.toString(), v)),
        'isActive': isActive,
        if (weeks.isNotEmpty)
          'weeks': weeks.map((w) => w.toJson()).toList(),
        if (currentWeek != 1) 'currentWeek': currentWeek,
        if (isPaused) 'isPaused': isPaused,
      };
}
