import '../domain/customer.dart';
import '../domain/customer_repository.dart';

class LocalCustomerRepository implements CustomerRepository {
  final List<Customer> _customers = [
    const Customer(
      id: 1,
      name: 'Ahmed Store',
      phone: '01000000000',
      address: 'Cairo',
    ),
    const Customer(
      id: 2,
      name: 'El Baraka Market',
      phone: '01111111111',
      address: 'Giza',
    ),
  ];

  @override
  Future<List<Customer>> getCustomers() async {
    return List.unmodifiable(_customers);
  }

  @override
  Future<void> addCustomer(Customer customer) async {
    _customers.add(customer);
  }

  @override
  Future<void> deleteCustomer(int id) async {
    _customers.removeWhere((customer) => customer.id == id);
  }
}