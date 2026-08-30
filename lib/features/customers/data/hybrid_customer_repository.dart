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
/// - الكتابة: بتتسجل محليًا أولًا وبعدين بنحاول نبعت للـ API.
///   لو السيرفر مش متاح وقت الكتابة تبقى البيانات محفوظة محليًا
///   وممكن بعدها تتزامن.
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
      return await _remote.getCustomers();
    } catch (error) {
      if (_isOffline(error)) return local.getCustomers();
      rethrow;
    }
  }

  @override
  Future<Customer?> getCustomerById(int customerId) async {
    try {
      return await _remote.getCustomerById(customerId);
    } catch (error) {
      if (_isOffline(error)) return local.getCustomerById(customerId);
      rethrow;
    }
  }

  @override
  Future<int> createCustomer(Customer customer) async {
    final localId = await local.createCustomer(customer);
    try {
      await _remote.createCustomer(customer);
    } catch (_) {
      // سيرفر مش متاح → محفوظة محليًا على الأقل.
    }
    return localId;
  }

  @override
  Future<int> updateCustomer(Customer customer) async {
    final updated = await local.updateCustomer(customer);
    try {
      await _remote.updateCustomer(customer);
    } catch (_) {
      // مغفورة محليًا بنجاح.
    }
    return updated;
  }

  @override
  Future<int> deleteCustomer(int customerId) async {
    final deleted = await local.deleteCustomer(customerId);
    try {
      await _remote.deleteCustomer(customerId);
    } catch (_) {
      // اتشالت محليًا؛ هتتتابع للـ API بعدين.
    }
    return deleted;
  }

  @override
  Future<List<Customer>> searchCustomers(String query) async {
    try {
      return await _remote.searchCustomers(query);
    } catch (error) {
      if (_isOffline(error)) return local.searchCustomers(query);
      rethrow;
    }
  }
}