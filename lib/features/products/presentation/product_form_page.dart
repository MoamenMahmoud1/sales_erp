import 'package:flutter/material.dart';

import '../data/local_product_repository.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

class ProductFormPage extends StatefulWidget {
  final Product? product;
  final ProductRepository? repository;
  final bool carMode;

  const ProductFormPage({
    super.key,
    this.product,
    this.repository,
    this.carMode = false,
  });

  bool get isEditing => product != null;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _repository = LocalProductRepository();

  ProductRepository get _dataSource => widget.repository ?? _repository;

  late final TextEditingController _nameController;
  late final TextEditingController _priceController;
  late final TextEditingController _purchasePriceController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    final product = widget.product;
    _nameController = TextEditingController(text: product?.name ?? '');
    _priceController = TextEditingController(
      text: product == null ? '' : product.sellingPrice.toStringAsFixed(2),
    );
    _purchasePriceController = TextEditingController(
      text: product == null ? '' : product.purchasePrice.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _purchasePriceController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Product name is required.';
    }
    return null;
  }

  String? _validatePrice(String? value, {required String label}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required.';
    }

    final price = double.tryParse(value.trim());
    if (price == null) {
      return 'Enter a valid $label.';
    }
    if (price <= 0) {
      return '$label must be greater than zero.';
    }
    return null;
  }

  Future<void> _save() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    final name = _nameController.text.trim();
    final sellingPrice = double.parse(_priceController.text.trim());
    final purchasePrice = widget.carMode
        ? double.parse(_purchasePriceController.text.trim())
        : sellingPrice;

    setState(() => _isSaving = true);

    try {
      final productId = widget.isEditing
          ? await _dataSource.updateProduct(
              id: widget.product!.id,
              name: name,
              price: sellingPrice,
              purchasePrice: purchasePrice,
              sellingPrice: sellingPrice,
            ).then((_) => widget.product!.id)
          : await _dataSource.addProduct(
              name: name,
              price: sellingPrice,
              purchasePrice: purchasePrice,
              sellingPrice: sellingPrice,
            );

      if (!mounted) return;

      Navigator.of(context).pop(
        Product(
          id: productId,
          name: name,
          price: sellingPrice,
          purchasePrice: purchasePrice,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save product: $error')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _decoration({required String label, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      suffixText: 'EGP',
      prefixIcon: Icon(icon),
      border: const OutlineInputBorder(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Product' : 'New Product'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              widget.isEditing ? 'Product information' : 'Add a new product',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              decoration: _decoration(
                label: 'Product name',
                icon: Icons.inventory_2_outlined,
              ),
              validator: _validateName,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _priceController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _decoration(
                label: widget.carMode ? 'Selling price' : 'Price',
                icon: Icons.sell_outlined,
              ),
              validator: (value) => _validatePrice(
                value,
                label: widget.carMode ? 'Selling price' : 'Price',
              ),
            ),
            if (widget.carMode) ...[
              const SizedBox(height: 16),
              TextFormField(
                controller: _purchasePriceController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: _decoration(
                  label: 'Buying price',
                  icon: Icons.shopping_cart_outlined,
                ),
                validator: (value) => _validatePrice(
                  value,
                  label: 'Buying price',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Selling price is used for the Car invoice. Buying price is used for cost and profit calculations.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
            ],
            const SizedBox(height: 32),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(
                  _isSaving
                      ? 'Saving...'
                      : widget.isEditing
                          ? 'Save Changes'
                          : 'Create Product',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
