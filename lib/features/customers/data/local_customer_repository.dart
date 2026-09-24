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

  Future<void> cacheCustomers(Iterable<Customer> customers) async {
    final database = await AppDatabase.database;
    await database.transaction((transaction) async {
      for (final customer in customers) {
        final row = customer.toMap();
        final existing = await transaction.query(
          'customers',
          columns: ['payment_type'],
          where: 'id = ?',
          whereArgs: [customer.id],
          limit: 1,
        );
        final values = {
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
          // The current API does not expose payment_type, so preserve the
          // existing local value instead of resetting it during API refresh.
          'payment_type':
              existing.isNotEmpty
                  ? existing.first['payment_type']
                  : row['payment_type'],
        };
        final updated = await transaction.update(
          'customers',
          values,
          where: 'id = ?',
          whereArgs: [customer.id],
        );
        if (updated == 0) {
          await transaction.insert(
            'customers',
            {'id': customer.id, ...values},
          );
        }
      }
    });
  }

  Future<void> cacheCustomer(Customer customer) => cacheCustomers([customer]);

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