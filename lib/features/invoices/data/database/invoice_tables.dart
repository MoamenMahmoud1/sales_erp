// Invoice Tables


class InvoiceTables {
  static const String invoices = '''
    CREATE TABLE invoices (
      id INTEGER PRIMARY KEY,
      customer_id INTEGER NOT NULL,
      created_at TEXT NOT NULL,
      updated_at TEXT NOT NULL,
      paid_at TEXT,
      coupon_id INTEGER
    )
  ''';

  static const String invoiceItems = '''
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
  ''';

  static const String payments = '''
    CREATE TABLE payments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      invoice_id INTEGER NOT NULL,
      cash_amount INTEGER NOT NULL,
      transfer_amount INTEGER NOT NULL,

      FOREIGN KEY (invoice_id)
        REFERENCES invoices(id)
        ON DELETE CASCADE
    )
  ''';
}

