class Invoice {
  final int id;
  final int customerId;

  final DateTime createdAt;
  final DateTime updatedAt;

  final Map<int, int> products;

  final double subtotal;
  final double couponDiscount;
  final double total;

  const Invoice({
    required this.id,
    required this.customerId,
    required this.createdAt,
    required this.updatedAt,
    required this.products,
    required this.subtotal,
    required this.couponDiscount,
    required this.total,
  });

  double get calculatedTotal {
    final result = subtotal - couponDiscount;

    return result < 0 ? 0 : result;
  }

  bool get hasCouponDiscount {
    return couponDiscount > 0;
  }

  factory Invoice.fromMap(
    Map<String, Object?> map, {
    Map<int, int> products = const {},
  }) {
    return Invoice(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] as String,
      ),
      products: products,
      subtotal:
          (map['subtotal'] as num?)?.toDouble() ?? 0,
      couponDiscount:
          (map['coupon_discount'] as num?)?.toDouble() ?? 0,
      total:
          (map['total'] as num?)?.toDouble() ?? 0,
    );
  }
}