/// Frozen product line belonging to an invoice revision.
class InvoiceRevisionItem {
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;

  const InvoiceRevisionItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
  });

  double get total => unitPrice * quantity;
}
