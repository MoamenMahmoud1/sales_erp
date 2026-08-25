import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

class InvoiceDatabase {
  final String databaseName;
  Database? _database;

  InvoiceDatabase({this.databaseName = 'sales_erp_invoice.db'});

  Future<Database> get database async {
    final existing = _database;
    if (existing != null) {
      return existing;
    }

    final path = databaseName.contains('test')
      ? inMemoryDatabasePath
      : p.join(await getDatabasesPath(), databaseName);
    _database = await openDatabase(
      path,
      version: 2,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (database, version) async {
        await database.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await database.execute('''
          CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            paid_at TEXT,
            coupon_id INTEGER,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
          )
        ''');
        await database.execute('''
          CREATE TABLE invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            unit_price INTEGER NOT NULL,
            quantity INTEGER NOT NULL,
            FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
          )
        ''');
        await database.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            cash_amount INTEGER NOT NULL DEFAULT 0,
            transfer_amount INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
          )
        ''');
        await database.execute('''
          CREATE TABLE payment_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            cash_amount INTEGER NOT NULL,
            transfer_amount INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
          )
        ''');
        await database.execute('''
          CREATE TABLE payment_allocations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payment_transaction_id INTEGER NOT NULL,
            invoice_id INTEGER NOT NULL,
            cash_amount INTEGER NOT NULL,
            transfer_amount INTEGER NOT NULL,
            FOREIGN KEY (payment_transaction_id)
              REFERENCES payment_transactions(id) ON DELETE CASCADE,
            FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
          )
        ''');
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await database.execute(
            'ALTER TABLE invoices ADD COLUMN coupon_id INTEGER',
          );
        }
      },
    );
    return _database!;
  }

  Future<void> close() async {
    final database = _database;
    _database = null;
    await database?.close();
  }
}
