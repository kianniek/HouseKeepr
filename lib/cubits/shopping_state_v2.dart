part of 'shopping_cubit_v2.dart';

class ShoppingState extends Equatable {
  final List<GroceryItem> items;
  final bool aisleModeEnabled;
  final bool flatViewEnabled;
  final bool isLoading;
  final String? error;

  const ShoppingState({
    this.items = const [],
    this.aisleModeEnabled = false,
    this.flatViewEnabled = false,
    this.isLoading = false,
    this.error,
  });

  factory ShoppingState.initial() => const ShoppingState();

  ShoppingState copyWith({
    List<GroceryItem>? items,
    bool? aisleModeEnabled,
    bool? flatViewEnabled,
    bool? isLoading,
    String? error,
  }) => ShoppingState(
    items: items ?? this.items,
    aisleModeEnabled: aisleModeEnabled ?? this.aisleModeEnabled,
    flatViewEnabled: flatViewEnabled ?? this.flatViewEnabled,
    isLoading: isLoading ?? this.isLoading,
    error: error ?? this.error,
  );

  @override
  List<Object?> get props => [
    items,
    aisleModeEnabled,
    flatViewEnabled,
    isLoading,
    error,
  ];
}
