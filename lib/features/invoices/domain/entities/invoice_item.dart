import 'money.dart';

class InvoiceItem {
  final int productId;
  final String productName;
  final Money unitPrice;
  final int quantity;

  const InvoiceItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  InvoiceItem copyWith({
    int? productId,
    String? productName,
    Money? unitPrice,
    int? quantity,
  }) {
    return InvoiceItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      quantity: quantity ?? this.quantity,
    );
  }

  Money get total => unitPrice * quantity;
}

