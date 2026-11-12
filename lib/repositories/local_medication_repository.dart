import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/medication.dart';

/// Summary of doses in a day grouped into daytime (Sun ☀️) and evening (Moon 🌙) slots,
/// matching the Android 2x2 widget state requirements.
class WidgetDoseSummary {
  final DateTime date;
  final List<DoseInstance> morningDoses;
  final List<DoseInstance> eveningDoses;

  const WidgetDoseSummary({
    required this.date,
    required this.morningDoses,
    required this.eveningDoses,
  });

  bool get hasMorningDoses => morningDoses.isNotEmpty;
  bool get hasEveningDoses => eveningDoses.isNotEmpty;

  /// True if there is at least one dose and ALL doses in the slot are taken.
  bool get isMorningTaken =>
      hasMorningDoses && morningDoses.every((d) => d.isTaken);

  /// True if there is at least one dose and ALL doses in the slot are taken.
  bool get isEveningTaken =>
      hasEveningDoses && eveningDoses.every((d) => d.isTaken);

  List<DoseInstance> get allDoses => [...morningDoses, ...eveningDoses];
}

/// Local-only repository for personal medications and dose tracking.
///
/// Operates strictly within local storage (SharedPreferences) to guarantee that
/// medication data is never shared with a household or synced to Firestore.
class LocalMedicationRepository {
  static const String _kMedicationsKey = 'personal_medications_list';
  static const String _kDoseRecordsKey = 'personal_dose_records_map';

  final SharedPreferences? _prefs;

  LocalMedicationRepository({SharedPreferences? prefs}) : _prefs = prefs;

  Future<SharedPreferences> get _preferences async =>
      _prefs ?? await SharedPreferences.getInstance();

  /// Retrieve all personal medications.
  Future<List<Medication>> getMedications() async {
    final prefs = await _preferences;
    final jsonStr = prefs.getString(_kMedicationsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return [];
    }

    try {
      final List<dynamic> list = json.decode(jsonStr);
      return list
          .map((item) => Medication.fromMap(Map<String, dynamic>.from(item)))
          .toList()
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } catch (e) {
      debugPrint('LocalMedicationRepository.getMedications error: $e');
      return [];
    }
  }

  /// Get a single medication by ID.
  Future<Medication?> getMedication(String id) async {
    final list = await getMedications();
    try {
      return list.firstWhere((m) => m.id == id);
    } catch (_) {
      return null;
    }
  }

  /// Save or update a medication.
  Future<void> saveMedication(Medication medication) async {
    final list = await getMedications();
    final index = list.indexWhere((m) => m.id == medication.id);

    final updated = List<Medication>.from(list);
    if (index >= 0) {
      updated[index] = medication;
    } else {
      updated.add(medication);
    }

    await _saveMedicationsList(updated);
  }

  /// Delete a medication by ID.
  Future<void> deleteMedication(String id) async {
    final list = await getMedications();
    final updated = list.where((m) => m.id != id).toList();
    await _saveMedicationsList(updated);
  }

  /// Set the active status of a medication.
  Future<void> setMedicationActive(String id, bool isActive) async {
    final med = await getMedication(id);
    if (med != null) {
      await saveMedication(med.copyWith(isActive: isActive));
    }
  }

  /// Retrieve dose records, optionally filtered by date key (YYYY-MM-DD).
  Future<Map<String, DoseRecord>> getDoseRecords({String? dateKey}) async {
    final prefs = await _preferences;
    final jsonStr = prefs.getString(_kDoseRecordsKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      return {};
    }

    try {
      final Map<String, dynamic> rawMap = json.decode(jsonStr);
      final records = <String, DoseRecord>{};
      for (final entry in rawMap.entries) {
        final record = DoseRecord.fromMap(
          Map<String, dynamic>.from(entry.value),
        );
        if (dateKey == null || record.dateKey == dateKey) {
          records[entry.key] = record;
        }
      }
      return records;
    } catch (e) {
      debugPrint('LocalMedicationRepository.getDoseRecords error: $e');
      return {};
    }
  }

