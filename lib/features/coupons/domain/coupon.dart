class Coupon {
  final int id;
  final String name;
  final int unitsPerCarton;
  final double cartonPrice;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Coupon({
    required this.id,
    required this.name,
    required this.unitsPerCarton,
    required this.cartonPrice,
    required this.createdAt,
    required this.updatedAt,
  });

  /// سعر الوحدة = سعر الكرتونة ÷ عدد الوحدات في الكرتونة.
  double get unitPrice {
    if (unitsPerCarton <= 0) {
      return 0;
    }

    return cartonPrice / unitsPerCarton;
  }

  /// القيمة الإجمالية لعدد معين من الوحدات.
  double valueForQuantity(
    int quantity,
  ) {
    if (quantity <= 0) {
      return 0;
    }

    return quantity * unitPrice;
  }

  /// عدد الكراتين الكاملة في الكمية.
  int cartonsForQuantity(
    int quantity,
  ) {
    if (quantity <= 0 ||
        unitsPerCarton <= 0) {
      return 0;
    }

    return quantity ~/ unitsPerCarton;
  }

  /// الوحدات المتبقية بعد الكراتين الكاملة.
  int remainderForQuantity(
    int quantity,
  ) {
    if (quantity <= 0 ||
        unitsPerCarton <= 0) {
      return 0;
    }

    return quantity % unitsPerCarton;
  }

  /// عرض الكمية بشكل مفهوم للمستخدم.
  String formatQuantity(
    int quantity,
  ) {
    if (quantity <= 0) {
      return '0 Units';
    }

    if (unitsPerCarton <= 0) {
      return '$quantity Units';
    }

    final cartons =
        cartonsForQuantity(quantity);

    final remainder =
        remainderForQuantity(quantity);

    if (cartons == 0) {
      return '$quantity Units';
    }

    if (remainder == 0) {
      return cartons == 1
          ? '1 Carton'
          : '$cartons Cartons';
    }

    final cartonText = cartons == 1
        ? '1 Carton'
        : '$cartons Cartons';

    return '$cartonText + $remainder Units';
  }

  factory Coupon.fromMap(
    Map<String, Object?> map,
  ) {
    return Coupon(
      id: map['id'] as int,
      name: map['name'] as String,
      unitsPerCarton:
          (map['units_per_carton'] as num?)
                  ?.toInt() ??
              (map['pieces_per_coupon'] as num?)
                  ?.toInt() ??
              0,
      cartonPrice:
          (map['carton_price'] as num?)
                  ?.toDouble() ??
              (map['unit_price'] as num?)
                  ?.toDouble() ??
              0,
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
      'units_per_carton':
          unitsPerCarton,
      'carton_price':
          cartonPrice,
      'created_at':
          createdAt
              .toUtc()
              .toIso8601String(),
      'updated_at':
          updatedAt
              .toUtc()
              .toIso8601String(),
    };
  }

  Coupon copyWith({
    int? id,
    String? name,
    int? unitsPerCarton,
    double? cartonPrice,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Coupon(
      id: id ?? this.id,
      name: name ?? this.name,
      unitsPerCarton:
          unitsPerCarton ??
              this.unitsPerCarton,
      cartonPrice:
          cartonPrice ??
              this.cartonPrice,
      createdAt:
          createdAt ?? this.createdAt,
      updatedAt:
          updatedAt ?? this.updatedAt,
    );
  }
}

