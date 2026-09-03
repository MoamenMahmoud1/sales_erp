import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';
import 'api_product_repository.dart';
import 'local_product_repository.dart';

/// الوضع المختلط (Hybrid) للمنتجات.
///
/// نفس فكرة [HybridCustomerRepository]:
/// قراءة من الـ API مع fallback للمحلي، وكتابة محلية أولًا
/// + محاولة إرسال للـ API.
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
  }) async {
    final localId = await local.addProduct(
      name: name,
      price: price,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
    );
    try {
      await _remote.addProduct(
        name: name,
        price: price,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
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
  }) async {
    await local.updateProduct(
      id: id,
      name: name,
      price: price,
      purchasePrice: purchasePrice,
      sellingPrice: sellingPrice,
    );
    try {
      await _remote.updateProduct(
        id: id,
        name: name,
        price: price,
        purchasePrice: purchasePrice,
        sellingPrice: sellingPrice,
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
