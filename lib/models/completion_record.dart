import 'dart:convert';
import 'package:uuid/uuid.dart';

class CompletionRecord {
  final String id;
  final String taskId;
  // date in ISO YYYY-MM-DD representing the occurrence date (UTC)
  final String date;
  final String? completedBy;
  final DateTime createdAt;

  CompletionRecord({
    String? id,
    required this.taskId,
    required this.date,
    this.completedBy,
    DateTime? createdAt,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now().toUtc();

  Map<String, dynamic> toMap() => {
    'id': id,
    'taskId': taskId,
    'date': date,
    'completedBy': completedBy,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory CompletionRecord.fromMap(Map<String, dynamic> m) => CompletionRecord(
    id: m['id']?.toString(),
    taskId: m['taskId']?.toString() ?? '',
    date: m['date']?.toString() ?? '',
    completedBy: m['completedBy']?.toString(),
    createdAt: m['createdAt'] is String
        ? DateTime.parse(m['createdAt']).toUtc()
        : DateTime.now().toUtc(),
  );

  String toJson() => json.encode(toMap());

  factory CompletionRecord.fromJson(String s) =>
      CompletionRecord.fromMap(json.decode(s) as Map<String, dynamic>);
}
