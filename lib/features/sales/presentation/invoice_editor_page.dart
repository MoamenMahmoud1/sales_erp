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

  @override
  State<InvoiceEditorPage> createState() => _InvoiceEditorPageState();
}

class _InvoiceEditorPageState extends State<InvoiceEditorPage> {
  final _productRepository = LocalProductRepository();
  final _saleRepository = LocalSaleRepository();
  final Map<int, int> _quantities = {};
  List<Product> _products = const [];
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await _productRepository.getProducts();
    if (mounted) setState(() { _products = products; _loading = false; });
  }

  Future<void> _save() async {
    if (_quantities.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      await _saleRepository.createInvoice(
        customerId: widget.customer.id,
        products: _quantities,
        paymentMethod: widget.customer.paymentType == CustomerPaymentType.cash
            ? PaymentMethod.cash
            : PaymentMethod.transfer,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.invoiceId == null ? 'New Invoice' : 'Edit Invoice')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Customer: ${widget.customer.name}'),
                const SizedBox(height: 12),
                for (final product in _products)
                  ListTile(
                    title: Text(product.name),
                    subtitle: Text('${product.price.toStringAsFixed(2)} EGP'),
                    trailing: SizedBox(
                      width: 90,
                      child: TextFormField(
                        initialValue: '0',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Qty'),
                        onChanged: (value) {
                          final quantity = int.tryParse(value) ?? 0;
                          if (quantity > 0) {
                            _quantities[product.id] = quantity;
                          } else {
                            _quantities.remove(product.id);
                          }
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save invoice'),
                ),
              ],
            ),
    );
  }
}
