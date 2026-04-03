part of 'shopping_cubit.dart';

class ShoppingState extends Equatable {
  final List<ShoppingItem> items;

  const ShoppingState({this.items = const []});

  factory ShoppingState.initial() => const ShoppingState(items: []);

  ShoppingState copyWith({List<ShoppingItem>? items}) =>
      ShoppingState(items: items ?? this.items);

  @override
  List<Object?> get props => [items];
}
