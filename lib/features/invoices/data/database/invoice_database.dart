import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class InvoiceDatabase {
  static const _databaseName = 'sales_erp.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    _database = await _openDatabase();

    return _database!;
  }

  Future<Database> _openDatabase() async {
    final databasePath = await getDatabasesPath();

    final path = join(
      databasePath,
      _databaseName,
    );

    return openDatabase(
      path,
      version: _databaseVersion,
      onConfigure: _onConfigure,
      onCreate: _onCreate,
    );
  }

  Future<void> _onConfigure(
    Database db,
  ) async {
    await db.execute(
      'PRAGMA foreign_keys = ON',
    );
  }

  Future<void> _onCreate(
    Database db,
    int version,
  ) async {
    await db.transaction(
      (transaction) async {
        // --------------------------------------------------
        // Customers
        // --------------------------------------------------

        await transaction.execute('''
          CREATE TABLE customers (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');

        // --------------------------------------------------
        // Invoices
        // --------------------------------------------------

        await transaction.execute('''
          CREATE TABLE invoices (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL,
            paid_at TEXT,

            FOREIGN KEY (customer_id)
              REFERENCES customers(id)
          )
        ''');

        // --------------------------------------------------
        // Invoice Items
        // --------------------------------------------------

        await transaction.execute('''
          CREATE TABLE invoice_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL,
            product_id INTEGER NOT NULL,
            product_name TEXT NOT NULL,
            unit_price INTEGER NOT NULL,
            quantity INTEGER NOT NULL,

            FOREIGN KEY (invoice_id)
              REFERENCES invoices(id)
              ON DELETE CASCADE
          )
        ''');

        // --------------------------------------------------
        // Current Invoice Payment
        // --------------------------------------------------

        await transaction.execute('''
          CREATE TABLE payments (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            invoice_id INTEGER NOT NULL UNIQUE,
            cash_amount INTEGER NOT NULL,
            transfer_amount INTEGER NOT NULL,

            FOREIGN KEY (invoice_id)
              REFERENCES invoices(id)
              ON DELETE CASCADE
          )
        ''');

        // --------------------------------------------------
        // Payment Transactions
        // --------------------------------------------------

        await transaction.execute('''
          CREATE TABLE payment_transactions (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id INTEGER NOT NULL,
            cash_amount INTEGER NOT NULL,
            transfer_amount INTEGER NOT NULL,
            created_at TEXT NOT NULL,

            FOREIGN KEY (customer_id)
              REFERENCES customers(id)
          )
        ''');

        // --------------------------------------------------
        // Payment Allocations
        // --------------------------------------------------

        await transaction.execute('''
          CREATE TABLE payment_allocations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            payment_transaction_id INTEGER NOT NULL,
            invoice_id INTEGER NOT NULL,
            cash_amount INTEGER NOT NULL,
            transfer_amount INTEGER NOT NULL,

            FOREIGN KEY (payment_transaction_id)
              REFERENCES payment_transactions(id)
              ON DELETE CASCADE,

            FOREIGN KEY (invoice_id)
              REFERENCES invoices(id)
          )
        ''');

        // --------------------------------------------------
        // Indexes
        // --------------------------------------------------

        await transaction.execute('''
          CREATE INDEX idx_invoices_customer_id
          ON invoices(customer_id)
        ''');

        await transaction.execute('''
          CREATE INDEX idx_invoice_items_invoice_id
          ON invoice_items(invoice_id)
        ''');

        await transaction.execute('''
          CREATE INDEX idx_payment_transactions_customer_id
          ON payment_transactions(customer_id)
        ''');

        await transaction.execute('''
          CREATE INDEX idx_payment_allocations_transaction_id
          ON payment_allocations(payment_transaction_id)
        ''');

        await transaction.execute('''
          CREATE INDEX idx_payment_allocations_invoice_id
          ON payment_allocations(invoice_id)
        ''');
      },
    );
  }

  Future<void> close() async {
    final db = _database;

    if (db == null) {
      return;
    }

    await db.close();

    _database = null;
  }
}

