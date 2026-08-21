import 'package:flutter/material.dart';

import '../../customers/domain/customer.dart';
import '../../customers/domain/payment_method.dart';
import '../../products/data/local_product_repository.dart';
import '../../products/domain/product.dart';
import '../data/local_sale_repository.dart';

class InvoiceEditorPage extends StatefulWidget {
  final Customer customer;
  final int? invoiceId;

  const InvoiceEditorPage({
    super.key,
    required this.customer,
    this.invoiceId,
  });

  bool get isEditing => invoiceId != null;

  @override
  State<InvoiceEditorPage> createState() => _InvoiceEditorPageState();
}

class _InvoiceEditorPageState extends State<InvoiceEditorPage> {
  final _productRepository = LocalProductRepository();
  final _saleRepository = LocalSaleRepository();

  List<Product> _products = [];
  final Map<int, int> _quantities = {};

  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final products = await _productRepository.getProducts();

    if (widget.invoiceId != null) {
      final invoice = await _saleRepository.getInvoice(
        widget.invoiceId!,
      );

      if (invoice != null) {
        _quantities.addAll(invoice.products);
      }
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _products = products;
      _isLoading = false;
    });
  }

  void _changeQuantity(
    Product product,
    int change,
  ) {
    final currentQuantity = _quantities[product.id] ?? 0;
    final newQuantity = currentQuantity + change;

    setState(() {
      if (newQuantity <= 0) {
        _quantities.remove(product.id);
      } else {
        _quantities[product.id] = newQuantity;
      }
    });
  }

  PaymentMethod _getPaymentMethod() {
    switch (widget.customer.paymentType) {
      case CustomerPaymentType.cash:
        return PaymentMethod.cash;
      case CustomerPaymentType.bankTransfer:
        return PaymentMethod.transfer;
    }
  }

  Future<void> _save() async {
    if (_quantities.isEmpty || _isSaving) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final products = Map<int, int>.from(_quantities);

      if (widget.isEditing) {
        await _saleRepository.updateInvoice(
          invoiceId: widget.invoiceId!,
          products: products,
        );
      } else {
        await _saleRepository.createInvoice(
          customerId: widget.customer.id,
          products: products,
          paymentMethod: _getPaymentMethod(),
        );
      }

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isEditing
              ? 'Edit Invoice'
              : 'New Invoice',
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _products.length,
        itemBuilder: (context, index) {
          final product = _products[index];
          final quantity = _quantities[product.id] ?? 0;

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
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton(
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(),
                )
              : Text(
                  widget.isEditing
                      ? 'SAVE CHANGES'
                      : 'CREATE INVOICE',
                ),
        ),
      ),
    );
  }
}

