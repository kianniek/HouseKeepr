import '../models/shopping_item.dart';

/// Interface to abstract remote shopping persistence for testing.
abstract class RemoteShoppingRepository {
  Future<void> saveItem(ShoppingItem item);
  Future<void> deleteItem(String id);
}
