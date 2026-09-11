import 'package:sqflite/sqflite.dart';

/// Migrations that were previously applied as post-open compatibility work.
///
/// Keeping them on the normal versioned upgrade path makes fresh installs and
/// upgraded installs follow the same schema lifecycle.
Future<void> runLatestMigrations(Database db, int oldVersion) async {
  if (oldVersion < 16) await _migrateToVersion16(db);
  if (oldVersion < 17) await _migrateToVersion17(db);
  if (oldVersion < 18) await _migrateToVersion18(db);
}

Future<void> _migrateToVersion16(Database db) async {
  await db.transaction((txn) async {
    await _ensureProductCategoryColumn(txn);
    await _ensureCarReturnedValueColumns(txn);
  });
}

Future<void> _migrateToVersion17(Database db) async {
  await db.transaction((txn) async {
    // Idempotent by design so a database created by an intermediate build is
    // repaired while moving to the current version.
    await _ensureProductCategoryColumn(txn);
    await _ensureCarReturnedValueColumns(txn);
    await _ensurePaymentDateColumns(txn);
  });
}

Future<void> _migrateToVersion18(Database db) async {
  await db.transaction((txn) async {
    await txn.execute('''
      CREATE TABLE IF NOT EXISTS sync_outbox (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        operation_key TEXT NOT NULL UNIQUE,
        method TEXT NOT NULL,
        path TEXT NOT NULL,
        body TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        next_attempt_at TEXT NOT NULL,
        last_error TEXT,
        response_body TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    await txn.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_outbox_due ON sync_outbox(status, next_attempt_at)',
    );
  });
}

Future<void> _ensureProductCategoryColumn(DatabaseExecutor db) async {
  if (!await _tableExists(db, 'products')) return;
  final columns = await _columns(db, 'products');
  if (columns.contains('category')) return;

  await db.execute(
    "ALTER TABLE products ADD COLUMN category TEXT NOT NULL DEFAULT 'General'",
  );
  await db.execute(
    "UPDATE products SET category = 'General' WHERE TRIM(COALESCE(category, '')) = ''",
  );
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)',
  );
}

Future<void> _ensureCarReturnedValueColumns(DatabaseExecutor db) async {
  await _ensureColumn(
    db,
    'car_trips',
    'total_returned_value_minor',
    'INTEGER NOT NULL DEFAULT 0',
  );
  await _ensureColumn(
    db,
    'car_revisions',
    'total_returned_value_minor',
    'INTEGER NOT NULL DEFAULT 0',
  );

  if (await _tableExists(db, 'car_trips') &&
      await _tableExists(db, 'car_trip_items')) {
    await db.execute('''
      UPDATE car_trips
      SET total_returned_value_minor = COALESCE((
        SELECT SUM(unit_price_minor * returned_cartons)
        FROM car_trip_items
        WHERE car_trip_items.trip_id = car_trips.id
      ), 0)
    ''');
  }

  if (await _tableExists(db, 'car_revisions') &&
      await _tableExists(db, 'car_revision_items')) {
    await db.execute('''
      UPDATE car_revisions
      SET total_returned_value_minor = COALESCE((
        SELECT SUM(unit_price_minor * returned_cartons)
        FROM car_revision_items
        WHERE car_revision_items.revision_id = car_revisions.id
      ), 0)
    ''');
  }
}

Future<void> _ensurePaymentDateColumns(DatabaseExecutor db) async {
  await _ensureColumn(db, 'payments', 'payment_at', 'TEXT');
  if (await _tableExists(db, 'payments')) {
    await db.execute(
      'UPDATE payments SET payment_at = created_at WHERE payment_at IS NULL',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_payments_payment_at ON payments(payment_at)',
    );
  }

  await _ensureColumn(db, 'car_payment_transactions', 'payment_at', 'TEXT');
  if (await _tableExists(db, 'car_payment_transactions')) {
    await db.execute('''
      UPDATE car_payment_transactions
      SET payment_at = created_at
      WHERE payment_at IS NULL
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_car_pmt_tx_payment_at ON car_payment_transactions(payment_at)',
    );
  }

  await _ensureColumn(db, 'car_payment_allocations', 'payment_at', 'TEXT');
  if (await _tableExists(db, 'car_payment_allocations')) {
    await db.execute('''
      UPDATE car_payment_allocations
      SET payment_at = (
        SELECT COALESCE(cpt.payment_at, cpt.created_at)
        FROM car_payment_transactions cpt
        WHERE cpt.id = car_payment_allocations.payment_transaction_id
      )
      WHERE payment_at IS NULL
    ''');
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_car_pmt_alloc_payment_at ON car_payment_allocations(payment_at)',
    );
  }
}

Future<void> _ensureColumn(
  DatabaseExecutor db,
  String table,
  String column,
  String definition,
) async {
  if (!await _tableExists(db, table)) return;
  final columns = await _columns(db, table);
  if (columns.contains(column)) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}

Future<Set<String>> _columns(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return {for (final row in rows) row['name'] as String};
}

Future<bool> _tableExists(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [table],
  );
  return rows.isNotEmpty;
}
