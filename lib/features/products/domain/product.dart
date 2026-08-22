class Product {
  final int id;
  final String name;
  final double price;

  const Product({
    required this.id,
    required this.name,
    required this.price,
  });

  factory Product.fromMap(Map<String, Object?> map) {
    return Product(
      id: map['id'] as int,
      name: map['name'] as String,
      price: (map['price'] as num).toDouble(),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
    };
  }

  Product copyWith({
    int? id,
    String? name,
    double? price,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
    );
  }
}