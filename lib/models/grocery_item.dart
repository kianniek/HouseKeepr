import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'grocery_category.dart';

class GroceryItem extends Equatable {
  static const Object _sentinel = Object();

  final String id;
  final String name;
  final String? note;
  final double quantity;
  final String? unit;
  final GroceryCategory category;
  final bool checked;
  final DateTime createdAt;
  final DateTime? checkedAt;
  final DateTime updatedAt;
  final bool isDeleted;
  final int? serverVersion;

  const GroceryItem({
    required this.id,
    required this.name,
    this.note,
    this.quantity = 1.0,
    this.unit,
    this.category = GroceryCategory.other,
    this.checked = false,
    required this.createdAt,
    this.checkedAt,
    DateTime? updatedAt,
    this.isDeleted = false,
    this.serverVersion,
  }) : updatedAt = updatedAt ?? createdAt;

  GroceryItem copyWith({
    String? id,
    String? name,
    Object? note = _sentinel,
    double? quantity,
    String? unit,
    GroceryCategory? category,
    bool? checked,
    DateTime? createdAt,
    Object? checkedAt = _sentinel,
    DateTime? updatedAt,
    bool? isDeleted,
    int? serverVersion,
  }) => GroceryItem(
    id: id ?? this.id,
    name: name ?? this.name,
    note: identical(note, _sentinel) ? this.note : note as String?,
    quantity: quantity ?? this.quantity,
    unit: unit ?? this.unit,
    category: category ?? this.category,
    checked: checked ?? this.checked,
    createdAt: createdAt ?? this.createdAt,
    checkedAt: identical(checkedAt, _sentinel)
        ? this.checkedAt
        : checkedAt as DateTime?,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    serverVersion: serverVersion ?? this.serverVersion,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'note': note,
    'quantity': quantity,
    'unit': unit,
    'category': category.name,
    'checked': checked,
    'createdAt': createdAt.toIso8601String(),
    'checkedAt': checkedAt?.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'isDeleted': isDeleted,
    'serverVersion': serverVersion,
  };

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw;
    if (raw is String) return DateTime.tryParse(raw);
    if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
    return null;
  }

  factory GroceryItem.fromMap(Map<String, dynamic> map) => GroceryItem(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    note: map['note'] as String?,
    quantity: map['quantity'] as double? ?? 1.0,
    unit: map['unit'] as String?,
    category: GroceryCategory.fromString(map['category'] as String?),
    checked: map['checked'] as bool? ?? false,
    createdAt: _parseDate(map['createdAt']) ?? DateTime.now(),
    checkedAt: _parseDate(map['checkedAt']),
    updatedAt:
        _parseDate(map['updatedAt']) ??
        _parseDate(map['createdAt']) ??
        _parseDate(map['serverVersion']) ??
        DateTime.now(),
    isDeleted: map['isDeleted'] as bool? ?? false,
    serverVersion: map['serverVersion'] as int?,
  );

  String toJson() => json.encode(toMap());

  factory GroceryItem.fromJson(String source) =>
      GroceryItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  List<Object?> get props => [
    id,
    name,
    note,
    quantity,
    category,
    checked,
    createdAt,
    checkedAt,
    updatedAt,
    isDeleted,
    serverVersion,
  ];
}
