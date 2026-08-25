import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

class ApiCustomerRepository implements CustomerRepository {
  final ApiClient client;
  const ApiCustomerRepository(this.client);

  List<Customer> _items(Response<dynamic> response) {
    final payload = response.data;
    final values = payload is Map ? payload['results'] : payload;
    return (values as List)
        .map((item) => Customer.fromMap(Map<String, Object?>.from(item as Map)))
        .toList(growable: false);
  }

  @override
  Future<List<Customer>> getCustomers() async {
    return _items(await client.dio.get('/customers/'));
  }

  @override
  Future<Customer?> getCustomerById(int customerId) async {
    try {
      final response = await client.dio.get('/customers/$customerId/');
      return Customer.fromMap(Map<String, Object?>.from(response.data as Map));
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  @override
  Future<int> createCustomer(Customer customer) async {
    final response = await client.dio.post('/customers/', data: {
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address,
    });
    return (response.data['id'] as num).toInt();
  }

  @override
  Future<int> updateCustomer(Customer customer) async {
    await client.dio.patch('/customers/${customer.id}/', data: {
      'name': customer.name,
      'phone': customer.phone,
      'address': customer.address,
    });
    return customer.id;
  }

  @override
  Future<int> deleteCustomer(int customerId) async {
    await client.dio.delete('/customers/$customerId/');
    return customerId;
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    final customers = await getCustomers();
    final value = query.trim().toLowerCase();
    if (value.isEmpty) return customers;
    return customers.where((customer) {
      return customer.name.toLowerCase().contains(value) ||
          customer.phone.toLowerCase().contains(value);
    }).toList(growable: false);
  }
}
