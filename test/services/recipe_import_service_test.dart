import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/services/recipe_import_service.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('RecipeImportService', () {
    test('isRecipeUrl validates http/https URLs accurately', () {
      expect(
        RecipeImportService.isRecipeUrl(
          'https://www.ah.nl/allerhande/recept/R-R1193374/lasagne-met-bechamelsaus',
        ),
        isTrue,
      );
      expect(
        RecipeImportService.isRecipeUrl(
          'https://www.jumbo.com/recepten/hutspot-met-rookworst-999615',
        ),
        isTrue,
      );
      expect(RecipeImportService.isRecipeUrl('2 pakken melk'), isFalse);
      expect(
        RecipeImportService.isRecipeUrl('this-is-supposed-to-be-not-a-valid-url'),
        isFalse,
      );
    });

    test('deriveSourceName maps Dutch supermarkets and chef blogs', () {
      expect(
        RecipeImportService.deriveSourceName(
          'https://www.ah.nl/allerhande/recept/R-R1193374/lasagne-met-bechamelsaus',
        ),
        'Albert Heijn',
      );
      expect(
        RecipeImportService.deriveSourceName(
          'https://www.jumbo.com/recepten/hutspot-met-rookworst-999615',
        ),
        'Jumbo',
      );
      expect(
        RecipeImportService.deriveSourceName(
          'https://rutgerbakt.nl/taart-recepten/appeltaart/recept-de-lekkerste-appeltaart/',
        ),
        'rutgerbakt.nl',
      );
    });

    test('parses Albert Heijn style JSON-LD Recipe', () async {
      const html = '''
      <html>
        <head>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@type": "Recipe",
            "name": "Romige Pasta Pesto",
            "recipeYield": "4 personen",
            "image": "https://static.ah.nl/pasta.jpg",
            "recipeIngredient": [
              "300 g penne",
              "2 el groene pesto",
              "250 g cherrytomaten"
            ]
          }
          </script>
        </head>
        <body></body>
      </html>
      ''';

      final service = RecipeImportService(
        client: MockClient((_) async => http.Response(html, 200)),
      );

      final recipe = await service.fetchAndParse(
        'https://www.ah.nl/allerhande/recept/R-R1193374/lasagne-met-bechamelsaus',
      );

      expect(recipe.title, 'Romige Pasta Pesto');
      expect(recipe.sourceName, 'Albert Heijn');
      expect(recipe.servings, 4);
      expect(recipe.imageUrl, 'https://static.ah.nl/pasta.jpg');
      expect(recipe.ingredients.length, 3);
      expect(recipe.ingredients[0].name, 'Penne');
      expect(recipe.ingredients[0].quantity, 300);
      expect(recipe.ingredients[0].unit, 'g');
    });

    test('parses @graph JSON-LD Recipe (Jumbo / WordPress Yoast style)',
        () async {
      const html = '''
      <html>
        <head>
          <script type="application/ld+json">
          {
            "@context": "https://schema.org",
            "@graph": [
              { "@type": "WebPage", "name": "Blog" },
              {
                "@type": "Recipe",
                "name": "Klassieke Appeltaart",
                "recipeYield": ["8 stukken"],
                "recipeIngredient": [
                  "400 g zelfrijzend bakmeel",
                  "200 g roomboter"
                ]
              }
            ]
          }
          </script>
        </head>
        <body></body>
      </html>
      ''';

      final service = RecipeImportService(
        client: MockClient((_) async => http.Response(html, 200)),
      );

      final recipe = await service.fetchAndParse(
        'https://www.jumbo.com/recepten/hutspot-met-rookworst-999615',
      );

      expect(recipe.title, 'Klassieke Appeltaart');
      expect(recipe.sourceName, 'Jumbo');
      expect(recipe.servings, 8);
      expect(recipe.ingredients.length, 2);
      expect(recipe.ingredients[1].name, 'Roomboter');
    });

    test('falls back to Microdata when JSON-LD is missing', () async {
      const html = '''
      <html>
        <head><title>Bananenbrood</title></head>
        <body>
          <div itemscope itemtype="http://schema.org/Recipe">
            <h1 itemprop="name">Snel Bananenbrood</h1>
            <ul>
              <li itemprop="recipeIngredient">3 rijpe bananen</li>
              <li itemprop="recipeIngredient">150 g havermout</li>
            </ul>
          </div>
        </body>
      </html>
      ''';

      final service = RecipeImportService(
        client: MockClient((_) async => http.Response(html, 200)),
      );

      final recipe = await service.fetchAndParse(
        'https://rutgerbakt.nl/taart-recepten/appeltaart/recept-de-lekkerste-appeltaart/',
      );

      expect(recipe.title, 'Snel Bananenbrood');
      expect(recipe.sourceName, 'rutgerbakt.nl');
      expect(recipe.ingredients.length, 2);
    });

    test('throws RecipeParseException when no ingredients are found', () async {
      const html = '<html><body><h1>Empty Page</h1></body></html>';
      final service = RecipeImportService(
        client: MockClient((_) async => http.Response(html, 200)),
      );

      expect(
        () => service.fetchAndParse(
          'https://this-is-supposed-to-be-not-a-valid-url.example/no-recipe',
        ),
        throwsA(isA<RecipeParseException>()),
      );
    });

    test('throws RecipeFetchException on HTTP 403/404', () async {
      final service = RecipeImportService(
        client: MockClient((_) async => http.Response('Forbidden', 403)),
      );

      expect(
        () => service.fetchAndParse(
          'https://this-is-supposed-to-be-not-a-valid-url.example/blocked',
        ),
        throwsA(isA<RecipeFetchException>()),
      );
    });
  });
}
