import 'package:flutter/material.dart';

import '../../../../core/extensions.dart';
import '../../../../core/grocery_parser.dart';
import '../../../../core/quantity_unit_formatter.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../models/grocery_category.dart';
import '../../../../services/recipe_import_service.dart';
import 'recipe_webview_extractor_page.dart';

class RecipeImportResult {
  final String title;
  final String url;
  final String sourceName;
  final int? servings;
  final String? imageUrl;
  final List<ParsedGroceryItem> ingredients;

  const RecipeImportResult({
    required this.title,
    required this.url,
    required this.sourceName,
    this.servings,
    this.imageUrl,
    required this.ingredients,
  });
}

Future<RecipeImportResult?> showRecipeImportDialog(
  BuildContext context, {
  String? initialUrl,
  RecipeImportService? service,
}) {
  return showDialog<RecipeImportResult>(
    context: context,
    builder: (_) =>
        _RecipeImportDialog(initialUrl: initialUrl, service: service),
  );
}

class _RecipeImportDialog extends StatefulWidget {
  final String? initialUrl;
  final RecipeImportService? service;

  const _RecipeImportDialog({this.initialUrl, this.service});

  @override
  State<_RecipeImportDialog> createState() => _RecipeImportDialogState();
}

class _RecipeImportDialogState extends State<_RecipeImportDialog> {
  late final RecipeImportService _service;
  late final TextEditingController _urlController;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _manualIngredientsController =
      TextEditingController();

  bool _isLoading = false;
  bool _manualMode = false;
  String? _error;
  ImportedRecipe? _recipe;

  int? _baseServings;
  int? _currentServings;
  late List<ParsedGroceryItem> _baseIngredients;
  late List<ParsedGroceryItem> _scaledIngredients;
  late List<bool> _selected;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? RecipeImportService();
    _urlController = TextEditingController(text: widget.initialUrl ?? '');
    _baseIngredients = const [];
    _scaledIngredients = const [];
    _selected = const [];

