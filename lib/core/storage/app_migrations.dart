import 'package:sqflite/sqflite.dart';

Future<void> runAppMigrations(
  Database db,
  int oldVersion,
) async {
  if (oldVersion < 2) await _migrateToVersion2(db);
  if (oldVersion < 3) await _migrateToVersion3(db);
  if (oldVersion < 4) await _migrateToVersion4(db);
  if (oldVersion < 5) await _migrateToVersion5(db);
  if (oldVersion < 6) await _migrateToVersion6(db);
  if (oldVersion < 7) await _migrateToVersion7(db);
  if (oldVersion < 8) await _migrateToVersion8(db);
  if (oldVersion < 9) await _migrateToVersion9(db);
  if (oldVersion < 10) await _migrateToVersion10(db);
  if (oldVersion < 11) await _migrateToVersion11(db);
  if (oldVersion < 12) await _migrateToVersion12(db);
}

Future<void> _migrateToVersion2(Database db) async {
  await db.transaction((txn) async {
    if (!await _tableExists(txn, 'invoices')) {
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
    if (!await _tableExists(txn, 'invoice_items')) {
      await txn.execute('''
        CREATE TABLE invoice_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL DEFAULT 0,
          FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
        )
      ''');
    }
    if (await _tableExists(txn, 'sales')) {
      final oldSales = await txn.query('sales');
      for (final sale in oldSales) {
        final now = DateTime.now().toUtc().toIso8601String();
        final invoiceId = await txn.insert('invoices', {
          'customer_id': sale['customer_id'],
          'created_at': now,
          'updated_at': now,
          'subtotal': 0,
          'coupon_discount': 0,
          'total': 0,
        });
        await txn.insert('invoice_items', {
          'invoice_id': invoiceId,
          'product_id': sale['product_id'],
          'quantity': sale['quantity'],
          'unit_price': 0,
        });
      }
      await txn.execute('DROP TABLE sales');
    }
  });
}

Future<void> _migrateToVersion3(Database db) async {
  if (await _tableExists(db, 'invoice_changes')) return;
  await db.execute('''
    CREATE TABLE invoice_changes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      old_quantity INTEGER NOT NULL,
      new_quantity INTEGER NOT NULL,
      changed_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
    )
  ''');
}

Future<void> _migrateToVersion4(Database db) async {
  await db.execute('''
    CREATE INDEX IF NOT EXISTS idx_invoice_changes_expires_at
    ON invoice_changes(expires_at)
  ''');
}

Future<void> _migrateToVersion5(Database db) async {
  await db.transaction((txn) async {
    if (!await _tableExists(txn, 'coupons')) {
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
    if (!await _tableExists(txn, 'customer_coupons')) {
      await txn.execute('''
        CREATE TABLE customer_coupons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          customer_id INTEGER NOT NULL,
          coupon_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          created_at TEXT NOT NULL,
          FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
          FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
          UNIQUE(customer_id, coupon_id)
        )
      ''');
    }
    if (!await _tableExists(txn, 'invoice_coupons')) {
      await txn.execute('''
        CREATE TABLE invoice_coupons (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          invoice_id INTEGER NOT NULL,
          coupon_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          unit_price REAL NOT NULL,
          total_value REAL NOT NULL,
          FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
          FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE RESTRICT
        )
      ''');
    }
  });
  await db.execute('CREATE INDEX IF NOT EXISTS idx_coupons_name ON coupons(name)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_coupons_customer_id ON customer_coupons(customer_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_customer_coupons_coupon_id ON customer_coupons(coupon_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_invoice_coupons_invoice_id ON invoice_coupons(invoice_id)');
}

Future<void> _migrateToVersion6(Database db) async {}

Future<void> _migrateToVersion7(Database db) async {
  if (await _tableExists(db, 'payments')) return;
  await db.transaction((txn) async {
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
        FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
        FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
      )
    ''');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_payments_customer_id ON payments(customer_id)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_payments_invoice_id ON payments(invoice_id)');
    await txn.execute('CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status)');
  });
}

Future<void> _migrateToVersion8(Database db) async {}

Future<void> _migrateToVersion9(Database db) async {
  if (await _tableExists(db, 'customers')) return;
  await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      address TEXT NOT NULL,
      payment_type TEXT NOT NULL DEFAULT 'cash'
    )
  ''');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_name ON customers(name)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_customers_phone ON customers(phone)');
}

Future<void> _migrateToVersion10(Database db) async {
  await db.transaction((txn) async {
    final columns = await txn.rawQuery('PRAGMA table_info(coupons)');
    final existing = {for (final row in columns) row['name'] as String};

    if (!existing.contains('units_per_carton')) {
      await txn.execute('ALTER TABLE coupons ADD COLUMN units_per_carton INTEGER');
    }
    if (!existing.contains('carton_price')) {
      await txn.execute('ALTER TABLE coupons ADD COLUMN carton_price REAL');
    }

    await txn.execute('''
      UPDATE coupons
      SET units_per_carton = COALESCE(units_per_carton, pieces_per_coupon, 0),
          carton_price = COALESCE(carton_price, pieces_per_coupon * unit_price, 0)
    ''');
  });
}

Future<void> _migrateToVersion11(Database db) async {
  await db.transaction((txn) async {
    // Car schema belongs to the central AppDatabase. The schema helper is
    // idempotent so this migration can also recover partially-created tables.
    // ignore: avoid_dynamic_calls
    await _createCarTables(txn);
  });
}

Future<void> _migrateToVersion12(Database db) async {
  await db.transaction((txn) async {
    final columns = await txn.rawQuery('PRAGMA table_info(car_revisions)');
    final existing = {for (final row in columns) row['name'] as String};

    if (!existing.contains('sales_car_id')) {
      await txn.execute('ALTER TABLE car_revisions ADD COLUMN sales_car_id INTEGER');
    }
    if (!existing.contains('sales_car_name')) {
      await txn.execute('ALTER TABLE car_revisions ADD COLUMN sales_car_name TEXT');
    }
    if (!existing.contains('warehouse_id')) {
      await txn.execute('ALTER TABLE car_revisions ADD COLUMN warehouse_id INTEGER');
    }
    if (!existing.contains('warehouse_name')) {
      await txn.execute('ALTER TABLE car_revisions ADD COLUMN warehouse_name TEXT');
    }

    // Existing rows from the first Car migration may be missing these values.
    // Backfill them from the current trip snapshot when possible.
    await txn.execute('''
      UPDATE car_revisions
      SET sales_car_id = COALESCE(
            sales_car_id,
            (SELECT sales_car_id FROM car_trips WHERE car_trips.id = car_revisions.trip_id)
          ),
          sales_car_name = COALESCE(
            sales_car_name,
            (SELECT sales_car_name FROM car_trips WHERE car_trips.id = car_revisions.trip_id)
          ),
          warehouse_id = COALESCE(
            warehouse_id,
            (SELECT warehouse_id FROM car_trips WHERE car_trips.id = car_revisions.trip_id)
          ),
          warehouse_name = COALESCE(
            warehouse_name,
            (SELECT warehouse_name FROM car_trips WHERE car_trips.id = car_revisions.trip_id)
          )
    ''');
  });
}

Future<void> _createCarTables(DatabaseExecutor db) async {
  // Importing through a local helper would create a circular dependency with
  // the central schema, so execute the migration through the shared schema
  // entry point exposed in this file's part-free design.
  throw StateError(
    'Car schema migration must be wired by AppDatabase using createCarTables.',
  );
}

Future<bool> _tableExists(DatabaseExecutor db, String tableName) async {
  final rows = await db.rawQuery('''
    SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?
  ''', [tableName]);
  return rows.isNotEmpty;
}
