import 'package:flutter/material.dart';
import '../../../../generated/app_localizations.dart';
import '../../../../services/shopping_products_service.dart';

class ShoppingAddProductDialog extends StatefulWidget {
  final ShoppingProductsService productsService;

  const ShoppingAddProductDialog({super.key, required this.productsService});

  @override
  State<ShoppingAddProductDialog> createState() =>
      _ShoppingAddProductDialogState();
}

class _ShoppingAddProductDialogState extends State<ShoppingAddProductDialog> {
  String? _selectedSection;
  final _productENController = TextEditingController();
  final _productNLController = TextEditingController();
  late List<String> _sections;

  @override
  void initState() {
    super.initState();
    _sections = widget.productsService.getSections();
    if (_sections.isNotEmpty) {
      _selectedSection = _sections.first;
    }
  }

  @override
  void dispose() {
    _productENController.dispose();
    _productNLController.dispose();
    super.dispose();
  }

  Future<void> _addProduct() async {
    final l10n = AppLocalizations.of(context);
    if (_selectedSection == null || _productENController.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.pleaseFillRequiredFields)));
      return;
    }

    final products = widget.productsService.getProductsForSection(
      _selectedSection!,
    );

    final enName = _productENController.text.trim();
    // Find the matching NL name if available, or use EN as fallback
    String? nlName;
    if (_productNLController.text.trim().isNotEmpty) {
      nlName = _productNLController.text.trim();
    } else {
      for (final p in products) {
        if (p.productEN.toLowerCase() == enName.toLowerCase()) {
          nlName = p.productNL;
          break;
        }
      }
      nlName ??= enName;
    }

    final sectionNL = products.isNotEmpty
        ? products.first.sectionNL
        : _selectedSection!;

    final product = ShoppingProduct(
      sectionNL: sectionNL,
      sectionEN: _selectedSection!,
      productNL: nlName,
      productEN: enName,
    );

    try {
      await widget.productsService.addProduct(product);
      if (mounted) {
        _productENController.clear();
        _productNLController.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.productAdded)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.addProductToDatabase),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.chooseSectionAndEnterProduct,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            DropdownButton<String>(
              isExpanded: true,
              value: _selectedSection,
              items: _sections
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (newVal) => setState(() => _selectedSection = newVal),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _productENController,
              decoration: InputDecoration(
                labelText: l10n.productNameEn,
                hintText: l10n.productNameEnHint,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _productNLController,
              decoration: InputDecoration(
                labelText: l10n.productNameNlOptional,
                hintText: l10n.productNameNlHint,
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        ElevatedButton(onPressed: _addProduct, child: Text(l10n.add)),
      ],
    );
  }
}
