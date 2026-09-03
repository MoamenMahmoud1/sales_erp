import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/product.dart';
import '../domain/product_repository.dart';

class ApiProductRepository implements ProductRepository {
  final ApiClient client;

  const ApiProductRepository(this.client);

  List<Map<String, Object?>> _rows(Response<dynamic> response) {
    final payload = response.data;
    final values = payload is Map ? payload['results'] : payload;
    return (values as List)
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList(growable: false);
  }

  @override
  Future<List<Product>> getProducts() async {
    final response = await client.dio.get('/products/');
    return _rows(response).map(Product.fromMap).toList(growable: false);
  }

  @override
  Future<int> addProduct({
    required String name,
    required double price,
    double? purchasePrice,
    double? sellingPrice,
    String category = 'General',
  }) async {
    final normalizedSellingPrice = sellingPrice ?? price;
    final normalizedPurchasePrice = purchasePrice ?? normalizedSellingPrice;

    final response = await client.dio.post('/products/', data: {
      'name': name.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'purchase_price': normalizedPurchasePrice,
      'selling_price': normalizedSellingPrice,
    });
    return (response.data['id'] as num).toInt();
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
    final normalizedSellingPrice = sellingPrice ?? price;
    final normalizedPurchasePrice = purchasePrice ?? normalizedSellingPrice;

    await client.dio.patch('/products/$id/', data: {
      'name': name.trim(),
      'category': category.trim().isEmpty ? 'General' : category.trim(),
      'purchase_price': normalizedPurchasePrice,
      'selling_price': normalizedSellingPrice,
    });
  }

  @override
  Future<void> deleteProduct(int id) async {
    await client.dio.delete('/products/$id/');
  }
}
