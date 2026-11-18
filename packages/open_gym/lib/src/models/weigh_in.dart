import 'package:health_keepr/health_keepr.dart';

/// A daily bodyweight entry stored locally in `health_keepr.db`.
class WeighIn with HealthRecordMetadata {
  const WeighIn({
    required this.id,
    required this.date,
    required this.weightKg,
    this.note,
    this.source,
    this.healthConnectId,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory WeighIn.create({
    required String date,
    required double weightKg,
    String? note,
    String? source,
    String? healthConnectId,
  }) {
    return WeighIn(
      id: HealthRecordMetadata.generateId(),
      date: date,
      weightKg: weightKg,
      note: note,
      source: source,
      healthConnectId: healthConnectId,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory WeighIn.fromJson(Map<String, dynamic> json) {
    return WeighIn(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      date: (json['date'] as String?) ?? '',
      weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
      note: json['note'] as String?,
      source: json['source'] as String?,
      healthConnectId: json['healthConnectId'] as String?,
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;

  /// Calendar date in `YYYY-MM-DD` format.
  final String date;
  final double weightKg;
  final String? note;
  final String? source;
  final String? healthConnectId;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'date': date,
        'weightKg': weightKg,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (source != null) 'source': source,
        if (healthConnectId != null) 'healthConnectId': healthConnectId,
      };
}
