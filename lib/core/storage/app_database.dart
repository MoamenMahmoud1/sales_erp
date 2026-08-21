import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'sales_erp.db');

    _database = await openDatabase(
      path,
      version: 7,
      onCreate: (database, version) async {
        await _createTables(database);
      },
      onUpgrade: (database, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _migrateToVersion2(database);
        }

        if (oldVersion < 3) {
          await _migrateToVersion3(database);
        }

        if (oldVersion < 4) {
          await _migrateToVersion4(database);
        }

        if (oldVersion < 5) {
          await _migrateToVersion5(database);
        }

        if (oldVersion < 6) {
          await _migrateToVersion6(database);
        }

        if (oldVersion < 7) {
          await _migrateToVersion7(database);
        }
      },
    );

    await _cleanupExpiredInvoiceChanges(_database!);

    return _database!;
  }

  static Future<void> _createTables(
    Database database,
  ) async {
    await database.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        coupon_discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0
      )
    ''');

    await database.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,
        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE TABLE invoice_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        old_quantity INTEGER NOT NULL,
        new_quantity INTEGER NOT NULL,
        changed_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_invoice_changes_expires_at
      ON invoice_changes(expires_at)
    ''');

    await database.execute('''
      CREATE TABLE coupons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        pieces_per_coupon INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE TABLE customer_coupons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        coupon_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (coupon_id)
          REFERENCES coupons(id)
          ON DELETE CASCADE,
        UNIQUE(customer_id, coupon_id)
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_customer_coupons_customer_id
      ON customer_coupons(customer_id)
    ''');

    await database.execute('''
      CREATE TABLE invoice_coupons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        coupon_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL,
        total_value REAL NOT NULL,
        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE,
        FOREIGN KEY (coupon_id)
          REFERENCES coupons(id)
          ON DELETE RESTRICT
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_invoice_coupons_invoice_id
      ON invoice_coupons(invoice_id)
    ''');

    await database.execute('''
      CREATE TABLE payments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        invoice_id INTEGER NOT NULL,
        amount REAL NOT NULL,
        method TEXT NOT NULL,
        status TEXT NOT NULL,
        reference TEXT,
        created_at TEXT NOT NULL,
        confirmed_at TEXT
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_payments_customer_id
      ON payments(customer_id)
    ''');

    await database.execute('''
      CREATE INDEX idx_payments_invoice_id
      ON payments(invoice_id)
    ''');

    await database.execute('''
      CREATE INDEX idx_payments_status
      ON payments(status)
    ''');
  }

  static Future<void> _migrateToVersion2(
    Database database,
  ) async {
    await database.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE invoices (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL,
          subtotal REAL NOT NULL DEFAULT 0,
          coupon_discount REAL NOT NULL DEFAULT 0,
          total REAL NOT NULL DEFAULT 0
        )
      ''');

      await txn.execute('''
        CREATE TABLE invoice_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL DEFAULT 0,
          FOREIGN KEY (invoice_id)
            REFERENCES invoices(id)
        )
      ''');

      final oldSales = await txn.query('sales');

      for (final sale in oldSales) {
        final now =
            DateTime.now().toUtc().toIso8601String();

        final invoiceId = await txn.insert(
          'invoices',
          {
            'customer_id': sale['customer_id'],
            'created_at': now,
            'updated_at': now,
            'subtotal': 0,
            'coupon_discount': 0,
            'total': 0,
          },
        );

        await txn.insert(
          'invoice_items',
          {
            'invoice_id': invoiceId,
            'product_id': sale['product_id'],
            'quantity': sale['quantity'],
            'unit_price': 0,
          },
        );
      }

      await txn.execute('DROP TABLE sales');
    });
  }

  static Future<void> _migrateToVersion3(
    Database database,
  ) async {
    await database.execute('''
      CREATE TABLE invoice_changes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        old_quantity INTEGER NOT NULL,
        new_quantity INTEGER NOT NULL,
        changed_at TEXT NOT NULL,
        expires_at TEXT NOT NULL,
        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
      )
    ''');
  }

  static Future<void> _migrateToVersion4(
    Database database,
  ) async {
    await database.execute('''
      CREATE INDEX idx_invoice_changes_expires_at
      ON invoice_changes(expires_at)
    ''');
  }

  static Future<void> _migrateToVersion5(
    Database database,
  ) async {
    await database.transaction((txn) async {
      await txn.execute('''
        ALTER TABLE invoices
        ADD COLUMN subtotal REAL NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        ALTER TABLE invoices
        ADD COLUMN coupon_discount REAL NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        ALTER TABLE invoices
        ADD COLUMN total REAL NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        ALTER TABLE invoice_items
        ADD COLUMN unit_price REAL NOT NULL DEFAULT 0
      ''');

      await txn.execute('''
        CREATE TABLE coupons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          pieces_per_coupon INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');

      await txn.execute('''
        CREATE TABLE customer_coupons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          coupon_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (coupon_id)
            REFERENCES coupons(id)
            ON DELETE CASCADE,
          UNIQUE(customer_id, coupon_id)
        )
      ''');

      await txn.execute('''
        CREATE INDEX idx_customer_coupons_customer_id
        ON customer_coupons(customer_id)
      ''');

      await txn.execute('''
        CREATE TABLE invoice_coupons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          coupon_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          total_value REAL NOT NULL,
          FOREIGN KEY (invoice_id)
            REFERENCES invoices(id)
            ON DELETE CASCADE,
          FOREIGN KEY (coupon_id)
            REFERENCES coupons(id)
            ON DELETE RESTRICT
        )
      ''');

      await txn.execute('''
        CREATE INDEX idx_invoice_coupons_invoice_id
        ON invoice_coupons(invoice_id)
      ''');
    });
  }

  static Future<void> _migrateToVersion6(
    Database database,
  ) async {
    // Version 6 keeps the existing coupon schema.
    // No additional tables are required here.
  }

  static Future<void> _migrateToVersion7(
    Database database,
  ) async {
    await database.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE payments (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          invoice_id INTEGER NOT NULL,
          amount REAL NOT NULL,
          method TEXT NOT NULL,
          status TEXT NOT NULL,
          reference TEXT,
          created_at TEXT NOT NULL,
          confirmed_at TEXT
        )
      ''');

      await txn.execute('''
        CREATE INDEX idx_payments_customer_id
        ON payments(customer_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_payments_invoice_id
        ON payments(invoice_id)
      ''');

      await txn.execute('''
        CREATE INDEX idx_payments_status
        ON payments(status)
      ''');
    });
  }

  static Future<void> _cleanupExpiredInvoiceChanges(
    Database database,
  ) async {
    final now =
        DateTime.now().toUtc().toIso8601String();

    await database.delete(
      'invoice_changes',
      where: 'expires_at <= ?',
      whereArgs: [now],
    );
  }

  static Future<void> cleanupExpiredInvoiceChanges() async {
    final database = await AppDatabase.database;

    await _cleanupExpiredInvoiceChanges(database);
  }
}