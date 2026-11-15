import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/generated/app_localizations.dart';
import 'package:housekeepr/models/grocery_category.dart';
import 'package:housekeepr/models/grocery_item.dart';
import 'package:housekeepr/ui/features/shopping/widgets/recipe_shopping_list_tile.dart';

void main() {
  testWidgets('RecipeShoppingListTile displays recipe, progress, and toggles expand',
      (tester) async {
    final now = DateTime(2026, 1, 1);
    final recipe = GroceryItem(
      id: 'rec-1',
      name: 'Spaghetti Carbonara',
      createdAt: now,
      isRecipe: true,
      recipeSource: 'Albert Heijn',
      recipeServings: 4,
      recipeUrl: 'https://www.ah.nl/allerhande/recept/R-R1/carbonara',
    );
    final ingredients = [
      GroceryItem(
        id: 'ing-1',
        name: 'Spaghetti',
        quantity: 400,
        unit: 'g',
        category: GroceryCategory.international,
        createdAt: now,
        parentRecipeId: 'rec-1',
        checked: true,
      ),
      GroceryItem(
        id: 'ing-2',
        name: 'Eieren',
        quantity: 4,
        category: GroceryCategory.dairy,
        createdAt: now,
        parentRecipeId: 'rec-1',
        checked: false,
      ),
    ];

    var parentToggled = false;
    String? toggledIngredientId;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [
              RecipeShoppingListTile(
                recipe: recipe,
                ingredients: ingredients,
                aisleMode: false,
                onToggleRecipe: () => parentToggled = true,
                onDeleteRecipe: () {},
                onToggleIngredient: (ing) => toggledIngredientId = ing.id,
                onDeleteIngredient: (_) {},
                onIngredientQuantity: (_) {},
              ),
            ],
          ),
        ),
      ),
    );

    expect(find.text('Spaghetti Carbonara'), findsOneWidget);
    expect(find.text('Albert Heijn • 4 servings'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Spaghetti'), findsOneWidget);
    expect(find.text('Eieren'), findsOneWidget);

    // Tap an ingredient
    await tester.tap(find.text('Eieren'));
    expect(toggledIngredientId, 'ing-2');

    // Tap the recipe's leading check-all circle
    await tester.tap(find.byKey(const ValueKey('recipe_toggle_rec-1')));
    expect(parentToggled, isTrue);

    // Collapse by tapping recipe title
    await tester.tap(find.text('Spaghetti Carbonara'));
    await tester.pumpAndSettle();
    final crossFade = tester.widget<AnimatedCrossFade>(
      find.byType(AnimatedCrossFade),
    );
    expect(crossFade.crossFadeState, CrossFadeState.showSecond);
  });
}
