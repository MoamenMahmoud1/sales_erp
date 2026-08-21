import '../domain/product.dart';
import '../domain/product_repository.dart';

class LocalProductRepository implements ProductRepository {
  final List<Product> _products = [
    const Product(
      id: 1,
      name: 'Product A',
      price: 100,
    ),
    const Product(
      id: 2,
      name: 'Product B',
      price: 150,
    ),
    const Product(
      id: 3,
      name: 'Product C',
      price: 200,
    ),
    const Product(
      id: 4,
      name: 'Product D',
      price: 75,
    ),
  ];

  @override
  Future<List<Product>> getProducts() async {
    return List.unmodifiable(_products);
  }
}