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

  factory ReturnableInvoiceItem.fromJson(Map<String, dynamic> json) {
    return ReturnableInvoiceItem(
      invoiceItemId: _readInt(json['id']),
      productId: _readInt(json['product']),
      productName: json['product_name']?.toString() ?? '',
      soldQuantity: _readInt(json['quantity']),
      returnedQuantity: _readInt(json['returned_quantity']),
      unitPrice: json['unit_price']?.toString() ?? '0.00',
    );
  }
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

  factory ReturnableInvoice.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    return ReturnableInvoice(
      id: _readInt(json['id']),
      customerName: json['customer_name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      items: [
        for (final item in rawItems is List ? rawItems : const [])
          if (item is Map) ReturnableInvoiceItem.fromJson(Map<String, dynamic>.from(item)),
      ],
    );
  }
}

int _readInt(dynamic value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