    if (widget.initialUrl != null &&
        RecipeImportService.isRecipeUrl(widget.initialUrl!)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fetchRecipe());
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _titleController.dispose();
    _manualIngredientsController.dispose();
    super.dispose();
  }

  Future<void> _fetchRecipe() async {
    final url = _urlController.text.trim();
    if (!RecipeImportService.isRecipeUrl(url)) {
      setState(() => _error = 'Please enter a valid http(s) recipe URL.');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final recipe = await _service.fetchAndParse(url);
      if (!mounted) return;
      _applyImportedRecipe(recipe);
    } on RecipeFetchException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 403 && RecipeWebViewExtractorPage.isSupported) {
        await _openWebViewFallback(url);
        return;
      }
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  void _applyImportedRecipe(ImportedRecipe recipe) {
    setState(() {
      _recipe = recipe;
      _manualMode = false;
      _error = null;
      _titleController.text = recipe.title;
      _baseServings = recipe.servings;
      _currentServings = recipe.servings;
      _baseIngredients = List.of(recipe.ingredients);
      _scaledIngredients = List.of(recipe.ingredients);
      _selected = List<bool>.filled(recipe.ingredients.length, true);
      _isLoading = false;
    });
  }

  Future<void> _openWebViewFallback(String url) async {
    final extracted = await Navigator.of(context).push<ImportedRecipe>(
      MaterialPageRoute(
        builder: (_) => RecipeWebViewExtractorPage(url: url, service: _service),
      ),
    );
    if (!mounted) return;
    if (extracted != null) {
      _applyImportedRecipe(extracted);
    } else {
      setState(() {
        _isLoading = false;
        _error = 'Recipe page returned HTTP 403.';
      });
    }
  }

  String _guessTitleFromUrl(String url) {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || uri.pathSegments.isEmpty) {
      return RecipeImportService.deriveSourceName(url);
    }
    final last = uri.pathSegments.lastWhere(
      (s) => s.isNotEmpty,
      orElse: () => '',
    );
    if (last.isEmpty) return RecipeImportService.deriveSourceName(url);
    final cleaned = last
        .replaceAll(RegExp(r'-\d+$'), '')
        .replaceAll('-', ' ')
        .trim();
    if (cleaned.isEmpty) return RecipeImportService.deriveSourceName(url);
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }

  void _enterManualMode() {
    setState(() {
      _manualMode = true;
      _error = null;
      if (_titleController.text.trim().isEmpty) {
        _titleController.text = _guessTitleFromUrl(_urlController.text);
      }
    });
  }

  void _parseManualIngredients() {
    try {
      final recipe = _service.fromManualIngredients(
        url: _urlController.text,
        title: _titleController.text,
        servings: 4,
        rawIngredientsText: _manualIngredientsController.text,
      );
      setState(() {
        _recipe = recipe;
        _manualMode = false;
        _error = null;
        _titleController.text = recipe.title;
        _baseServings = recipe.servings;
        _currentServings = recipe.servings;
        _baseIngredients = List.of(recipe.ingredients);
        _scaledIngredients = List.of(recipe.ingredients);
        _selected = List<bool>.filled(recipe.ingredients.length, true);
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _updateServings(int nextServings) {
    if (nextServings < 1 || _baseServings == null || _baseServings! <= 0) {
      return;
    }
    final factor = nextServings / _baseServings!;
    setState(() {
      _currentServings = nextServings;
      _scaledIngredients = List.generate(_baseIngredients.length, (i) {
        final base = _baseIngredients[i];
        final currentCat = _scaledIngredients[i].category;
        final scaledQty = double.parse(
          (base.quantity * factor).toStringAsFixed(2),
        );
        return base.copyWith(
          quantity: scaledQty > 0 ? scaledQty : base.quantity,
          category: currentCat,
        );
      });
    });
  }

  void _updateCategory(int index, GroceryCategory category) {
    setState(() {
      _scaledIngredients[index] = _scaledIngredients[index].copyWith(
        category: category,
      );
    });
  }

  void _toggleAll(bool? value) {
    final next = value ?? false;
    setState(() {
      _selected = List<bool>.filled(_selected.length, next);
    });
  }

  void _onConfirm() {
    final recipe = _recipe;
    if (recipe == null) return;
    final chosen = <ParsedGroceryItem>[];
    for (var i = 0; i < _scaledIngredients.length; i++) {
      if (_selected[i]) {
        chosen.add(_scaledIngredients[i]);
      }
    }
    if (chosen.isEmpty) return;

    final title = _titleController.text.trim().isEmpty
        ? recipe.title
        : _titleController.text.trim();

    Navigator.of(context).pop(
      RecipeImportResult(
        title: title,
        url: recipe.url,
        sourceName: recipe.sourceName,
        servings: _currentServings,
        imageUrl: recipe.imageUrl,
        ingredients: chosen,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasRecipe = _recipe != null;
    final allSelected = _selected.isNotEmpty && _selected.every((v) => v);
    final selectedCount = _selected.where((v) => v).length;

    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.restaurant_menu, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(l10n.importRecipe)),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: _manualMode && !hasRecipe
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.recipeTitleLabel,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _manualIngredientsController,
                      maxLines: 8,
                      minLines: 5,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: l10n.pasteIngredientsHint,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: scheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              )
            : !hasRecipe
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _urlController,
                    autofocus: widget.initialUrl == null,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      hintText: l10n.recipeUrlHint,
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.link),
                    ),
                    onSubmitted: (_) => _fetchRecipe(),
                  ),
                  if (_isLoading) ...[
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2.5),
                        ),
                        const SizedBox(width: 12),
                        Text(l10n.fetchingRecipe),
                      ],
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      l10n.recipeImportFailed(_error!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.error,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (RecipeWebViewExtractorPage.isSupported)
                          OutlinedButton.icon(
                            onPressed: () => _openWebViewFallback(
                              _urlController.text.trim(),
                            ),
                            icon: const Icon(Icons.open_in_browser, size: 18),
                            label: Text(l10n.openInWebView),
                          ),
                        OutlinedButton.icon(
                          onPressed: _enterManualMode,
                          icon: const Icon(Icons.content_paste, size: 18),
                          label: Text(l10n.pasteIngredientsManually),
                        ),
                      ],
                    ),
                  ],
                ],
              )
            : SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _titleController,
                      decoration: InputDecoration(
                        labelText: l10n.recipeTitleLabel,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Chip(
                          avatar: const Icon(Icons.public, size: 16),
                          label: Text(_recipe!.sourceName),
                          visualDensity: VisualDensity.compact,
                        ),
                        const Spacer(),
                        if (_currentServings != null) ...[
                          IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: _currentServings! > 1
                                ? () => _updateServings(_currentServings! - 1)
                                : null,
                            visualDensity: VisualDensity.compact,
                          ),
                          Text(
                            l10n.servingsCount(_currentServings!),
                            style: theme.textTheme.labelLarge,
                          ),
                          IconButton(
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () =>
                                _updateServings(_currentServings! + 1),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ],
                    ),
                    const Divider(),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: allSelected,
                      onChanged: _toggleAll,
                      title: Text(
                        '${l10n.selectAllIngredients} ($selectedCount/${_scaledIngredients.length})',
                        style: theme.textTheme.labelLarge,
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 280),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _scaledIngredients.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _scaledIngredients[index];
                          final qtyStr =
                              item.quantity == item.quantity.floorToDouble()
                              ? item.quantity.toInt().toString()
                              : item.quantity.toTrimmedFixed(2);
                          final formattedUnit = formatQuantityUnit(
                            item.unit,
                            item.quantity,
                          );
                          final qtyWithUnit =
                              formattedUnit != null && formattedUnit.isNotEmpty
                              ? '$qtyStr $formattedUnit'
                              : qtyStr;

                          return CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _selected[index],
                            onChanged: (val) =>
                                setState(() => _selected[index] = val ?? false),
                            title: Text(
                              item.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              item.note != null && item.note!.isNotEmpty
                                  ? '$qtyWithUnit • ${item.note}'
                                  : qtyWithUnit,
                            ),
                            secondary: DropdownButton<GroceryCategory>(
                              value: item.category,
                              underline: const SizedBox(),
                              items: GroceryCategory.values.map((cat) {
                                return DropdownMenuItem(
                                  value: cat,
                                  child: Text(cat.emoji),
                                );
                              }).toList(),
                              onChanged: (cat) {
                                if (cat != null) _updateCategory(index, cat);
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        if (_manualMode && !hasRecipe)
          FilledButton(
            onPressed: _parseManualIngredients,
            child: Text(l10n.parseIngredients),
          )
        else if (!hasRecipe)
          FilledButton(
            onPressed: _isLoading ? null : _fetchRecipe,
            child: Text(l10n.fetchRecipe),
          )
        else
          FilledButton(
            onPressed: selectedCount > 0 ? _onConfirm : null,
            child: Text(l10n.addRecipe),
          ),
      ],
    );
  }
}
