import 'dart:convert';

import 'package:equatable/equatable.dart';

class ShoppingItem extends Equatable {
  final String id;
  final String name;
  final String? note;
  final int quantity;
  final String? category;
  final bool inCart;

  const ShoppingItem({
    required this.id,
    required this.name,
    this.note,
    this.quantity = 1,
    this.category,
    this.inCart = false,
  });

  ShoppingItem copyWith({
    String? id,
    String? name,
    String? note,
    int? quantity,
    String? category,
    bool? inCart,
  }) => ShoppingItem(
    id: id ?? this.id,
    name: name ?? this.name,
    note: note ?? this.note,
    quantity: quantity ?? this.quantity,
    category: category ?? this.category,
    inCart: inCart ?? this.inCart,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name,
    'note': note,
    'quantity': quantity,
    'category': category,
    'inCart': inCart,
  };

  factory ShoppingItem.fromMap(Map<String, dynamic> map) => ShoppingItem(
    id: map['id'] as String,
    name: map['name'] as String,
    note: map['note'] as String?,
    quantity: map['quantity'] as int? ?? 1,
    category: map['category'] as String?,
    inCart: map['inCart'] as bool? ?? false,
  );

  String toJson() => json.encode(toMap());

  factory ShoppingItem.fromJson(String source) =>
      ShoppingItem.fromMap(json.decode(source));

  @override
  List<Object?> get props => [id, name, note, quantity, category, inCart];
}
