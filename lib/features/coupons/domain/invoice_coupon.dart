class InvoiceCoupon {
  final int id;
  final int invoiceId;
  final int couponId;
  final int quantity;
  final double unitPrice;
  final double totalValue;

  const InvoiceCoupon({
    required this.id,
    required this.invoiceId,
    required this.couponId,
    required this.quantity,
    required this.unitPrice,
    required this.totalValue,
  });

  factory InvoiceCoupon.fromMap(
    Map<String, Object?> map,
  ) {
    return InvoiceCoupon(
      id: map['id'] as int,
      invoiceId: map['invoice_id'] as int,
      couponId: map['coupon_id'] as int,
      quantity: map['quantity'] as int,
      unitPrice:
          (map['unit_price'] as num).toDouble(),
      totalValue:
          (map['total_value'] as num).toDouble(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'coupon_id': couponId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_value': totalValue,
    };
  }
}