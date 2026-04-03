import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'grocery_category.dart';

class GroceryItem extends Equatable {
  final String id;
  final String name;
  final String? note;
  final int quantity;
  final GroceryCategory category;
  final bool checked;
  final DateTime createdAt;
  final DateTime? checkedAt;
  final int? serverVersion;

  const GroceryItem({
    required this.id,
    required this.name,
    this.note,
    this.quantity = 1,
    this.category = GroceryCategory.other,
    this.checked = false,
    required this.createdAt,
    this.checkedAt,
    this.serverVersion,
  });

  GroceryItem copyWith({
    String? id,
    String? name,
    String? note,
    int? quantity,
    GroceryCategory? category,
    bool? checked,
    DateTime? createdAt,
    DateTime? checkedAt,
    int? serverVersion,
  }) => GroceryItem(
    id: id ?? this.id,
    name: name ?? this.name,
    note: note ?? this.note,
    quantity: quantity ?? this.quantity,
    category: category ?? this.category,
    checked: checked ?? this.checked,
    createdAt: createdAt ?? this.createdAt,
    checkedAt: checkedAt ?? this.checkedAt,
    serverVersion: serverVersion ?? this.serverVersion,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'note': note,
    'quantity': quantity,
    'category': category.name,
    'checked': checked,
    'createdAt': createdAt.toIso8601String(),
    'checkedAt': checkedAt?.toIso8601String(),
    'serverVersion': serverVersion,
  };

  factory GroceryItem.fromMap(Map<String, dynamic> map) => GroceryItem(
    id: map['id'] as String? ?? '',
    name: map['name'] as String? ?? '',
    note: map['note'] as String?,
    quantity: map['quantity'] as int? ?? 1,
    category: GroceryCategory.fromString(map['category'] as String?),
    checked: map['checked'] as bool? ?? false,
    createdAt:
        DateTime.tryParse(map['createdAt'] as String? ?? '') ?? DateTime.now(),
    checkedAt: DateTime.tryParse(map['checkedAt'] as String? ?? ''),
    serverVersion: map['serverVersion'] as int?,
  );

  String toJson() => json.encode(toMap());

  factory GroceryItem.fromJson(String source) =>
      GroceryItem.fromMap(json.decode(source) as Map<String, dynamic>);

  @override
  List<Object?> get props => [id, name, quantity, category, checked, createdAt];
}
