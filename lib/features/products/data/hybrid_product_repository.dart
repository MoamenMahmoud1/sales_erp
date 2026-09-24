import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import 'api_product_repository.dart';
import 'local_product_repository.dart';

/// Hybrid product storage: local-first writes with API synchronization and
/// API-first reads with local fallback.
class HybridProductRepository implements ProductRepository {
  final ApiClient client;
  final LocalProductRepository local;

  ApiProductRepository? _api;

  HybridProductRepository(
    this.client, {
    LocalProductRepository? local,
  }) : local = local ?? LocalProductRepository();

  ApiProductRepository get _remote => _api ??= ApiProductRepository(client);

  bool _isOffline(Object error) => error is DioException;

  @override
  Future<List<Product>> getProducts() async {
    try {
      final products = await _remote.getProducts();
      await local.cacheProducts(products);
      return products;
    } catch (error) {
      if (_isOffline(error)) return local.getProducts();
      rethrow;
    }
  }

  @override
  Future<int> addProduct({
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
    String category = 'General',
  }) async {
    final remoteId = await _remote.addProduct(
      name: name,
      price: price,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      category: category,
    );
    await local.cacheProduct(
      Product(
        id: remoteId,
        name: name.trim(),
        category: category.trim().isEmpty ? 'General' : category.trim(),
        price: sellingPrice ?? price,
        purchasePrice: purchasePrice ?? sellingPrice ?? price,
      ),
    );
    return remoteId;
  }

  @override
  Future<void> updateProduct({
    required int id,
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
    String category = 'General',
  }) async {
    await _remote.updateProduct(
      id: id,
      name: name,
      price: price,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      category: category,
    );
    await local.cacheProduct(
      Product(
        id: id,
        name: name.trim(),
        category: category.trim().isEmpty ? 'General' : category.trim(),
        price: sellingPrice ?? price,
        purchasePrice: purchasePrice ?? sellingPrice ?? price,
      ),
    );
  }

  @override
  Future<void> deleteProduct(int id) async {
    await _remote.deleteProduct(id);
    await local.deleteProduct(id);
  }
}
