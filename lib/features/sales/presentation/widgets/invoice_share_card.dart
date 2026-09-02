import 'package:flutter/material.dart';

import '../../domain/services/invoice_display_number.dart';

class ShareInvoiceItem {
  final String name;
  final int quantity;
  final double unitPrice;

  const ShareInvoiceItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;
}

class ShareInvoiceData {
  final int id;
  final String customerName;
  final String customerPhone;
  final DateTime createdAt;
  final double subtotal;
  final double discount;
  final double total;
  final List<ShareInvoiceItem> items;
  final String paidStatus;
  final String paymentMethod;
  final double paidAmount;

  const ShareInvoiceData({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.createdAt,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.items,
    required this.paidStatus,
    required this.paymentMethod,
    required this.paidAmount,
  });

  String get displayNumber => const InvoiceDisplayNumber().forInvoice(
        id: id,
        createdAt: createdAt,
      );

  double get outstanding => (total - paidAmount).clamp(0, total);

  static ShareInvoiceData fromMap(
    Object? header,
    List<ShareInvoiceItem> items,
  ) {
    final map = Map<String, Object?>.from(header as Map);
    return ShareInvoiceData(
      id: (map['id'] as num).toInt(),
      customerName: map['customer_name'] as String,
      customerPhone: (map['customer_phone'] as String?) ?? '',
      createdAt: DateTime.parse(map['created_at'] as String),
      subtotal: (map['subtotal'] as num).toDouble(),
      discount: (map['coupon_discount'] as num).toDouble(),
      total: (map['total'] as num).toDouble(),
      items: items,
      paidStatus: (map['payment_status'] as String?) ?? 'unpaid',
      paymentMethod: (map['payment_method'] as String?) ?? 'cash',
      paidAmount: (map['paid_amount'] as num?)?.toDouble() ?? 0,
    );
  }
}

class InvoiceShareCard extends StatelessWidget {
  final ShareInvoiceData data;
  final double width;

  const InvoiceShareCard({
    super.key,
    required this.data,
    this.width = 360,
  });

  String _money(double value) => '${value.toStringAsFixed(2)} EGP';

  String _formatDate(DateTime dt) =>
      '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} — '
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final isPaid = data.paidStatus == 'paid';
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: width,
      constraints: const BoxConstraints(minHeight: 220),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            scheme.primaryContainer.withValues(alpha: .55),
            scheme.surface,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(scheme, isPaid),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          const _Label('Billed to'),
          Text(
            data.customerName,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.customerPhone,
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Date', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              Text(
                _formatDate(data.createdAt),
                style: TextStyle(
                  color: scheme.onSurface,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(),
          const SizedBox(height: 6),
          for (final item in data.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.name,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          '${item.quantity} × ${_money(item.unitPrice)}',
                          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _money(item.total),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          const Divider(),
          _totalLine('Subtotal', data.subtotal, scheme),
          if (data.discount > 0)
            _totalLine('Discount', -data.discount, scheme, isSubtraction: true),
          if (data.paidAmount > 0)
            _totalLine('Paid', -data.paidAmount, scheme, isSubtraction: true),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.primary,
                ),
              ),
              Text(
                _money(data.total),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'Thank you for your business',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(ColorScheme scheme, bool isPaid) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.receipt_long, color: scheme.primary, size: 22),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Sales ERP',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Invoice ${data.displayNumber}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
        ),
        Chip(
          label: Text(isPaid ? 'Paid' : 'Unpaid'),
          labelStyle: TextStyle(
            color: isPaid ? const Color(0xFF1B5E20) : const Color(0xFFB26A00),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
          backgroundColor:
              isPaid ? Colors.green.withValues(alpha: .18) : Colors.orange.withValues(alpha: .18),
          side: BorderSide.none,
        ),
      ],
    );
  }

  Widget _totalLine(
    String label,
    double amount,
    ColorScheme scheme, {
    bool isSubtraction = false,
  }) {
    final text = isSubtraction ? '-${_money(amount.abs())}' : _money(amount);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: amount < 0 ? scheme.error : scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
}
