import 'customer.dart';

abstract interface class CustomerRepository {
  Future<List<Customer>> getCustomers();
  Future<Customer?> getCustomerById(int customerId);
  Future<int> createCustomer(Customer customer);
  Future<int> updateCustomer(Customer customer);
  Future<int> deleteCustomer(int customerId);
  Future<List<Customer>> searchCustomers(String query);
}
