import 'package:flutter/material.dart';

import '../ai/nutrition_estimator.dart';
import '../ml/nutrition_mapper.dart';

/// Shared helper that populates empty nutrition [TextEditingController]s
/// from a [NutritionEstimator] without overwriting user-entered values.
class NutritionAutoFillHelper {
  NutritionAutoFillHelper._();

  static String formatNumber(double value) {
    if (!value.isFinite) return '0';
    if ((value - value.roundToDouble()).abs() < 0.05) {
      return value.round().toString();
    }
    return value.toStringAsFixed(1);
  }

  static double? parsePositive(String raw) {
    final parsed = double.tryParse(raw.trim().replaceAll(',', '.'));
    if (parsed == null || !parsed.isFinite || parsed <= 0) return null;
    return parsed;
  }

  /// Runs [estimator] for [nameController.text] and optional [gramsController.text].
  ///
  /// Only fills fields that are currently empty (`trim().isEmpty`).
  static Future<NutritionEstimate?> fillEmptyFields({
    required NutritionEstimator estimator,
    required TextEditingController nameController,
    required TextEditingController gramsController,
    required TextEditingController kcalController,
    required TextEditingController proteinController,
    required TextEditingController carbsController,
    required TextEditingController fatController,
  }) async {
    final foodName = nameController.text.trim();
    if (foodName.isEmpty) return null;

    final requestedGrams = parsePositive(gramsController.text);
    final estimate = await estimator.estimate(
      foodName: foodName,
      servingGrams: requestedGrams,
    );
    if (estimate == null) return null;

    if (estimate.cleanedTitle != null &&
        estimate.cleanedTitle!.trim().isNotEmpty) {
      nameController.text = estimate.cleanedTitle!.trim();
    }
    if (gramsController.text.trim().isEmpty) {
      gramsController.text = formatNumber(estimate.servingGrams);
    }
    if (kcalController.text.trim().isEmpty) {
      kcalController.text = formatNumber(estimate.kcal);
    }
    if (proteinController.text.trim().isEmpty) {
      proteinController.text = formatNumber(estimate.proteinGrams);
    }
    if (carbsController.text.trim().isEmpty) {
      carbsController.text = formatNumber(estimate.carbsGrams);
    }
    if (fatController.text.trim().isEmpty) {
      fatController.text = formatNumber(estimate.fatGrams);
    }

    return estimate;
  }

  static String badgeLabel(NutritionEstimate estimate) {
    if (estimate.source == NutritionEstimateSource.onDeviceLlm) {
      return 'On-Device AI';
    }
    final name = estimate.matchedFoodName ?? estimate.matchedFood?.name;
    if (estimate.matchKind == NutritionMatchKind.fallback) {
      return name != null && name.isNotEmpty
          ? 'Fallback: "$name"'
          : 'Generic fallback';
    }
    return name != null && name.isNotEmpty
        ? 'From "$name"'
        : 'Built-in food list';
  }

  static String _matchKindLabel(NutritionMatchKind? kind) {
    return switch (kind) {
      NutritionMatchKind.exact => 'Exact match',
      NutritionMatchKind.alias => 'Alias match',
      NutritionMatchKind.keyword => 'Keyword match',
      NutritionMatchKind.category => 'Category match',
      NutritionMatchKind.fallback => 'Generic fallback',
      null => 'Built-in match',
    };
  }

  static Future<void> showSourceDetailsDialog(
    BuildContext context, {
    required NutritionEstimate estimate,
    required bool isAiModelReady,
    VoidCallback? onOpenAiModelManager,
  }) {
    final food = estimate.matchedFood;
    final isLlm = estimate.source == NutritionEstimateSource.onDeviceLlm;
    final sourceDescription = isLlm
        ? 'On-Device AI (compact language model)'
        : 'Built-in food list · ${_matchKindLabel(estimate.matchKind)}';

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Auto-fill Source'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              sourceDescription,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (food != null) ...<Widget>[
              const SizedBox(height: 10),
              Text('Matched item: ${food.name}'),
              const SizedBox(height: 4),
              Text(
                'Per 100g: ${formatNumber(food.kcalPer100g)} kcal · '
                'P ${formatNumber(food.proteinPer100g)}g · '
                'C ${formatNumber(food.carbsPer100g)}g · '
                'F ${formatNumber(food.fatPer100g)}g',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ] else if (estimate.matchedFoodName != null) ...<Widget>[
              const SizedBox(height: 10),
              Text('Matched item: ${estimate.matchedFoodName}'),
            ],
            const SizedBox(height: 12),
            Text(
              isAiModelReady
                  ? 'On-Device AI model is downloaded and active.'
                  : 'On-Device AI model is not downloaded, so Auto-fill used the built-in food list.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: <Widget>[
          if (!isAiModelReady && onOpenAiModelManager != null)
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                onOpenAiModelManager();
              },
              child: const Text('Download AI Model'),
            ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Tappable source chip shown after Auto-fill populates nutrition fields.
class NutritionAutoFillSourceChip extends StatelessWidget {
  const NutritionAutoFillSourceChip({
    super.key,
    required this.estimate,
    required this.isAiModelReady,
    this.onOpenAiModelManager,
  });

  final NutritionEstimate estimate;
  final bool isAiModelReady;
  final VoidCallback? onOpenAiModelManager;

  @override
  Widget build(BuildContext context) {
    final isFallback = estimate.matchKind == NutritionMatchKind.fallback &&
        estimate.source == NutritionEstimateSource.localCatalog;
    final colorScheme = Theme.of(context).colorScheme;

    return ActionChip(
      avatar: Icon(
        Icons.info_outline_rounded,
        size: 16,
        color: isFallback ? colorScheme.error : colorScheme.primary,
      ),
      label: Text(
        NutritionAutoFillHelper.badgeLabel(estimate),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: () {
        NutritionAutoFillHelper.showSourceDetailsDialog(
          context,
          estimate: estimate,
          isAiModelReady: isAiModelReady,
          onOpenAiModelManager: onOpenAiModelManager,
        );
      },
    );
  }
}
