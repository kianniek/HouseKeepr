import 'dart:convert';
import 'package:equatable/equatable.dart';

/// Recurrence pattern for personal medications.
enum MedicationRecurrenceType {
  /// Scheduled every day.
  daily,

  /// Scheduled on specific days of the week (1 = Monday, ..., 7 = Sunday).
  specificDaysOfWeek,

  /// Scheduled every N days (e.g. every 2 days).
  intervalDays,
}

/// Time-of-day slots corresponding to the Android widget wireframe:
/// - [morning] (Sun ☀️): daytime/morning scheduled doses (typically before 17:00).
/// - [evening] (Moon 🌙): evening/nighttime scheduled doses (17:00 and later).
enum TimeOfDaySlot {
  morning,
  evening;

  static TimeOfDaySlot fromHour(int hour) {
    return hour < 17 ? TimeOfDaySlot.morning : TimeOfDaySlot.evening;
  }
}

/// Status of an individual dose instance.
enum DoseStatus { pending, taken, skipped }

/// Time of day for a scheduled dose (24-hour format).
class MedicationTime extends Equatable {
  final int hour;
  final int minute;
  final TimeOfDaySlot slot;

  MedicationTime({
    required this.hour,
    required this.minute,
    TimeOfDaySlot? slot,
  }) : assert(hour >= 0 && hour <= 23, 'Hour must be between 0 and 23'),
       assert(minute >= 0 && minute <= 59, 'Minute must be between 0 and 59'),
       slot = slot ?? TimeOfDaySlot.fromHour(hour);

  String format24h() {
    final h = hour.toString().padLeft(2, '0');
    final m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Map<String, dynamic> toMap() => {
    'hour': hour,
    'minute': minute,
    'slot': slot.name,
  };

  factory MedicationTime.fromMap(Map<String, dynamic> map) {
    final hour = map['hour'] as int? ?? 8;
    final minute = map['minute'] as int? ?? 0;
    final slotName = map['slot'] as String?;
    final slot = slotName != null
        ? TimeOfDaySlot.values.firstWhere(
            (e) => e.name == slotName,
            orElse: () => TimeOfDaySlot.fromHour(hour),
          )
        : TimeOfDaySlot.fromHour(hour);
    return MedicationTime(hour: hour, minute: minute, slot: slot);
  }

  factory MedicationTime.fromString(String timeStr, {TimeOfDaySlot? slot}) {
    final parts = timeStr.trim().split(':');
    final hour = int.tryParse(parts.isNotEmpty ? parts[0] : '8') ?? 8;
    final minute = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return MedicationTime(hour: hour, minute: minute, slot: slot);
  }

  @override
  List<Object?> get props => [hour, minute, slot];
}

/// Persistent record of a user's action on a scheduled dose.
class DoseRecord extends Equatable {
  final String doseId;
  final String medicationId;
  final String dateKey; // YYYY-MM-DD
  final DoseStatus status;
  final DateTime timestamp;

