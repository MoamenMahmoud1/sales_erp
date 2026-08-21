import 'coupon.dart';

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

  /// Total monetary value of all coupon pieces.
  double get totalValue {
    return coupon.valueForQuantity(quantity);
  }

  /// Displays the quantity as cartons + remaining coupons.
  ///
  /// Examples:
  /// 10 pieces with 10 pieces/carton -> 1 Carton
  /// 25 pieces with 10 pieces/carton -> 2 Cartons + 5 Coupons
  /// 5 pieces with 10 pieces/carton -> 5 Coupons
  String get displayQuantity {
    return coupon.formatQuantity(quantity);
  }

  /// Number of complete cartons.
  int get cartons {
    return coupon.cartonsForQuantity(quantity);
  }

  /// Number of remaining coupons after complete cartons.
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

