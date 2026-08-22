import 'package:flutter/material.dart';

import '../../products/data/local_product_repository.dart';
import '../../products/domain/product.dart';
import '../domain/customer.dart';

class AddProductsPage extends StatefulWidget {
  final Customer customer;

  const AddProductsPage({
    super.key,
    required this.customer,
  });

  @override
  State<AddProductsPage> createState() =>
      _AddProductsPageState();
}

class _AddProductsPageState
    extends State<AddProductsPage> {
  final _repository = LocalProductRepository();

  List<Product> _products = [];
  final Map<int, int> _quantities = {};

  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final products =
          await _repository.getProducts();

      if (!mounted) {
        return;
      }

      setState(() {
        _products = products;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to load products.';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load products: $error',
          ),
        ),
      );
    }
  }

  void _changeQuantity(
    Product product,
    int change,
  ) {
    final currentQuantity =
        _quantities[product.id] ?? 0;

    final newQuantity =
        currentQuantity + change;

    if (newQuantity < 0) {
      return;
    }

    setState(() {
      if (newQuantity == 0) {
        _quantities.remove(product.id);
      } else {
        _quantities[product.id] = newQuantity;
      }
    });
  }

  void _save() {
    if (_quantities.isEmpty) {
      return;
    }

    Navigator.of(context).pop(
      Map<int, int>.from(_quantities),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: 48,
              ),
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadProducts,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_products.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          children: const [
            SizedBox(height: 200),
            Center(
              child: Text(
                'No products available.',
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadProducts,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];

          final quantity =
              _quantities[product.id] ?? 0;

          return Card(
            margin: const EdgeInsets.only(
              bottom: 12,
            ),
            child: ListTile(
              title: Text(product.name),
              subtitle: Text(
                '${product.price.toStringAsFixed(2)} EGP',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: quantity == 0
                        ? null
                        : () {
                            _changeQuantity(
                              product,
                              -1,
                            );
                          },
                    icon: const Icon(
                      Icons.remove,
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '$quantity',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _changeQuantity(
                        product,
                        1,
                      );
                    },
                    icon: const Icon(
                      Icons.add,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Products - ${widget.customer.name}',
        ),
      ),
      body: _buildBody(),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed:
              _quantities.isEmpty ? null : _save,
          child: const Text('SAVE PRODUCTS'),
        ),
      ),
    );
  }
}