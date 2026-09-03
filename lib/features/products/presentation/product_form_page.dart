import 'package:flutter/material.dart';

import '../data/local_product_repository.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

class ProductFormPage extends StatefulWidget {
  final Product? product;
  final ProductRepository? repository;

  const ProductFormPage({
    super.key,
    this.product,
    this.repository,
  });

  bool get isEditing =>
      product != null;

  @override
  State<ProductFormPage> createState() =>
      _ProductFormPageState();
}

class _ProductFormPageState
    extends State<ProductFormPage> {
  final _formKey =
      GlobalKey<FormState>();

  final _repository =
      LocalProductRepository();

  ProductRepository get _dataSource =>
      widget.repository ?? _repository;

  late final TextEditingController
      _nameController;

  late final TextEditingController
      _priceController;

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();

    _nameController =
        TextEditingController(
      text: widget.product?.name ?? '',
    );

    _priceController =
        TextEditingController(
      text: widget.product == null
          ? ''
          : widget.product!.price
              .toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();

    super.dispose();
  }

  String? _validateName(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Product name is required.';
    }

    return null;
  }

  String? _validatePrice(
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return 'Price is required.';
    }

    final price =
        double.tryParse(value.trim());

    if (price == null) {
      return 'Enter a valid price.';
    }

    if (price <= 0) {
      return 'Price must be greater than zero.';
    }

    return null;
  }

  Future<void> _save() async {
    if (_isSaving) {
      return;
    }

    if (!_formKey.currentState!
        .validate()) {
      return;
    }

    final price =
        double.parse(
      _priceController.text.trim(),
    );
    final name = _nameController.text.trim();

    setState(() {
      _isSaving = true;
    });

    try {
      final productId = widget.isEditing
          ? await _updateProduct(name, price)
          : await _dataSource.addProduct(
              name: name,
              price: price,
            );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(
        Product(
          id: productId,
          name: name,
          price: price,
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save product: $error',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<int> _updateProduct(
    String name,
    double price,
  ) async {
    final product = widget.product!;
    await _dataSource.updateProduct(
      id: product.id,
      name: name,
      price: price,
    );
    return product.id;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Edit Product'
              : 'New Product',
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding:
              const EdgeInsets.all(16),
          children: [
            Text(
              widget.isEditing
                  ? 'Product information'
                  : 'Add a new product',
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(
                    fontWeight:
                        FontWeight.bold,
                  ),
            ),

            const SizedBox(
              height: 24,
            ),

            TextFormField(
              controller:
                  _nameController,
              textCapitalization:
                  TextCapitalization.words,
              decoration:
                  const InputDecoration(
                labelText:
                    'Product name',
                prefixIcon:
                    Icon(
                  Icons.inventory_2_outlined,
                ),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  _validateName,
            ),

            const SizedBox(
              height: 16,
            ),

            TextFormField(
              controller:
                  _priceController,
              keyboardType:
                  const TextInputType
                      .numberWithOptions(
                decimal: true,
              ),
              decoration:
                  const InputDecoration(
                labelText:
                    'Price',
                suffixText:
                    'EGP',
                prefixIcon:
                    Icon(
                  Icons.payments_outlined,
                ),
                border:
                    OutlineInputBorder(),
              ),
              validator:
                  _validatePrice,
            ),

            const SizedBox(
              height: 32,
            ),

            SizedBox(
              height: 52,
              width: double.infinity,
              child: FilledButton.icon(
                onPressed:
                    _isSaving
                        ? null
                        : _save,
                icon: _isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.save,
                      ),
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
