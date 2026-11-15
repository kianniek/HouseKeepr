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

  /// When the item was soft-deleted. Used for the 7-day "Recently Deleted"
  /// retention window. Null for active items (and legacy tombstones).
  final DateTime? deletedAt;

  /// Whether this item is a recipe parent container.
  final bool isRecipe;

  /// ID of the parent recipe [GroceryItem] when this item is a recipe ingredient.
  final String? parentRecipeId;

  /// Source URL for a recipe parent container.
  final String? recipeUrl;

  /// Friendly source/website name for a recipe (e.g. "Albert Heijn", "Jumbo").
  final String? recipeSource;

  /// Number of servings for a recipe parent container.
  final int? recipeServings;

  /// Optional thumbnail image URL for a recipe parent container.
  final String? recipeImageUrl;

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
    this.deletedAt,
    this.isRecipe = false,
    this.parentRecipeId,
    this.recipeUrl,
    this.recipeSource,
    this.recipeServings,
    this.recipeImageUrl,
  }) : updatedAt = updatedAt ?? createdAt;

  GroceryItem copyWith({
    String? id,
    String? name,
    Object? note = _sentinel,
    double? quantity,
    Object? unit = _sentinel,
    GroceryCategory? category,
    bool? checked,
    DateTime? createdAt,
    Object? checkedAt = _sentinel,
    DateTime? updatedAt,
    bool? isDeleted,
    int? serverVersion,
    Object? deletedAt = _sentinel,
    bool? isRecipe,
    Object? parentRecipeId = _sentinel,
    Object? recipeUrl = _sentinel,
    Object? recipeSource = _sentinel,
    Object? recipeServings = _sentinel,
    Object? recipeImageUrl = _sentinel,
  }) => GroceryItem(
    id: id ?? this.id,
    name: name ?? this.name,
    note: identical(note, _sentinel) ? this.note : note as String?,
    quantity: quantity ?? this.quantity,
    unit: identical(unit, _sentinel) ? this.unit : unit as String?,
    category: category ?? this.category,
    checked: checked ?? this.checked,
    createdAt: createdAt ?? this.createdAt,
    checkedAt: identical(checkedAt, _sentinel)
        ? this.checkedAt
        : checkedAt as DateTime?,
    updatedAt: updatedAt ?? this.updatedAt,
    isDeleted: isDeleted ?? this.isDeleted,
    serverVersion: serverVersion ?? this.serverVersion,
    deletedAt: identical(deletedAt, _sentinel)
        ? this.deletedAt
        : deletedAt as DateTime?,
    isRecipe: isRecipe ?? this.isRecipe,
    parentRecipeId: identical(parentRecipeId, _sentinel)
        ? this.parentRecipeId
        : parentRecipeId as String?,
    recipeUrl: identical(recipeUrl, _sentinel)
        ? this.recipeUrl
        : recipeUrl as String?,
    recipeSource: identical(recipeSource, _sentinel)
        ? this.recipeSource
        : recipeSource as String?,
    recipeServings: identical(recipeServings, _sentinel)
        ? this.recipeServings
        : recipeServings as int?,
    recipeImageUrl: identical(recipeImageUrl, _sentinel)
        ? this.recipeImageUrl
        : recipeImageUrl as String?,
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
    'deletedAt': deletedAt?.toIso8601String(),
    if (isRecipe) 'isRecipe': isRecipe,
    if (parentRecipeId != null) 'parentRecipeId': parentRecipeId,
    if (recipeUrl != null) 'recipeUrl': recipeUrl,
    if (recipeSource != null) 'recipeSource': recipeSource,
    if (recipeServings != null) 'recipeServings': recipeServings,
    if (recipeImageUrl != null) 'recipeImageUrl': recipeImageUrl,
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
    quantity: (map['quantity'] as num?)?.toDouble() ?? 1.0,
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
    deletedAt: _parseDate(map['deletedAt']),
    isRecipe: map['isRecipe'] as bool? ?? false,
    parentRecipeId: map['parentRecipeId'] as String?,
    recipeUrl: map['recipeUrl'] as String?,
    recipeSource: map['recipeSource'] as String?,
    recipeServings: (map['recipeServings'] as num?)?.toInt(),
    recipeImageUrl: map['recipeImageUrl'] as String?,
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
    unit,
    category,
    checked,
    createdAt,
    checkedAt,
    updatedAt,
    isDeleted,
    serverVersion,
    deletedAt,
    isRecipe,
    parentRecipeId,
    recipeUrl,
    recipeSource,
    recipeServings,
    recipeImageUrl,
  ];
}
