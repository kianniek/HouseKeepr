part of 'shopping_cubit.dart';

class ShoppingState extends Equatable {
  final List<GroceryItem> items;
  final bool aisleModeEnabled;
  final bool flatViewEnabled;
  final bool isLoading;
  final String? error;
  final GroceryCategory selectedCategory;
  final bool manualCategoryOverride;
  final String manualOverrideText;
  final String? suggestedText;
  final double suggestionConfidence;

  const ShoppingState({
    this.items = const [],
    this.aisleModeEnabled = false,
    this.flatViewEnabled = false,
    this.isLoading = false,
    this.error,
    this.selectedCategory = GroceryCategory.other,
    this.manualCategoryOverride = false,
    this.manualOverrideText = '',
    this.suggestedText,
    this.suggestionConfidence = 0.0,
  });

  factory ShoppingState.initial() => const ShoppingState();

  ShoppingState copyWith({
    List<GroceryItem>? items,
    bool? aisleModeEnabled,
    bool? flatViewEnabled,
    bool? isLoading,
    String? error,
    GroceryCategory? selectedCategory,
    bool? manualCategoryOverride,
    String? manualOverrideText,
    String? suggestedText,
    double? suggestionConfidence,
  }) => ShoppingState(
    items: items ?? this.items,
    aisleModeEnabled: aisleModeEnabled ?? this.aisleModeEnabled,
    flatViewEnabled: flatViewEnabled ?? this.flatViewEnabled,
    isLoading: isLoading ?? this.isLoading,
    error: error ?? this.error,
    selectedCategory: selectedCategory ?? this.selectedCategory,
    manualCategoryOverride:
        manualCategoryOverride ?? this.manualCategoryOverride,
    manualOverrideText: manualOverrideText ?? this.manualOverrideText,
    suggestedText: suggestedText ?? this.suggestedText,
    suggestionConfidence: suggestionConfidence ?? this.suggestionConfidence,
  );

  @override
  List<Object?> get props => [
    items,
    aisleModeEnabled,
    flatViewEnabled,
    isLoading,
    error,
    selectedCategory,
    manualCategoryOverride,
    manualOverrideText,
    suggestedText,
    suggestionConfidence,
  ];
}
