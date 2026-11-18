import 'package:health_keepr/health_keepr.dart';

/// A body measurement check-in (circumferences, body fat %, blood pressure).
class BodyMeasurement with HealthRecordMetadata {
  const BodyMeasurement({
    required this.id,
    required this.date,
    this.bodyFatPct,
    this.chestCm,
    this.waistCm,
    this.hipsCm,
    this.armsCm,
    this.thighsCm,
    this.calvesCm,
    this.bpSys,
    this.bpDia,
    this.pulse,
    this.note,
    this.source,
    this.healthConnectId,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory BodyMeasurement.create({
    required String date,
    double? bodyFatPct,
    double? chestCm,
    double? waistCm,
    double? hipsCm,
    double? armsCm,
    double? thighsCm,
    double? calvesCm,
    int? bpSys,
    int? bpDia,
    int? pulse,
    String? note,
    String? source,
    String? healthConnectId,
  }) {
    return BodyMeasurement(
      id: HealthRecordMetadata.generateId(),
      date: date,
      bodyFatPct: bodyFatPct,
      chestCm: chestCm,
      waistCm: waistCm,
      hipsCm: hipsCm,
      armsCm: armsCm,
      thighsCm: thighsCm,
      calvesCm: calvesCm,
      bpSys: bpSys,
      bpDia: bpDia,
      pulse: pulse,
      note: note,
      source: source,
      healthConnectId: healthConnectId,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory BodyMeasurement.fromJson(Map<String, dynamic> json) {
    return BodyMeasurement(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      date: (json['date'] as String?) ?? '',
      bodyFatPct: (json['bodyFatPct'] as num?)?.toDouble(),
      chestCm: (json['chestCm'] as num?)?.toDouble(),
      waistCm: (json['waistCm'] as num?)?.toDouble(),
      hipsCm: (json['hipsCm'] as num?)?.toDouble(),
      armsCm: (json['armsCm'] as num?)?.toDouble(),
      thighsCm: (json['thighsCm'] as num?)?.toDouble(),
      calvesCm: (json['calvesCm'] as num?)?.toDouble(),
      bpSys: (json['bpSys'] as num?)?.toInt(),
      bpDia: (json['bpDia'] as num?)?.toInt(),
      pulse: (json['pulse'] as num?)?.toInt(),
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
  final String date;
  final double? bodyFatPct;
  final double? chestCm;
  final double? waistCm;
  final double? hipsCm;
  final double? armsCm;
  final double? thighsCm;
  final double? calvesCm;
  final int? bpSys;
  final int? bpDia;
  final int? pulse;
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
        if (bodyFatPct != null) 'bodyFatPct': bodyFatPct,
        if (chestCm != null) 'chestCm': chestCm,
        if (waistCm != null) 'waistCm': waistCm,
        if (hipsCm != null) 'hipsCm': hipsCm,
        if (armsCm != null) 'armsCm': armsCm,
        if (thighsCm != null) 'thighsCm': thighsCm,
        if (calvesCm != null) 'calvesCm': calvesCm,
        if (bpSys != null) 'bpSys': bpSys,
        if (bpDia != null) 'bpDia': bpDia,
        if (pulse != null) 'pulse': pulse,
        if (note != null && note!.isNotEmpty) 'note': note,
        if (source != null) 'source': source,
        if (healthConnectId != null) 'healthConnectId': healthConnectId,
      };
}
