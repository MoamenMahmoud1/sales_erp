class ReturnableInvoiceItem {
  final int invoiceItemId;
  final int productId;
  final String productName;
  final int soldQuantity;
  final int returnedQuantity;
  final String unitPrice;

  const ReturnableInvoiceItem({
    required this.invoiceItemId,
    required this.productId,
    required this.productName,
    required this.soldQuantity,
    required this.returnedQuantity,
    required this.unitPrice,
  });

  int get remainingQuantity => soldQuantity - returnedQuantity;
}

class ReturnableInvoice {
  final int id;
  final String customerName;
  final String status;
  final List<ReturnableInvoiceItem> items;

  const ReturnableInvoice({
    required this.id,
    required this.customerName,
    required this.status,
    required this.items,
  });
}
