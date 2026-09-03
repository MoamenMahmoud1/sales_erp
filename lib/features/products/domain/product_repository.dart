import 'product.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts();

  Future<int> addProduct({
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
    String category = 'General',
  });

  Future<void> updateProduct({
    required int id,
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
    String category = 'General',
  });

  Future<void> deleteProduct(int id);
}
