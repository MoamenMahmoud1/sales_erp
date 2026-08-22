import 'product.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts();

  Future<int> addProduct({
    required String name,
    required double price,
  });

  Future<void> updateProduct({
    required int id,
    required String name,
    required double price,
  });

  Future<void> deleteProduct(int id);
}