  const DoseRecord({
    required this.doseId,
    required this.medicationId,
    required this.dateKey,
    required this.status,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
    'doseId': doseId,
    'medicationId': medicationId,
    'dateKey': dateKey,
    'status': status.name,
    'timestamp': timestamp.toIso8601String(),
  };

  factory DoseRecord.fromMap(Map<String, dynamic> map) {
    return DoseRecord(
      doseId: map['doseId'] as String? ?? '',
      medicationId: map['medicationId'] as String? ?? '',
      dateKey: map['dateKey'] as String? ?? '',
      status: DoseStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DoseStatus.pending,
      ),
      timestamp: map['timestamp'] != null
          ? DateTime.tryParse(map['timestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [doseId, medicationId, dateKey, status, timestamp];
}

/// A materialized dose instance for a specific day and time.
class DoseInstance extends Equatable {
  final String id;
  final String medicationId;
  final String medicationName;
  final String dosage;
  final DateTime scheduledDate;
  final MedicationTime time;
  final TimeOfDaySlot slot;
  final DoseStatus status;
  final DateTime? actionTime;

  const DoseInstance({
    required this.id,
    required this.medicationId,
    required this.medicationName,
    required this.dosage,
    required this.scheduledDate,
    required this.time,
    required this.slot,
    this.status = DoseStatus.pending,
    this.actionTime,
  });

  bool get isTaken => status == DoseStatus.taken;
  bool get isSkipped => status == DoseStatus.skipped;
  bool get isPending => status == DoseStatus.pending;

  DoseInstance copyWith({
    String? id,
    String? medicationId,
    String? medicationName,
    String? dosage,
    DateTime? scheduledDate,
    MedicationTime? time,
    TimeOfDaySlot? slot,
    DoseStatus? status,
    DateTime? actionTime,
  }) => DoseInstance(
    id: id ?? this.id,
    medicationId: medicationId ?? this.medicationId,
    medicationName: medicationName ?? this.medicationName,
    dosage: dosage ?? this.dosage,
    scheduledDate: scheduledDate ?? this.scheduledDate,
    time: time ?? this.time,
    slot: slot ?? this.slot,
    status: status ?? this.status,
    actionTime: actionTime ?? this.actionTime,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'medicationId': medicationId,
    'medicationName': medicationName,
    'dosage': dosage,
    'scheduledDate': scheduledDate.toIso8601String(),
    'time': time.toMap(),
    'slot': slot.name,
    'status': status.name,
    'actionTime': actionTime?.toIso8601String(),
  };

  factory DoseInstance.fromMap(Map<String, dynamic> map) {
    return DoseInstance(
      id: map['id'] as String? ?? '',
      medicationId: map['medicationId'] as String? ?? '',
      medicationName: map['medicationName'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      scheduledDate:
          DateTime.tryParse(map['scheduledDate'] as String? ?? '') ??
          DateTime.now(),
      time: MedicationTime.fromMap(
        Map<String, dynamic>.from(map['time'] as Map? ?? {}),
      ),
      slot: TimeOfDaySlot.values.firstWhere(
        (e) => e.name == map['slot'],
        orElse: () => TimeOfDaySlot.morning,
      ),
      status: DoseStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => DoseStatus.pending,
      ),
      actionTime: map['actionTime'] != null
          ? DateTime.tryParse(map['actionTime'] as String)
          : null,
    );
  }

  @override
  List<Object?> get props => [
    id,
    medicationId,
    medicationName,
    dosage,
    scheduledDate,
    time,
    slot,
    status,
    actionTime,
  ];
}

/// Personal medication definition.
class Medication extends Equatable {
  static const Object _sentinel = Object();

  final String id;
  final String name;
  final String dosage;
  final bool isActive;
  final MedicationRecurrenceType recurrenceType;
  final List<int> daysOfWeek; // 1 = Monday, 7 = Sunday
  final int intervalDays; // e.g., every 2 days
  final DateTime startDate;
  final DateTime? endDate;
  final List<MedicationTime> notificationTimes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Medication({
    required this.id,
    required this.name,
    this.dosage = '',
    this.isActive = true,
    this.recurrenceType = MedicationRecurrenceType.daily,
    this.daysOfWeek = const [1, 2, 3, 4, 5, 6, 7],
    this.intervalDays = 1,
    DateTime? startDate,
    this.endDate,
    this.notificationTimes = const [],
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : startDate = startDate != null
           ? DateTime(startDate.year, startDate.month, startDate.day)
           : DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? createdAt ?? DateTime.now();

  bool get isValid =>
      name.trim().isNotEmpty &&
      notificationTimes.isNotEmpty &&
      (endDate == null || !endDate!.isBefore(startDate));

  Medication copyWith({
    String? id,
    String? name,
    String? dosage,
    bool? isActive,
    MedicationRecurrenceType? recurrenceType,
    List<int>? daysOfWeek,
    int? intervalDays,
    DateTime? startDate,
    Object? endDate = _sentinel,
    List<MedicationTime>? notificationTimes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Medication(
    id: id ?? this.id,
    name: name ?? this.name,
    dosage: dosage ?? this.dosage,
    isActive: isActive ?? this.isActive,
    recurrenceType: recurrenceType ?? this.recurrenceType,
    daysOfWeek: daysOfWeek ?? this.daysOfWeek,
    intervalDays: intervalDays ?? this.intervalDays,
    startDate: startDate ?? this.startDate,
    endDate: identical(endDate, _sentinel)
        ? this.endDate
        : endDate as DateTime?,
    notificationTimes: notificationTimes ?? this.notificationTimes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? DateTime.now(),
  );

  /// Check whether this medication is scheduled to be taken on [date].
  bool isScheduledForDate(DateTime date) {
    if (!isActive) return false;

    final targetDate = DateTime(date.year, date.month, date.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);

    if (targetDate.isBefore(start)) return false;

    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (targetDate.isAfter(end)) return false;
    }

    switch (recurrenceType) {
      case MedicationRecurrenceType.daily:
        return true;
      case MedicationRecurrenceType.specificDaysOfWeek:
        return daysOfWeek.contains(targetDate.weekday);
      case MedicationRecurrenceType.intervalDays:
        final diff = targetDate.difference(start).inDays;
        return diff >= 0 && (intervalDays > 0) && (diff % intervalDays == 0);
    }
  }

  /// Format date to YYYY-MM-DD
  static String dateToKey(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Generate deterministic dose ID for a medication at date and time.
  static String doseIdFor(
    String medicationId,
    DateTime date,
    MedicationTime time,
  ) {
    final key = dateToKey(date);
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '${medicationId}_${key}_$h$m';
  }

  /// Generate dose instances for a given date, optionally merged with recorded user actions.
  List<DoseInstance> generateDosesForDate(
    DateTime date, {
    Map<String, DoseRecord>? doseRecords,
  }) {
    if (!isScheduledForDate(date)) return [];

    final normalizedDate = DateTime(date.year, date.month, date.day);
    final results = <DoseInstance>[];

    for (final time in notificationTimes) {
      final doseId = doseIdFor(id, normalizedDate, time);
      final record = doseRecords?[doseId];

      results.add(
        DoseInstance(
          id: doseId,
          medicationId: id,
          medicationName: name,
          dosage: dosage,
          scheduledDate: normalizedDate,
          time: time,
          slot: time.slot,
          status: record?.status ?? DoseStatus.pending,
          actionTime: record?.timestamp,
        ),
      );
    }

    return results;
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'dosage': dosage,
    'isActive': isActive,
    'recurrenceType': recurrenceType.name,
    'daysOfWeek': daysOfWeek,
    'intervalDays': intervalDays,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'notificationTimes': notificationTimes.map((t) => t.toMap()).toList(),
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory Medication.fromMap(Map<String, dynamic> map) {
    return Medication(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      dosage: map['dosage'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      recurrenceType: MedicationRecurrenceType.values.firstWhere(
        (e) => e.name == map['recurrenceType'],
        orElse: () => MedicationRecurrenceType.daily,
      ),
      daysOfWeek:
          (map['daysOfWeek'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          const [1, 2, 3, 4, 5, 6, 7],
      intervalDays: (map['intervalDays'] as num?)?.toInt() ?? 1,
      startDate:
          DateTime.tryParse(map['startDate'] as String? ?? '') ??
          DateTime.now(),
      endDate: map['endDate'] != null
          ? DateTime.tryParse(map['endDate'] as String)
          : null,
      notificationTimes:
          (map['notificationTimes'] as List<dynamic>?)
              ?.map((t) => MedicationTime.fromMap(Map<String, dynamic>.from(t)))
              .toList() ??
          const [],
      createdAt:
          DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      updatedAt:
          DateTime.tryParse(map['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory Medication.fromJson(String source) =>
      Medication.fromMap(json.decode(source));

  @override
  List<Object?> get props => [
    id,
    name,
    dosage,
    isActive,
    recurrenceType,
    daysOfWeek,
    intervalDays,
    startDate,
    endDate,
    notificationTimes,
    createdAt,
    updatedAt,
  ];
}
