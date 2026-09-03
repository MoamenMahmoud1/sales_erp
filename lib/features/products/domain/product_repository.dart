import 'product.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts();

  Future<int> addProduct({
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
  });

  Future<void> updateProduct({
    required int id,
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
  });

  Future<void> deleteProduct(int id);
}
