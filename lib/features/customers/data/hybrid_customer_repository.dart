import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';
import 'api_customer_repository.dart';
import 'local_customer_repository.dart';

/// الوضع المختلط (Hybrid).
///
/// - القراءة: بنجرب الـ API الأول؛ لو السيرفر ملوش دعوة
///   (networking error) بنقع على القاعدة المحلية.
/// - الكتابة: الـAPI هو المصدر النهائي. بعد النجاح نحدّث الـlocal cache.
///   عمليات الكتابة الـoffline لا تُخترع محليًا هنا؛ الـcommands القابلة
///   لإعادة المحاولة تستخدم الـdurable outbox في طبقتها الخاصة.
class HybridCustomerRepository implements CustomerRepository {
  final ApiClient client;
  final LocalCustomerRepository local;

  ApiCustomerRepository? _api;

  HybridCustomerRepository(
    this.client, {
    LocalCustomerRepository? local,
  }) : local = local ?? LocalCustomerRepository();

  ApiCustomerRepository get _remote =>
      _api ??= ApiCustomerRepository(client);

  bool _isOffline(Object error) => error is DioException;

  @override
  Future<List<Customer>> getCustomers() async {
    try {
      final customers = await _remote.getCustomers();
      await local.cacheCustomers(customers);
      return customers;
    } catch (error) {
      if (_isOffline(error)) return local.getCustomers();
      rethrow;
    }
  }

  @override
  Future<Customer?> getCustomerById(int customerId) async {
    try {
      final customer = await _remote.getCustomerById(customerId);
      if (customer != null) await local.cacheCustomer(customer);
      return customer;
    } catch (error) {
      if (_isOffline(error)) return local.getCustomerById(customerId);
      rethrow;
    }
  }

  @override
  Future<int> createCustomer(Customer customer) async {
    final remoteId = await _remote.createCustomer(customer);
    await local.cacheCustomer(customer.copyWith(id: remoteId));
    return remoteId;
  }

  @override
  Future<int> updateCustomer(Customer customer) async {
    await _remote.updateCustomer(customer);
    await local.cacheCustomer(customer);
    return customer.id;
  }

  @override
  Future<int> deleteCustomer(int customerId) async {
    await _remote.deleteCustomer(customerId);
    await local.deleteCustomer(customerId);
    return customerId;
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      final customers = await _remote.searchCustomers(query);
      await local.cacheCustomers(customers);
      return customers;
    } catch (error) {
      if (_isOffline(error)) return local.searchCustomers(query);
      rethrow;
    }
  }
}