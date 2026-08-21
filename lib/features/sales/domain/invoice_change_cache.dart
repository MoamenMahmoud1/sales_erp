import 'invoice_change.dart';

class InvoiceChangeCache {
  final int invoiceId;
  final DateTime changedAt;
  final DateTime expiresAt;
  final List<InvoiceChange> changes;

  const InvoiceChangeCache({
    required this.invoiceId,
    required this.changedAt,
    required this.expiresAt,
    required this.changes,
  });

  bool get isExpired {
    return DateTime.now().toUtc().isAfter(expiresAt);
  }
}