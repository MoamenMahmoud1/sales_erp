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
      return await _remote.getProducts();
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
    final localId = await local.addProduct(
      name: name,
      price: price,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      category: category,
    );
    try {
      await _remote.addProduct(
        name: name,
        price: price,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        category: category,
      );
    } catch (_) {
      // محفوظ محليًا.
    }
    return localId;
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
    await local.updateProduct(
      id: id,
      name: name,
      price: price,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
      category: category,
    );
    try {
      await _remote.updateProduct(
        id: id,
        name: name,
        price: price,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
        category: category,
      );
    } catch (_) {
      // محفوظ محليًا.
    }
  }

  @override
  Future<void> deleteProduct(int id) async {
    await local.deleteProduct(id);
    try {
      await _remote.deleteProduct(id);
    } catch (_) {
      // محفوظ محليًا.
    }
  }
}
