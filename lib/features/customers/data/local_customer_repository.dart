import '../../../core/storage/app_database.dart';
import '../domain/customer.dart';
import '../domain/customer_repository.dart';

class LocalCustomerRepository implements CustomerRepository {
  @override
  Future<List<Customer>> getCustomers() async {
    final database = await AppDatabase.database;

    final rows = await database.query(
      'customers',
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(Customer.fromMap)
        .toList();
  }

  @override
  Future<Customer?> getCustomerById(
    int customerId,
  ) async {
    final database = await AppDatabase.database;

    final rows = await database.query(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return Customer.fromMap(rows.first);
  }

  @override
  Future<int> createCustomer(
    Customer customer,
  ) async {
    final database = await AppDatabase.database;

    return database.insert(
      'customers',
      {
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        'payment_type':
            customer.paymentType ==
                    CustomerPaymentType.bankTransfer
                ? 'bank_transfer'
                : 'cash',
      },
    );
  }

  @override
  Future<int> updateCustomer(
    Customer customer,
  ) async {
    final database = await AppDatabase.database;

    return database.update(
      'customers',
      {
        'name': customer.name,
        'phone': customer.phone,
        'address': customer.address,
        'payment_type':
            customer.paymentType ==
                    CustomerPaymentType.bankTransfer
                ? 'bank_transfer'
                : 'cash',
      },
      where: 'id = ?',
      whereArgs: [customer.id],
    );
  }

  @override
  Future<int> deleteCustomer(
    int customerId,
  ) async {
    final database = await AppDatabase.database;

    return database.delete(
      'customers',
      where: 'id = ?',
      whereArgs: [customerId],
    );
  }

  @override
  Future<List<Customer>> searchCustomers(
    String query,
  ) async {
    final database = await AppDatabase.database;

    final value = query.trim();

    if (value.isEmpty) {
      return getCustomers();
    }

    final rows = await database.query(
      'customers',
      where: '''
        name LIKE ?
        OR phone LIKE ?
      ''',
      whereArgs: [
        '%$value%',
        '%$value%',
      ],
      orderBy: 'name COLLATE NOCASE ASC',
    );

    return rows
        .map(Customer.fromMap)
        .toList();
  }
}