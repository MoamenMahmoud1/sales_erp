import 'package:flutter/material.dart';

import '../../customers/domain/customer.dart';
import '../data/local_sale_repository.dart';
import '../presentation/widgets/invoice_share_card.dart';
import '../presentation/widgets/invoice_share_page.dart';

/// Details for one normal customer invoice with clean display numbering.
class InvoiceDetailsPage extends StatefulWidget {
  final Customer customer;
  final int invoiceId;

  const InvoiceDetailsPage({
    super.key,
    required this.customer,
    required this.invoiceId,
  });

  @override
  State<InvoiceDetailsPage> createState() => _InvoiceDetailsPageState();
}

class _InvoiceDetailsPageState extends State<InvoiceDetailsPage> {
  final _repository = LocalSaleRepository();

  Map<String, Object?>? _invoice;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final invoice = await _repository.getInvoiceWithItems(widget.invoiceId);
      if (!mounted) return;
      setState(() {
        _invoice = invoice;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Failed to load invoice: $error';
      });
    }
  }

  List<ShareInvoiceItem> _itemsOf(Map<String, Object?> invoice) {
    final raw = invoice['items'] as List? ?? const [];
    return raw.map((item) {
      final map = Map<String, Object?>.from(item as Map);
      return ShareInvoiceItem(
        name: map['product_name'] as String,
        quantity: (map['quantity'] as num).toInt(),
        unitPrice: (map['unit_price'] as num).toDouble(),
      );
    }).toList(growable: false);
  }

  String _money(num? value) =>
      '${(value ?? 0).toDouble().toStringAsFixed(2)} EGP';

  Future<void> _openShare() async {
    final invoice = _invoice;
    if (invoice == null) return;
    final data = ShareInvoiceData.fromMap(invoice, _itemsOf(invoice));
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => InvoiceSharePage(data: data)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final invoice = _invoice;
    final number = invoice == null
        ? null
        : ShareInvoiceData.fromMap(invoice, _itemsOf(invoice)).displayNumber;
    return Scaffold(
      appBar: AppBar(
        title: Text(number == null ? 'Invoice' : 'Invoice $number'),
        actions: [
          if (invoice != null)
            IconButton(
              tooltip: 'Share',
              icon: const Icon(Icons.ios_share),
              onPressed: _openShare,
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final scheme = Theme.of(context).colorScheme;
    if (_loading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final invoice = _invoice!;
    final items = _itemsOf(invoice);
    final total = (invoice['total'] as num).toDouble();
    final subtotal = (invoice['subtotal'] as num).toDouble();
    final discount = (invoice['coupon_discount'] as num).toDouble();
    final paid = (invoice['paid_amount'] as num?)?.toDouble() ?? 0;
    final remaining = (total - paid).clamp(0, total).toDouble();

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.customer.name,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(widget.customer.phone,
                      style: TextStyle(color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  Text(
                    'Created: ${invoice['created_at']}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Items', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.name,
                                    style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text(
                                  '${item.quantity} × ${_money(item.unitPrice)}',
                                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          Text(_money(item.total),
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  if (items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(child: Text('No items.')),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _totalRow(scheme, 'Subtotal', _money(subtotal)),
                  if (discount > 0)
                    _totalRow(scheme, 'Discount', '-${_money(discount)}'),
                  _totalRow(scheme, 'Paid', _money(paid)),
                  const Divider(),
                  _totalRow(scheme, 'Total', _money(total), emphasized: true),
                  if (remaining > 0)
                    _totalRow(scheme, 'Remaining', _money(remaining), emphasized: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _openShare,
            icon: const Icon(Icons.ios_share),
            label: const Text('Share as image'),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _totalRow(
    ColorScheme scheme,
    String label,
    String value, {
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: TextStyle(
                fontSize: emphasized ? 16 : 13,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w500,
              )),
          Text(value,
              style: TextStyle(
                fontSize: emphasized ? 17 : 13,
                fontWeight: emphasized ? FontWeight.w800 : FontWeight.w600,
                color: emphasized ? scheme.primary : scheme.onSurface,
              )),
        ],
      ),
    );
  }
}
