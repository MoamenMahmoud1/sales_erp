import 'package:flutter/material.dart';

import '../../products/data/local_product_repository.dart';
import '../../products/domain/product.dart';
import '../data/local_sale_repository.dart';
import '../domain/invoice.dart';
import '../domain/invoice_change.dart';
import 'invoice_editor_page.dart';
import '../../customers/domain/customer.dart';

class InvoiceDetailsPage extends StatefulWidget {
  final Customer customer;
  final int invoiceId;

  const InvoiceDetailsPage({
    super.key,
    required this.customer,
    required this.invoiceId,
  });

  @override
  State<InvoiceDetailsPage> createState() =>
      _InvoiceDetailsPageState();
}

class _InvoiceDetailsPageState
    extends State<InvoiceDetailsPage> {
  final _saleRepository = LocalSaleRepository();
  final _productRepository = LocalProductRepository();

  Invoice? _invoice;
  List<InvoiceChange> _changes = [];
  List<Product> _products = [];

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final invoice = await _saleRepository.getInvoice(
      widget.invoiceId,
    );

    final changes =
        await _saleRepository.getRecentInvoiceChanges(
      widget.invoiceId,
    );

    final products =
        await _productRepository.getProducts();

    if (!mounted) return;

    setState(() {
      _invoice = invoice;
      _changes = changes;
      _products = products;
      _isLoading = false;
    });
  }

  Product? _findProduct(int productId) {
    for (final product in _products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }

  String _productName(int productId) {
    return _findProduct(productId)?.name ??
        'Product #$productId';
  }

  String _quantityText(int quantity) {
    if (quantity == 0) {
      return 'removed';
    }

    return '× $quantity';
  }

  Future<void> _edit() async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => InvoiceEditorPage(
          customer: widget.customer,
          invoiceId: widget.invoiceId,
        ),
      ),
    );

    if (saved == true) {
      await _load();
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

    final invoice = _invoice;

    if (invoice == null) {
      return const Scaffold(
        body: Center(
          child: Text('Invoice not found.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Invoice #${invoice.id}'),
      ),

      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            widget.customer.name,
            style: Theme.of(context)
                .textTheme
                .headlineSmall,
          ),

          const SizedBox(height: 16),

          _InfoCard(
            title: 'Invoice information',
            children: [
              _InfoRow(
                label: 'Created',
                value: _formatDate(invoice.createdAt),
              ),
              _InfoRow(
                label: 'Updated',
                value: _formatDate(invoice.updatedAt),
              ),
            ],
          ),

          const SizedBox(height: 16),

          _InfoCard(
            title: 'Current products',
            children: invoice.products.entries.map(
              (entry) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _productName(entry.key),
                  ),
                  trailing: Text(
                    '× ${entry.value}',
                  ),
                );
              },
            ).toList(),
          ),

          const SizedBox(height: 16),

          if (_changes.isNotEmpty)
            _InfoCard(
              title: 'Changes in the last 24 hours',
              children: _changes.map(
                (change) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _productName(change.productId),
                    ),
                    subtitle: Text(
                      '${_quantityText(change.oldQuantity)}'
                      '  →  '
                      '${_quantityText(change.newQuantity)}',
                    ),
                  );
                },
              ).toList(),
            ),

          if (_changes.isEmpty)
            _InfoCard(
              title: 'Changes in the last 24 hours',
              children: const [
                Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 8,
                  ),
                  child: Text(
                    'No recent changes.',
                  ),
                ),
              ],
            ),

          const SizedBox(height: 24),

          FilledButton.icon(
            onPressed: _edit,
            icon: const Icon(Icons.edit),
            label: const Text('EDIT INVOICE'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dateTime) {
    final local = dateTime.toLocal();

    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    final hour = local.hour.toString().padLeft(2, '0');
    final minute =
        local.minute.toString().padLeft(2, '0');

    return '$day/$month/${local.year} '
        '$hour:$minute';
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _InfoCard({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),

            const SizedBox(height: 12),

            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value),
        ],
      ),
    );
  }
}