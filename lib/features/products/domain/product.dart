class Product {
  final int id;
  final String name;

  /// Legacy public price field. It is the product selling price.
  final double price;

  final double purchasePrice;

  double get sellingPrice => price;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    this.purchasePrice = 0,
  });

  factory Product.fromMap(Map<String, Object?> map) {
    double parse(Object? value, double fallback) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? fallback;
      return fallback;
    }

    final legacyPrice = parse(map['price'], 0);
    final sellingPrice = parse(map['selling_price'], legacyPrice);
    final parsedPurchasePrice = parse(map['purchase_price'], sellingPrice);
    final purchasePrice = parsedPurchasePrice > 0
        ? parsedPurchasePrice
        : sellingPrice;

    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      price: sellingPrice,
      purchasePrice: purchasePrice,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
    double? purchasePrice,
    double? sellingPrice,
  }) {
    final nextSellingPrice = sellingPrice ?? price ?? this.sellingPrice;
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: nextSellingPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
    );
  }
}
