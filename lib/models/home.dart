import 'dart:convert';

import 'package:equatable/equatable.dart';

class Home extends Equatable {
  final String id;
  final String name;
  final String createdBy;
  final List<String> members;
  final String? inviteCode;
  final DateTime createdAt;

  Home({
    required this.id,
    required this.name,
    required this.createdBy,
    this.members = const [],
    this.inviteCode,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Home copyWith({
    String? id,
    String? name,
    String? createdBy,
    List<String>? members,
    String? inviteCode,
    DateTime? createdAt,
  }) => Home(
    id: id ?? this.id,
    name: name ?? this.name,
    createdBy: createdBy ?? this.createdBy,
    members: members ?? this.members,
    inviteCode: inviteCode ?? this.inviteCode,
    createdAt: createdAt ?? this.createdAt,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'createdBy': createdBy,
    'members': members,
    'inviteCode': inviteCode,
    'createdAt': createdAt.toUtc().toIso8601String(),
  };

  factory Home.fromMap(Map<String, dynamic> map) => Home(
    id: (map['id'] is String)
        ? map['id'] as String
        : (map['id']?.toString() ?? ''),
    name: (map['name'] is String)
        ? map['name'] as String
        : (map['name']?.toString() ?? ''),
    createdBy: (map['createdBy'] is String)
        ? map['createdBy'] as String
        : (map['createdBy']?.toString() ?? ''),
    members: (map['members'] is List)
        ? (map['members'] as List)
              .map((e) => e?.toString() ?? '')
              .where((s) => s.isNotEmpty)
              .toList()
        : [],
    inviteCode: map['inviteCode'] is String
        ? map['inviteCode'] as String
        : (map['inviteCode']?.toString()),
    createdAt: () {
      final v = map['createdAt'];
      if (v is DateTime) return v;
      if (v is String) {
        try {
          return DateTime.parse(v).toUtc();
        } catch (_) {
          return DateTime.now().toUtc();
        }
      }
      return DateTime.now().toUtc();
    }(),
  );

  String toJson() => json.encode(toMap());

  factory Home.fromJson(String source) => Home.fromMap(json.decode(source));

  @override
  List<Object?> get props => [
    id,
    name,
    createdBy,
    members,
    inviteCode,
    createdAt,
  ];
}
