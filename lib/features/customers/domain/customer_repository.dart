import 'customer.dart';

abstract interface class CustomerRepository {
  Future<List<Customer>> getCustomers();

  Future<void> addCustomer(Customer customer);

  Future<void> deleteCustomer(int id);
}