import 'package:equatable/equatable.dart';

class PingPreferences extends Equatable {
  final bool ghostMode;
  final DateTime? ghostModeUntil;
  final List<String> autoApproveList;

  const PingPreferences({
    this.ghostMode = false,
    this.ghostModeUntil,
    this.autoApproveList = const [],
  });

  PingPreferences copyWith({
    bool? ghostMode,
    DateTime? ghostModeUntil,
    List<String>? autoApproveList,
  }) {
    return PingPreferences(
      ghostMode: ghostMode ?? this.ghostMode,
      ghostModeUntil: ghostModeUntil ?? this.ghostModeUntil,
      autoApproveList: autoApproveList ?? this.autoApproveList,
    );
  }

  factory PingPreferences.fromMap(Map<String, dynamic> map) {
    DateTime? parseTime(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      // Assume Firestore Timestamp has toDate()
      try {
        return value.toDate();
      } catch (_) {
        if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
        if (value is String) return DateTime.tryParse(value);
      }
      return null;
    }

    return PingPreferences(
      ghostMode: map['ghostMode'] ?? false,
      ghostModeUntil: parseTime(map['ghostModeUntil']),
      autoApproveList: List<String>.from(map['autoApproveList'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ghostMode': ghostMode,
      if (ghostModeUntil != null)
        'ghostModeUntil': ghostModeUntil, // Needs Timestamp conversion usually
      'autoApproveList': autoApproveList,
    };
  }

  @override
  List<Object?> get props => [ghostMode, ghostModeUntil, autoApproveList];
}
