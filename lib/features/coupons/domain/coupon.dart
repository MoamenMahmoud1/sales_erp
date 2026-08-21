class Coupon {
  final int id;
  final String name;
  final int piecesPerCoupon;
  final double unitPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Coupon({
    required this.id,
    required this.name,
    required this.piecesPerCoupon,
    required this.unitPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  double get totalValue {
    return piecesPerCoupon * unitPrice;
  }

  double valueForQuantity(int quantity) {
    return quantity * unitPrice;
  }

  int cartonsForQuantity(int quantity) {
    if (quantity <= 0 || piecesPerCoupon <= 0) {
      return 0;
    }

    return quantity ~/ piecesPerCoupon;
  }

  int remainderForQuantity(int quantity) {
    if (quantity <= 0 || piecesPerCoupon <= 0) {
      return 0;
    }

    return quantity % piecesPerCoupon;
  }

  String formatQuantity(int quantity) {
    if (quantity <= 0) {
      return '0 Coupons';
    }

    if (piecesPerCoupon <= 0) {
      return '$quantity Coupons';
    }

    final cartons = cartonsForQuantity(quantity);
    final remainder = remainderForQuantity(quantity);

    if (cartons == 0) {
      return '$quantity Coupons';
    }

    if (remainder == 0) {
      return cartons == 1
          ? '1 Carton'
          : '$cartons Cartons';
    }

    final cartonText = cartons == 1
        ? '1 Carton'
        : '$cartons Cartons';

    return '$cartonText + $remainder Coupons';
  }

  factory Coupon.fromMap(
    Map<String, Object?> map,
  ) {
    return Coupon(
      id: map['id'] as int,
      name: map['name'] as String,
      piecesPerCoupon:
          map['pieces_per_coupon'] as int,
      unitPrice:
          (map['unit_price'] as num).toDouble(),
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
      updatedAt: DateTime.parse(
        map['updated_at'] as String,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'pieces_per_coupon': piecesPerCoupon,
      'unit_price': unitPrice,
      'created_at':
          createdAt.toUtc().toIso8601String(),
      'updated_at':
          updatedAt.toUtc().toIso8601String(),
    };
  }
}