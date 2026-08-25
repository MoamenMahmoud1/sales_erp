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
    final response = await client.dio.get('/sales/products/');
    return _rows(response).map(Product.fromMap).toList(growable: false);
  }

  @override
  Future<int> addProduct({required String name, required double price}) async {
    final response = await client.dio.post('/sales/products/', data: {
      'name': name.trim(),
      'price': price,
      'stock_quantity': 0,
    });
    return (response.data['id'] as num).toInt();
  }

  @override
  Future<void> updateProduct({required int id, required String name, required double price}) async {
    await client.dio.patch('/sales/products/$id/', data: {
      'name': name.trim(),
      'price': price,
    });
  }

  @override
  Future<void> deleteProduct(int id) async {
    await client.dio.delete('/sales/products/$id/');
  }
}
