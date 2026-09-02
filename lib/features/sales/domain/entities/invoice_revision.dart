import 'invoice_revision_item.dart';

/// Immutable snapshot of a normal customer invoice at one point in time.
class InvoiceRevision {
  final int id;
  final int invoiceId;
  final int revisionNumber;
  final DateTime createdAt;
  final int customerId;
  final String customerName;
  final double subtotal;
  final double discount;
  final double total;
  final List<InvoiceRevisionItem> items;

  const InvoiceRevision({
    required this.id,
    required this.invoiceId,
    required this.revisionNumber,
    required this.createdAt,
    required this.customerId,
    required this.customerName,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.items,
  });
}
