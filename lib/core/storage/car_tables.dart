import 'package:sqflite/sqflite.dart';

/// Creates the Car module's tables inside the application's single database.
Future<void> createCarTables(DatabaseExecutor db) async {
  await _createSalesCars(db);
  await _createWarehouses(db);
  await _createTrips(db);
  await _createTripItems(db);
  await _createRevisions(db);
  await _createRevisionItems(db);
  await _createPaymentTransactions(db);
  await _createPaymentAllocations(db);
}

Future<void> _createSalesCars(DatabaseExecutor db) async {
  if (!await _exists(db, 'sales_cars')) {
    await db.execute('''
      CREATE TABLE sales_cars (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        plate TEXT NOT NULL DEFAULT '',
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
  }
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_sales_cars_name ON sales_cars(name)',
  );
}

Future<void> _createWarehouses(DatabaseExecutor db) async {
  if (!await _exists(db, 'warehouses')) {
    await db.execute('''
      CREATE TABLE warehouses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        location TEXT,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');
  }
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_warehouses_name ON warehouses(name)',
  );
}

Future<void> _createTrips(DatabaseExecutor db) async {
  if (await _exists(db, 'car_trips')) return;
  await db.execute('''
    CREATE TABLE car_trips (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      display_number TEXT NOT NULL UNIQUE,
      sales_car_id INTEGER NOT NULL,
      sales_car_name TEXT NOT NULL,
      warehouse_id INTEGER NOT NULL,
      warehouse_name TEXT NOT NULL,
      opened_at TEXT NOT NULL,
      closed_at TEXT,
      due_date TEXT,
      status TEXT NOT NULL DEFAULT 'open',
      global_discount_percent REAL NOT NULL DEFAULT 0
        CHECK (global_discount_percent >= 0 AND global_discount_percent <= 100),
      gross_subtotal_minor INTEGER NOT NULL DEFAULT 0,
      product_discount_total_minor INTEGER NOT NULL DEFAULT 0,
      subtotal_after_products_minor INTEGER NOT NULL DEFAULT 0,
      global_discount_amount_minor INTEGER NOT NULL DEFAULT 0,
      final_total_value_minor INTEGER NOT NULL DEFAULT 0,
      total_loaded_cartons INTEGER NOT NULL DEFAULT 0,
      total_returned_cartons INTEGER NOT NULL DEFAULT 0,
      total_returned_value_minor INTEGER NOT NULL DEFAULT 0,
      total_sold_cartons INTEGER NOT NULL DEFAULT 0,
      paid_cash_minor INTEGER NOT NULL DEFAULT 0,
      paid_transfer_minor INTEGER NOT NULL DEFAULT 0,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      FOREIGN KEY (sales_car_id) REFERENCES sales_cars(id) ON DELETE RESTRICT,
      FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute('CREATE INDEX idx_car_trips_status ON car_trips(status)');
  await db.execute('CREATE INDEX idx_car_trips_sales_car_id ON car_trips(sales_car_id)');
  await db.execute('CREATE INDEX idx_car_trips_warehouse_id ON car_trips(warehouse_id)');
  await db.execute('CREATE INDEX idx_car_trips_opened_at ON car_trips(opened_at)');
  await db.execute('CREATE INDEX idx_car_trips_due_date ON car_trips(due_date)');
}

Future<void> _createTripItems(DatabaseExecutor db) async {
  if (!await _exists(db, 'car_trip_items')) return;
  await db.execute('''
    CREATE TABLE car_trip_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trip_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor > 0),
      loaded_cartons INTEGER NOT NULL CHECK (loaded_cartons >= 0),
      returned_cartons INTEGER NOT NULL CHECK (returned_cartons >= 0),
      discount_percent REAL NOT NULL DEFAULT 0
        CHECK (discount_percent >= 0 AND discount_percent <= 100),
      FOREIGN KEY (trip_id) REFERENCES car_trips(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT,
      CHECK (returned_cartons <= loaded_cartons)
    )
  ''');
  await db.execute('CREATE INDEX idx_car_trip_items_trip_id ON car_trip_items(trip_id)');
  await db.execute('CREATE INDEX idx_car_trip_items_product_id ON car_trip_items(product_id)');
}

Future<void> _createRevisions(DatabaseExecutor db) async {
  if (!await _exists(db, 'car_revisions')) return;
  await db.execute('''
    CREATE TABLE car_revisions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      trip_id INTEGER NOT NULL,
      display_number TEXT NOT NULL,
      revision_number INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      triggered_by TEXT,
      sales_car_id INTEGER NOT NULL,
      sales_car_name TEXT NOT NULL,
      warehouse_id INTEGER NOT NULL,
      warehouse_name TEXT NOT NULL,
      status TEXT NOT NULL,
      opened_at TEXT NOT NULL,
      closed_at TEXT,
      due_date TEXT,
      global_discount_percent REAL NOT NULL DEFAULT 0
        CHECK (global_discount_percent >= 0 AND global_discount_percent <= 100),
      gross_subtotal_minor INTEGER NOT NULL DEFAULT 0,
      product_discount_total_minor INTEGER NOT NULL DEFAULT 0,
      subtotal_after_products_minor INTEGER NOT NULL DEFAULT 0,
      global_discount_amount_minor INTEGER NOT NULL DEFAULT 0,
      final_total_value_minor INTEGER NOT NULL DEFAULT 0,
      total_loaded_cartons INTEGER NOT NULL DEFAULT 0,
      total_returned_cartons INTEGER NOT NULL DEFAULT 0,
      total_returned_value_minor INTEGER NOT NULL DEFAULT 0,
      total_sold_cartons INTEGER NOT NULL DEFAULT 0,
      paid_cash_minor INTEGER NOT NULL DEFAULT 0,
      paid_transfer_minor INTEGER NOT NULL DEFAULT 0,
      FOREIGN KEY (trip_id) REFERENCES car_trips(id) ON DELETE CASCADE,
      FOREIGN KEY (sales_car_id) REFERENCES sales_cars(id) ON DELETE RESTRICT,
      FOREIGN KEY (warehouse_id) REFERENCES warehouses(id) ON DELETE RESTRICT,
      UNIQUE (trip_id, revision_number)
    )
  ''');
  await db.execute('CREATE INDEX idx_car_revisions_trip_id ON car_revisions(trip_id)');
}

Future<void> _createRevisionItems(DatabaseExecutor db) async {
  if (!await _exists(db, 'car_revision_items')) return;
  await db.execute('''
    CREATE TABLE car_revision_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      revision_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      unit_price_minor INTEGER NOT NULL CHECK (unit_price_minor > 0),
      loaded_cartons INTEGER NOT NULL CHECK (loaded_cartons >= 0),
      returned_cartons INTEGER NOT NULL CHECK (returned_cartons >= 0),
      discount_percent REAL NOT NULL DEFAULT 0
        CHECK (discount_percent >= 0 AND discount_percent <= 100),
      FOREIGN KEY (revision_id) REFERENCES car_revisions(id) ON DELETE CASCADE,
      CHECK (returned_cartons <= loaded_cartons)
    )
  ''');
  await db.execute('CREATE INDEX idx_car_revision_items_revision_id ON car_revision_items(revision_id)');
}

Future<void> _createPaymentTransactions(DatabaseExecutor db) async {
  if (!await _exists(db, 'car_payment_transactions')) return;
  await db.execute('''
    CREATE TABLE car_payment_transactions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      cash_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (cash_amount_minor >= 0),
      transfer_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (transfer_amount_minor >= 0),
      reference TEXT,
      created_at TEXT NOT NULL,
      CHECK (cash_amount_minor + transfer_amount_minor > 0)
    )
  ''');
  await db.execute('CREATE INDEX idx_car_pmt_tx_created ON car_payment_transactions(created_at)');
}

Future<void> _createPaymentAllocations(DatabaseExecutor db) async {
  if (!await _exists(db, 'car_payment_allocations')) return;
  await db.execute('''
    CREATE TABLE car_payment_allocations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      payment_transaction_id INTEGER NOT NULL,
      trip_id INTEGER NOT NULL,
      cash_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (cash_amount_minor >= 0),
      transfer_amount_minor INTEGER NOT NULL DEFAULT 0 CHECK (transfer_amount_minor >= 0),
      FOREIGN KEY (payment_transaction_id)
        REFERENCES car_payment_transactions(id) ON DELETE CASCADE,
      FOREIGN KEY (trip_id) REFERENCES car_trips(id) ON DELETE CASCADE,
      UNIQUE (payment_transaction_id, trip_id),
      CHECK (cash_amount_minor + transfer_amount_minor > 0)
    )
  ''');
  await db.execute('CREATE INDEX idx_car_pmt_alloc_transaction ON car_payment_allocations(payment_transaction_id)');
  await db.execute('CREATE INDEX idx_car_pmt_alloc_trip ON car_payment_allocations(trip_id)');
}

Future<bool> _exists(DatabaseExecutor db, String tableName) async {
  final rows = await db.rawQuery('''
    SELECT name FROM sqlite_master
    WHERE type = 'table' AND name = ?
  ''', [tableName]);
  return rows.isNotEmpty;
}
