import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'app_migrations.dart';
import 'app_schema.dart';
import 'car_return_value_migration.dart';
import 'payment_date_migration.dart';

/// The application's single SQLite database.
class AppDatabase {
  AppDatabase._();

  static const databaseName = 'sales_erp.db';
  static const version = 17;

  static Database? _database;
  static Future<Database>? _opening;

  static Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final inFlight = _opening;
    if (inFlight != null) return inFlight;

    final future = _open();
    _opening = future;
    try {
      return await future;
    } finally {
      _opening = null;
    }
  }

  static Future<Database> _open() async {
    final root = await getDatabasesPath();
    final path = join(root, databaseName);

    final database = await openDatabase(
      path,
      version: version,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, _) => createAppSchema(db),
      onUpgrade: (db, oldVersion, _) async {
        await runAppMigrations(db, oldVersion);
        await runPaymentDateMigration(db, oldVersion);
      },
    );

    // Version 16 adds product categories. Keep this tiny compatibility step
    // here so databases upgraded from any previous schema get the new column
    // even though older installations may have skipped intermediate versions.
    await _ensureProductCategoryColumn(database);
    await ensureCarReturnedValueColumns(database);
    _database = database;
    await _cleanupExpiredInvoiceChanges(database);
    return database;
  }

  static Future<void> _ensureProductCategoryColumn(Database db) async {
    final rows = await db.rawQuery('PRAGMA table_info(products)');
    final columns = {for (final row in rows) row['name'] as String};
    if (columns.contains('category')) return;

    await db.transaction((txn) async {
      await txn.execute(
        "ALTER TABLE products ADD COLUMN category TEXT NOT NULL DEFAULT 'General'",
      );
      await txn.execute(
        "UPDATE products SET category = 'General' WHERE TRIM(COALESCE(category, '')) = ''",
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_products_category ON products(category)',
      );
    });
  }

  static Future<void> _cleanupExpiredInvoiceChanges(Database db) async {
    final rows = await db.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type = 'table' AND name = 'invoice_changes'
    ''');
    if (rows.isEmpty) return;

    await db.delete(
      'invoice_changes',
      where: 'expires_at <= ?',
      whereArgs: [DateTime.now().toUtc().toIso8601String()],
    );
  }

  static Future<void> cleanupExpiredInvoiceChanges() async {
    await _cleanupExpiredInvoiceChanges(await database);
  }

  /// Development-only reset. Normal application flows must use migrations.
  static Future<void> resetDatabase() async {
    final root = await getDatabasesPath();
    final path = join(root, databaseName);
    final existing = _database;

    _database = null;
    _opening = null;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    await deleteDatabase(path);
    await database;
  }
}