  /// Record or clear a dose status.
  Future<void> recordDoseStatus({
    required String doseId,
    required String medicationId,
    required String dateKey,
    required DoseStatus status,
  }) async {
    final prefs = await _preferences;
    final jsonStr = prefs.getString(_kDoseRecordsKey);
    final Map<String, dynamic> rawMap = jsonStr != null && jsonStr.isNotEmpty
        ? json.decode(jsonStr)
        : {};

    if (status == DoseStatus.pending) {
      // Removing the record treats it as pending (default state)
      rawMap.remove(doseId);
    } else {
      final record = DoseRecord(
        doseId: doseId,
        medicationId: medicationId,
        dateKey: dateKey,
        status: status,
        timestamp: DateTime.now(),
      );
      rawMap[doseId] = record.toMap();
    }

    await prefs.setString(_kDoseRecordsKey, json.encode(rawMap));
  }

  /// Materialize all scheduled doses for a given date, merged with user action states.
  Future<List<DoseInstance>> getDosesForDate(DateTime date) async {
    final dateKey = Medication.dateToKey(date);
    final medications = await getMedications();
    final records = await getDoseRecords(dateKey: dateKey);

    final doses = <DoseInstance>[];
    for (final med in medications) {
      doses.addAll(med.generateDosesForDate(date, doseRecords: records));
    }

    // Sort by time (hour, then minute), then name
    doses.sort((a, b) {
      final hourCmp = a.time.hour.compareTo(b.time.hour);
      if (hourCmp != 0) return hourCmp;
      final minCmp = a.time.minute.compareTo(b.time.minute);
      if (minCmp != 0) return minCmp;
      return a.medicationName.compareTo(b.medicationName);
    });

    return doses;
  }

  /// Get the daytime (Sun ☀️) vs evening (Moon 🌙) summary for the widget and tool UI.
  Future<WidgetDoseSummary> getWidgetSummary(DateTime date) async {
    final doses = await getDosesForDate(date);
    final morning = doses
        .where((d) => d.slot == TimeOfDaySlot.morning)
        .toList();
    final evening = doses
        .where((d) => d.slot == TimeOfDaySlot.evening)
        .toList();

    return WidgetDoseSummary(
      date: date,
      morningDoses: morning,
      eveningDoses: evening,
    );
  }

  /// Update the status of all doses in a specific slot (Morning/Sun or Evening/Moon) for a date.
  /// Used directly by widget toggle switches.
  Future<void> setSlotDosesStatus({
    required DateTime date,
    required TimeOfDaySlot slot,
    required DoseStatus status,
  }) async {
    final doses = await getDosesForDate(date);
    final slotDoses = doses.where((d) => d.slot == slot).toList();
    final dateKey = Medication.dateToKey(date);

    for (final dose in slotDoses) {
      await recordDoseStatus(
        doseId: dose.id,
        medicationId: dose.medicationId,
        dateKey: dateKey,
        status: status,
      );
    }
  }

  /// Toggle an individual dose between taken and pending (or set explicit status).
  Future<void> toggleDoseStatus(DoseInstance dose) async {
    final nextStatus = dose.isTaken ? DoseStatus.pending : DoseStatus.taken;
    await recordDoseStatus(
      doseId: dose.id,
      medicationId: dose.medicationId,
      dateKey: Medication.dateToKey(dose.scheduledDate),
      status: nextStatus,
    );
  }

  /// Clear all medication data (for testing / reset).
  Future<void> clearAll() async {
    final prefs = await _preferences;
    await prefs.remove(_kMedicationsKey);
    await prefs.remove(_kDoseRecordsKey);
  }

  Future<void> _saveMedicationsList(List<Medication> list) async {
    final prefs = await _preferences;
    final jsonList = list.map((m) => m.toMap()).toList();
    await prefs.setString(_kMedicationsKey, json.encode(jsonList));
  }
}
