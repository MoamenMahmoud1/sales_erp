import 'package:sqflite/sqflite.dart';

import 'car_tables.dart';

/// Fresh-install schema for the single application database.
///
/// Migrations for existing installations remain in [AppDatabase]. Keeping
/// fresh schema creation here prevents the database lifecycle class from
/// becoming a giant table-definition file.
Future<void> createAppSchema(DatabaseExecutor db) async {
  await db.execute('''
    CREATE TABLE customers (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      phone TEXT NOT NULL,
      address TEXT NOT NULL,
      payment_type TEXT NOT NULL DEFAULT 'cash'
    )
  ''');
  await db.execute('CREATE INDEX idx_customers_name ON customers(name)');
  await db.execute('CREATE INDEX idx_customers_phone ON customers(phone)');

  await db.execute('''
    CREATE TABLE products (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      price REAL NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_products_name ON products(name)');

  await db.execute('''
    CREATE TABLE invoices (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      subtotal REAL NOT NULL DEFAULT 0,
      coupon_discount REAL NOT NULL DEFAULT 0,
      total REAL NOT NULL DEFAULT 0,
      FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_invoices_customer_id ON invoices(customer_id)',
  );

  await db.execute('''
    CREATE TABLE invoice_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL CHECK (quantity >= 0),
      unit_price REAL NOT NULL DEFAULT 0,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_invoice_items_invoice_id ON invoice_items(invoice_id)',
  );
  await db.execute(
    'CREATE INDEX idx_invoice_items_product_id ON invoice_items(product_id)',
  );

  // Legacy short-lived change rows remain for compatibility. Real immutable
  // invoice revisions are handled by the invoice-revision migration/feature.
  await db.execute('''
    CREATE TABLE invoice_changes (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      product_id INTEGER NOT NULL,
      old_quantity INTEGER NOT NULL,
      new_quantity INTEGER NOT NULL,
      changed_at TEXT NOT NULL,
      expires_at TEXT NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_invoice_changes_expires_at ON invoice_changes(expires_at)',
  );

  await db.execute('''
    CREATE TABLE coupons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      pieces_per_coupon INTEGER NOT NULL,
      unit_price REAL NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL
    )
  ''');
  await db.execute('CREATE INDEX idx_coupons_name ON coupons(name)');

  await db.execute('''
    CREATE TABLE customer_coupons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL,
      coupon_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL CHECK (quantity >= 0),
      created_at TEXT NOT NULL,
      FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
      FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE CASCADE,
      UNIQUE(customer_id, coupon_id)
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_customer_coupons_customer_id ON customer_coupons(customer_id)',
  );
  await db.execute(
    'CREATE INDEX idx_customer_coupons_coupon_id ON customer_coupons(coupon_id)',
  );

  await db.execute('''
    CREATE TABLE invoice_coupons (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      coupon_id INTEGER NOT NULL,
      quantity INTEGER NOT NULL CHECK (quantity >= 0),
      unit_price REAL NOT NULL,
      total_value REAL NOT NULL,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE,
      FOREIGN KEY (coupon_id) REFERENCES coupons(id) ON DELETE RESTRICT
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_invoice_coupons_invoice_id ON invoice_coupons(invoice_id)',
  );

  await db.execute('''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      customer_id INTEGER NOT NULL,
      invoice_id INTEGER NOT NULL,
      amount REAL NOT NULL CHECK (amount >= 0),
      method TEXT NOT NULL,
      status TEXT NOT NULL,
      reference TEXT,
      created_at TEXT NOT NULL,
      confirmed_at TEXT,
      FOREIGN KEY (customer_id) REFERENCES customers(id) ON DELETE CASCADE,
      FOREIGN KEY (invoice_id) REFERENCES invoices(id) ON DELETE CASCADE
    )
  ''');
  await db.execute(
    'CREATE INDEX idx_payments_customer_id ON payments(customer_id)',
  );
  await db.execute(
    'CREATE INDEX idx_payments_invoice_id ON payments(invoice_id)',
  );
  await db.execute('CREATE INDEX idx_payments_status ON payments(status)');

  await createCarTables(db);
}
