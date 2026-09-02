import 'package:flutter/material.dart';

import '../../customers/domain/customer.dart';
import '../../customers/domain/payment_method.dart';
import '../../products/data/local_product_repository.dart';
import '../../products/domain/product.dart';
import '../data/local_sale_repository.dart';
import 'widgets/quantity_stepper.dart';

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
  final _discountController = TextEditingController(text: '0');
  final Map<int, int> _quantities = {};

  List<Product> _products = const [];
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _discountController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final products = await _productRepository.getProducts();
      if (widget.invoiceId != null) {
        final invoice = await _saleRepository.getInvoiceWithItems(widget.invoiceId!);
        if (invoice == null) throw StateError('Invoice not found.');
        final rawItems = invoice['items'] as List? ?? const [];
        for (final raw in rawItems) {
          final item = Map<String, Object?>.from(raw as Map);
          final id = (item['product_id'] as num).toInt();
          final quantity = (item['quantity'] as num).toInt();
          if (quantity > 0) _quantities[id] = quantity;
        }
        _discountController.text =
            ((invoice['coupon_discount'] as num?)?.toDouble() ?? 0).toStringAsFixed(2);
      }
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = '$error';
      });
    }
  }

  void _setQuantity(int productId, int quantity) {
    setState(() {
      if (quantity <= 0) {
        _quantities.remove(productId);
      } else {
        _quantities[productId] = quantity;
      }
    });
  }

  double get _subtotal => _products.fold<double>(
        0,
        (total, product) => total + product.price * (_quantities[product.id] ?? 0),
      );

  double get _discount {
    final value = double.tryParse(_discountController.text) ?? 0;
    if (!value.isFinite || value <= 0) return 0;
    return value.clamp(0, _subtotal).toDouble();
  }

  double get _total => _subtotal - _discount;

  Future<void> _save() async {
    if (_quantities.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final method = widget.customer.paymentType == CustomerPaymentType.cash
          ? PaymentMethod.cash
          : PaymentMethod.transfer;
      final products = Map.of(_quantities);
      if (widget.invoiceId == null) {
        await _saleRepository.createInvoice(
          customerId: widget.customer.id,
          products: products,
          paymentMethod: method,
          couponDiscount: _discount,
        );
      } else {
        await _saleRepository.updateInvoice(
          invoiceId: widget.invoiceId!,
          customerId: widget.customer.id,
          products: products,
          paymentMethod: method,
          couponDiscount: _discount,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.invoiceId != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(editing ? 'Edit Invoice' : 'New Invoice'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _errorState()
              : _body(),
      bottomNavigationBar: !_loading && _error == null ? _saveBar() : null,
    );
  }

  Widget _body() {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  child: Text(widget.customer.name.trim().isEmpty
                      ? '?'
                      : widget.customer.name.trim()[0].toUpperCase()),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.customer.name,
                          style: const TextStyle(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 3),
                      Text(widget.customer.phone,
                          style: TextStyle(color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text('Products', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        for (final product in _products)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(product.name,
                            style: const TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 3),
                        Text('${product.price.toStringAsFixed(2)} EGP / carton',
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                      ],
                    ),
                  ),
                  QuantityStepper(
                    value: _quantities[product.id] ?? 0,
                    onChanged: (value) => _setQuantity(product.id, value),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 14),
        Text('Global discount', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        TextField(
          controller: _discountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'Discount amount',
            suffixText: 'EGP',
            border: OutlineInputBorder(),
          ),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _summaryRow('Subtotal', _subtotal),
                if (_discount > 0) _summaryRow('Discount', -_discount),
                const Divider(height: 20),
                _summaryRow('Total', _total, emphasized: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(String label, double amount, {bool emphasized = false}) {
    final style = TextStyle(
      fontSize: emphasized ? 17 : 14,
      fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
      color: emphasized ? Theme.of(context).colorScheme.primary : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: style),
          Text('${amount.toStringAsFixed(2)} EGP', style: style),
        ],
      ),
    );
  }

  Widget _saveBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: FilledButton.icon(
          onPressed: _saving || _quantities.isEmpty ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: Text(_saving ? 'Saving...' : 'Save invoice'),
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        ),
      ),
    );
  }

  Widget _errorState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded, size: 46),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
}
