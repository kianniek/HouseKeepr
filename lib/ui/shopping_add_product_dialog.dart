import 'package:flutter/material.dart';
import '../services/shopping_products_service.dart';

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
    if (_selectedSection == null || _productENController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    final products = widget.productsService.getProductsForSection(
      _selectedSection!,
    );

    // Find the matching NL name if available, or use EN as fallback
    String? nlName;
    if (_productNLController.text.isNotEmpty) {
      nlName = _productNLController.text;
    } else {
      // Try to find a similar product for NL name
      for (final p in products) {
        if (p.productEN.toLowerCase() ==
            _productENController.text.toLowerCase()) {
          nlName = p.productNL;
          break;
        }
      }
      nlName ??= _productENController.text;
    }

    final product = ShoppingProduct(
      sectionNL: _selectedSection!, // In a full impl, map EN->NL
      sectionEN: _selectedSection!,
      productNL: nlName,
      productEN: _productENController.text.trim(),
    );

    try {
      await widget.productsService.addProduct(product);
      if (mounted) {
        _productENController.clear();
        _productNLController.clear();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Product added!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Product to Database'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a section and enter product names.',
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
              decoration: const InputDecoration(
                labelText: 'Product Name (EN)',
                hintText: 'e.g., Apple',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _productNLController,
              decoration: const InputDecoration(
                labelText: 'Product Name (NL) - Optional',
                hintText: 'e.g., Appel',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _addProduct, child: const Text('Add')),
      ],
    );
  }
}
