import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:housekeepr/models/coffee_recipe.dart';

class CoffeeFirebaseService {
  final FirebaseFirestore firestore;
  final String householdId;

  CoffeeFirebaseService({
    required this.householdId,
    FirebaseFirestore? firestore,
  }) : firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _col => firestore
      .collection('households')
      .doc(householdId)
      .collection('coffee_recipes');

  Future<void> seedDefaultRecipes() async {
    try {
      debugPrint(
        'CoffeeFirebaseService: Seeding default recipes for household $householdId',
      );
      for (final recipe in CoffeeRegistry.recipes) {
        await saveRecipe(recipe);
      }
    } catch (error) {
      debugPrint('CoffeeFirebaseService.seedDefaultRecipes failed: $error');
      rethrow;
    }
  }

  Future<List<CoffeeRecipe>> getCustomRecipes() async {
    try {
      debugPrint(
        'CoffeeFirebaseService.getCustomRecipes: '
        'households/$householdId/coffee_recipes',
      );
      final snapshot = await _col.get();
      return snapshot.docs
          .map((doc) => CoffeeRecipe.fromMap(doc.data(), doc.id))
          .where((recipe) => recipe.id.isNotEmpty && recipe.layers.isNotEmpty)
          .toList();
    } catch (error) {
      debugPrint('CoffeeFirebaseService.getCustomRecipes failed: $error');
      rethrow;
    }
  }

  Future<void> saveRecipe(CoffeeRecipe recipe) async {
    final data = Map<String, dynamic>.from(recipe.toMap());
    data['serverUpdateTimestamp'] = FieldValue.serverTimestamp();
    final id = recipe.id;
    try {
      debugPrint(
        'CoffeeFirebaseService.saveRecipe: '
        'households/$householdId/coffee_recipes/$id',
      );
      await _col.doc(id).set(data, SetOptions(merge: true));
    } catch (error) {
      debugPrint('CoffeeFirebaseService.saveRecipe failed: $error');
      rethrow;
    }
  }

  Future<void> deleteRecipe(String recipeId) async {
    try {
      debugPrint(
        'CoffeeFirebaseService.deleteRecipe: '
        'households/$householdId/coffee_recipes/$recipeId',
      );
      await _col.doc(recipeId).delete();
    } catch (error) {
      debugPrint('CoffeeFirebaseService.deleteRecipe failed: $error');
      rethrow;
    }
  }
}
