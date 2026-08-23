import '../../domain/entities/invoice_item.dart';
import '../../domain/entities/money.dart';

class InvoiceItemModel {
  final int? id;
  final int invoiceId;
  final int productId;
  final String productName;
  final int unitPrice;
  final int quantity;

  const InvoiceItemModel({
    this.id,
    required this.invoiceId,
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.quantity,
  });

  factory InvoiceItemModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return InvoiceItemModel(
      id: map['id'] as int,
      invoiceId: map['invoice_id'] as int,
      productId: map['product_id'] as int,
      productName: map['product_name'] as String,
      unitPrice: map['unit_price'] as int,
      quantity: map['quantity'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'invoice_id': invoiceId,
      'product_id': productId,
      'product_name': productName,
      'unit_price': unitPrice,
      'quantity': quantity,
    };
  }

  InvoiceItem toEntity() {
    return InvoiceItem(
      productId: productId,
      productName: productName,
      unitPrice: Money(unitPrice),
      quantity: quantity,
    );
  }

  factory InvoiceItemModel.fromEntity({
    required int invoiceId,
    required InvoiceItem entity,
  }) {
    return InvoiceItemModel(
      invoiceId: invoiceId,
      productId: entity.productId,
      productName: entity.productName,
      unitPrice: entity.unitPrice.minorUnits,
      quantity: entity.quantity,
    );
  }
}

