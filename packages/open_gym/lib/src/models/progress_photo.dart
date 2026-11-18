import 'package:health_keepr/health_keepr.dart';

/// A locally stored progress photo (base64-encoded for Android & Web portability).
class ProgressPhoto with HealthRecordMetadata {
  const ProgressPhoto({
    required this.id,
    required this.date,
    this.pose = 'front',
    required this.base64Image,
    this.note,
    required this.updatedAt,
    this.isSynced = false,
  });

  factory ProgressPhoto.create({
    required String date,
    String pose = 'front',
    required String base64Image,
    String? note,
  }) {
    return ProgressPhoto(
      id: HealthRecordMetadata.generateId(),
      date: date,
      pose: pose,
      base64Image: base64Image,
      note: note,
      updatedAt: HealthRecordMetadata.nowUtcIso(),
      isSynced: false,
    );
  }

  factory ProgressPhoto.fromJson(Map<String, dynamic> json) {
    return ProgressPhoto(
      id: (json['id'] as String?) ?? HealthRecordMetadata.generateId(),
      date: (json['date'] as String?) ?? '',
      pose: (json['pose'] as String?) ?? 'front',
      base64Image: (json['base64Image'] as String?) ?? '',
      note: json['note'] as String?,
      updatedAt:
          (json['updatedAt'] as String?) ?? HealthRecordMetadata.nowUtcIso(),
      isSynced: (json['isSynced'] as bool?) ?? false,
    );
  }

  @override
  final String id;
  final String date;
  final String pose;
  final String base64Image;
  final String? note;
  @override
  final String updatedAt;
  @override
  final bool isSynced;

  Map<String, dynamic> toJson() => <String, dynamic>{
        ...metadataToJson(),
        'date': date,
        'pose': pose,
        'base64Image': base64Image,
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}
