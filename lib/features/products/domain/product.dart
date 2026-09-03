class Product {
  final int id;
  final String name;
  final String category;

  /// Legacy public price field. It is the product selling price.
  final double price;

  final double purchasePrice;

  double get sellingPrice => price;

  const Product({
    required this.id,
    required this.name,
    this.category = 'General',
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
    final rawCategory = (map['category'] as String?)?.trim();

    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      category: rawCategory == null || rawCategory.isEmpty
          ? 'General'
          : rawCategory,
      price: sellingPrice,
      purchasePrice: purchasePrice,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'purchase_price': purchasePrice,
      'selling_price': sellingPrice,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    String? category,
    double? price,
    double? purchasePrice,
    double? sellingPrice,
  }) {
    final nextSellingPrice = sellingPrice ?? price ?? this.sellingPrice;
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      price: nextSellingPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
    );
  }
}
