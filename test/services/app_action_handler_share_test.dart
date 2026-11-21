import 'package:flutter_test/flutter_test.dart';
import 'package:housekeepr/services/app_action_handler.dart';

void main() {
  group('AppActionHandler Share Routing', () {
    test('extractFirstUrl finds URL inside shared prose and trims punctuation', () {
      const text =
          'Try this pasta tonight: https://www.ah.nl/allerhande/recept/R-R1192340). Enjoy!';
      expect(
        AppActionHandler.extractFirstUrl(text),
        'https://www.ah.nl/allerhande/recept/R-R1192340',
      );
      expect(AppActionHandler.extractFirstUrl('Just plain groceries'), isNull);
    });

    test('quick_add_shopping classifies URL as recipe import', () {
      final plan = AppActionHandler.classifyShareInput(
        text: 'https://www.seriouseats.com/classic-carbonara',
        shortcutId: 'quick_add_shopping',
      );
      expect(plan.action, ShareTargetAction.recipeUrl);
      expect(plan.extractedUrl, 'https://www.seriouseats.com/classic-carbonara');
    });

    test('quick_add_shopping classifies multi-line text as bulk import', () {
      final plan = AppActionHandler.classifyShareInput(
        text: '2L Milk\nEggs\nSourdough bread\n',
        shortcutId: 'quick_add_shopping',
      );
      expect(plan.action, ShareTargetAction.shoppingBulk);
      expect(plan.lines, ['2L Milk', 'Eggs', 'Sourdough bread']);
    });

    test('quick_add_shopping classifies single line as quick-add item', () {
      final plan = AppActionHandler.classifyShareInput(
        text: 'Oat milk',
        shortcutId: 'quick_add_shopping',
      );
      expect(plan.action, ShareTargetAction.shoppingSingle);
      expect(plan.lines, ['Oat milk']);
    });

    test('quick_add_task extracts subject and body into task title & description', () {
      final withSubject = AppActionHandler.classifyShareInput(
        text: 'https://example.com/plumber',
        subject: 'Call plumber',
        shortcutId: 'quick_add_task',
      );
      expect(withSubject.action, ShareTargetAction.createTask);
      expect(withSubject.taskTitle, 'Call plumber');
      expect(withSubject.taskDescription, 'https://example.com/plumber');

      final multiLineNoSubject = AppActionHandler.classifyShareInput(
        text: 'Pay utility bill\nCheck meter reading first',
        shortcutId: 'quick_add_task',
      );
      expect(multiLineNoSubject.action, ShareTargetAction.createTask);
      expect(multiLineNoSubject.taskTitle, 'Pay utility bill');
      expect(multiLineNoSubject.taskDescription, 'Check meter reading first');
    });

    test('untargeted share asks user while pre-computing URL and lines', () {
      final plan = AppActionHandler.classifyShareInput(
        text: 'Check out https://www.jumbo.com/recepten/123',
        shortcutId: null,
      );
      expect(plan.action, ShareTargetAction.askUser);
      expect(plan.extractedUrl, 'https://www.jumbo.com/recepten/123');
    });
  });
}
