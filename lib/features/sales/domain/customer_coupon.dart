import '../../coupons/domain/coupon.dart';

class CustomerCoupon {
  final int id;
  final int customerId;
  final Coupon coupon;
  final int quantity;
  final DateTime createdAt;

  const CustomerCoupon({
    required this.id,
    required this.customerId,
    required this.coupon,
    required this.quantity,
    required this.createdAt,
  });

  double get totalValue {
    return coupon.valueForQuantity(quantity);
  }

  String get displayQuantity {
    return coupon.formatQuantity(quantity);
  }

  int get cartons {
    return coupon.cartonsForQuantity(quantity);
  }

  int get remainder {
    return coupon.remainderForQuantity(quantity);
  }

  CustomerCoupon copyWith({
    int? id,
    int? customerId,
    Coupon? coupon,
    int? quantity,
    DateTime? createdAt,
  }) {
    return CustomerCoupon(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      coupon: coupon ?? this.coupon,
      quantity: quantity ?? this.quantity,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory CustomerCoupon.fromMap(
    Map<String, Object?> map,
    Coupon coupon,
  ) {
    return CustomerCoupon(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      coupon: coupon,
      quantity: map['quantity'] as int,
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'coupon_id': coupon.id,
      'quantity': quantity,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }
}

