import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AppDatabase {
  static Database? _database;

  static Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }

    final databasePath =
        await getDatabasesPath();

    final path = join(
      databasePath,
      'sales_erp.db',
    );

    _database = await openDatabase(
      path,
      version: 10,
      onConfigure: (database) async {
        await database.execute(
          'PRAGMA foreign_keys = ON',
        );
      },
      onCreate: (
        database,
        version,
      ) async {
        await _createTables(database);
      },
      onUpgrade: (
        database,
        oldVersion,
        newVersion,
      ) async {
        if (oldVersion < 2) {
          await _migrateToVersion2(
            database,
          );
        }

        if (oldVersion < 3) {
          await _migrateToVersion3(
            database,
          );
        }

        if (oldVersion < 4) {
          await _migrateToVersion4(
            database,
          );
        }

        if (oldVersion < 5) {
          await _migrateToVersion5(
            database,
          );
        }

        if (oldVersion < 6) {
          await _migrateToVersion6(
            database,
          );
        }

        if (oldVersion < 7) {
          await _migrateToVersion7(
            database,
          );
        }

        if (oldVersion < 8) {
          await _migrateToVersion8(
            database,
          );
        }

        if (oldVersion < 9) {
          await _migrateToVersion9(
            database,
          );
        }

        if (oldVersion < 10) {
          await _migrateToVersion10(
            database,
          );
        }
      },
    );

    await _cleanupExpiredInvoiceChanges(
      _database!,
    );

    return _database!;
  }

  // ============================================================
  // CREATE DATABASE
  // ============================================================

  static Future<void> _createTables(
    Database database,
  ) async {
    // CUSTOMERS

    await database.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        payment_type TEXT NOT NULL DEFAULT 'cash'
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_customers_name
      ON customers(name)
    ''');

    await database.execute('''
      CREATE INDEX idx_customers_phone
      ON customers(phone)
    ''');

    // PRODUCTS

    await database.execute('''
      CREATE TABLE products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        price REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_products_name
      ON products(name)
    ''');

    // INVOICES

    await database.execute('''
      CREATE TABLE invoices (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        subtotal REAL NOT NULL DEFAULT 0,
        coupon_discount REAL NOT NULL DEFAULT 0,
        total REAL NOT NULL DEFAULT 0,

        FOREIGN KEY (customer_id)
          REFERENCES customers(id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_invoices_customer_id
      ON invoices(customer_id)
    ''');

    // INVOICE ITEMS

    await database.execute('''
      CREATE TABLE invoice_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        invoice_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        unit_price REAL NOT NULL DEFAULT 0,

        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE,

        FOREIGN KEY (product_id)
          REFERENCES products(id)
          ON DELETE RESTRICT
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_invoice_items_invoice_id
      ON invoice_items(invoice_id)
    ''');

    await database.execute('''
      CREATE INDEX idx_invoice_items_product_id
      ON invoice_items(product_id)
    ''');

    // INVOICE CHANGES

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
          ON DELETE CASCADE,

        FOREIGN KEY (product_id)
          REFERENCES products(id)
          ON DELETE CASCADE
      )
    ''');

    await database.execute('''
      CREATE INDEX idx_invoice_changes_expires_at
      ON invoice_changes(expires_at)
    ''');

    // COUPONS

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
      CREATE INDEX idx_coupons_name
      ON coupons(name)
    ''');

    // CUSTOMER COUPONS

    await database.execute('''
      CREATE TABLE customer_coupons (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_id INTEGER NOT NULL,
        coupon_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        created_at TEXT NOT NULL,

        FOREIGN KEY (customer_id)
          REFERENCES customers(id)
          ON DELETE CASCADE,

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
      CREATE INDEX idx_customer_coupons_coupon_id
      ON customer_coupons(coupon_id)
    ''');

    // INVOICE COUPONS

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

    // PAYMENTS

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
        confirmed_at TEXT,

        FOREIGN KEY (customer_id)
          REFERENCES customers(id)
          ON DELETE CASCADE,

        FOREIGN KEY (invoice_id)
          REFERENCES invoices(id)
          ON DELETE CASCADE
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

  // ============================================================
  // MIGRATION 2
  // ============================================================

  static Future<void> _migrateToVersion2(
    Database database,
  ) async {
    await database.transaction(
      (txn) async {
        final invoicesExists =
            await _tableExists(
          txn,
          'invoices',
        );

        if (!invoicesExists) {
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
        }

        final invoiceItemsExists =
            await _tableExists(
          txn,
          'invoice_items',
        );

        if (!invoiceItemsExists) {
          await txn.execute('''
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
        }

        final salesExists =
            await _tableExists(
          txn,
          'sales',
        );

        if (salesExists) {
          final oldSales =
              await txn.query('sales');

          for (final sale in oldSales) {
            final now =
                DateTime.now()
                    .toUtc()
                    .toIso8601String();

            final invoiceId =
                await txn.insert(
              'invoices',
              {
                'customer_id':
                    sale['customer_id'],
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
                'invoice_id':
                    invoiceId,
                'product_id':
                    sale['product_id'],
                'quantity':
                    sale['quantity'],
                'unit_price': 0,
              },
            );
          }

          await txn.execute(
            'DROP TABLE sales',
          );
        }
      },
    );
  }

  // ============================================================
  // MIGRATION 3
  // ============================================================

  static Future<void> _migrateToVersion3(
    Database database,
  ) async {
    final exists =
        await _tableExists(
      database,
      'invoice_changes',
    );

    if (exists) {
      return;
    }

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
  }

  // ============================================================
  // MIGRATION 4
  // ============================================================

  static Future<void> _migrateToVersion4(
    Database database,
  ) async {
    await database.execute('''
      CREATE INDEX IF NOT EXISTS
        idx_invoice_changes_expires_at
      ON invoice_changes(expires_at)
    ''');
  }

  // ============================================================
  // MIGRATION 5
  // ============================================================

  static Future<void> _migrateToVersion5(
    Database database,
  ) async {
    await database.transaction(
      (txn) async {
        final couponsExists =
            await _tableExists(
          txn,
          'coupons',
        );

        if (!couponsExists) {
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
        }

        final customerCouponsExists =
            await _tableExists(
          txn,
          'customer_coupons',
        );

        if (!customerCouponsExists) {
          await txn.execute('''
            CREATE TABLE customer_coupons (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              customer_id INTEGER NOT NULL,
              coupon_id INTEGER NOT NULL,
              quantity INTEGER NOT NULL,
              created_at TEXT NOT NULL,

              FOREIGN KEY (customer_id)
                REFERENCES customers(id)
                ON DELETE CASCADE,

              FOREIGN KEY (coupon_id)
                REFERENCES coupons(id)
                ON DELETE CASCADE,

              UNIQUE(customer_id, coupon_id)
            )
          ''');
        }

        final invoiceCouponsExists =
            await _tableExists(
          txn,
          'invoice_coupons',
        );

        if (!invoiceCouponsExists) {
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
        }
      },
    );

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
        idx_coupons_name
      ON coupons(name)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
        idx_customer_coupons_customer_id
      ON customer_coupons(customer_id)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
        idx_customer_coupons_coupon_id
      ON customer_coupons(coupon_id)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
        idx_invoice_coupons_invoice_id
      ON invoice_coupons(invoice_id)
    ''');
  }

  // ============================================================
  // MIGRATION 6
  // ============================================================

  static Future<void> _migrateToVersion6(
    Database database,
  ) async {
    // Reserved.
  }

  // ============================================================
  // MIGRATION 7
  // ============================================================

  static Future<void> _migrateToVersion7(
    Database database,
  ) async {
    final exists =
        await _tableExists(
      database,
      'payments',
    );

    if (exists) {
      return;
    }

    await database.transaction(
      (txn) async {
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
            confirmed_at TEXT,

            FOREIGN KEY (customer_id)
              REFERENCES customers(id)
              ON DELETE CASCADE,

            FOREIGN KEY (invoice_id)
              REFERENCES invoices(id)
              ON DELETE CASCADE
          )
        ''');

        await txn.execute('''
          CREATE INDEX IF NOT EXISTS
            idx_payments_customer_id
          ON payments(customer_id)
        ''');

        await txn.execute('''
          CREATE INDEX IF NOT EXISTS
            idx_payments_invoice_id
          ON payments(invoice_id)
        ''');

        await txn.execute('''
          CREATE INDEX IF NOT EXISTS
            idx_payments_status
          ON payments(status)
        ''');
      },
    );
  }

  // ============================================================
  // MIGRATION 8
  // ============================================================

  static Future<void> _migrateToVersion8(
    Database database,
  ) async {
    // Products already exist.
  }

  // ============================================================
  // MIGRATION 9
  // ============================================================

  static Future<void> _migrateToVersion9(
    Database database,
  ) async {
    final exists =
        await _tableExists(
      database,
      'customers',
    );

    if (exists) {
      return;
    }

    await database.execute('''
      CREATE TABLE customers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        payment_type TEXT NOT NULL DEFAULT 'cash'
      )
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
        idx_customers_name
      ON customers(name)
    ''');

    await database.execute('''
      CREATE INDEX IF NOT EXISTS
        idx_customers_phone
      ON customers(phone)
    ''');
  }

  // ============================================================
  // MIGRATION 10 - NEW COUPON MODEL
  // ============================================================

  static Future<void> _migrateToVersion10(
    Database database,
  ) async {
    await database.transaction(
      (txn) async {
        final columns =
            await txn.rawQuery(
          'PRAGMA table_info(coupons)',
        );

        final existingColumns =
            columns
                .map(
                  (row) =>
                      row['name'] as String,
                )
                .toSet();

        // Add new columns.

        if (!existingColumns.contains(
          'units_per_carton',
        )) {
          await txn.execute('''
            ALTER TABLE coupons
            ADD COLUMN units_per_carton INTEGER
          ''');
        }

        if (!existingColumns.contains(
          'carton_price',
        )) {
          await txn.execute('''
            ALTER TABLE coupons
            ADD COLUMN carton_price REAL
          ''');
        }

        // Convert existing data from:
        //
        // pieces_per_coupon
        // unit_price
        //
        // to:
        //
        // units_per_carton
        // carton_price
        //
        // carton price =
        // pieces_per_coupon * unit_price

        await txn.execute('''
          UPDATE coupons
          SET
            units_per_carton =
              COALESCE(
                units_per_carton,
                pieces_per_coupon,
                0
              ),

            carton_price =
              COALESCE(
                carton_price,
                pieces_per_coupon *
                  unit_price,
                0
              )
        ''');
      },
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static Future<bool> _tableExists(
    DatabaseExecutor database,
    String tableName,
  ) async {
    final result =
        await database.rawQuery(
      '''
      SELECT name
      FROM sqlite_master
      WHERE type = 'table'
        AND name = ?
      ''',
      [tableName],
    );

    return result.isNotEmpty;
  }

  // ============================================================
  // CLEANUP
  // ============================================================

  static Future<void>
      _cleanupExpiredInvoiceChanges(
    Database database,
  ) async {
    final exists =
        await _tableExists(
      database,
      'invoice_changes',
    );

    if (!exists) {
      return;
    }

    final now =
        DateTime.now()
            .toUtc()
            .toIso8601String();

    await database.delete(
      'invoice_changes',
      where: 'expires_at <= ?',
      whereArgs: [now],
    );
  }

  static Future<void>
      cleanupExpiredInvoiceChanges() async {
    final database =
        await AppDatabase.database;

    await _cleanupExpiredInvoiceChanges(
      database,
    );
  }

  // ============================================================
  // DEVELOPMENT RESET
  // ============================================================

  static Future<void> resetDatabase() async {
    final databasePath =
        await getDatabasesPath();

    final path = join(
      databasePath,
      'sales_erp.db',
    );

    if (_database != null &&
        _database!.isOpen) {
      await _database!.close();
    }

    _database = null;

    await deleteDatabase(path);
  }
}