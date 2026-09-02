import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'app_migrations.dart';
import 'app_schema.dart';

/// The application's single SQLite database.
///
/// Feature modules may own repositories and data sources, but database
/// lifecycle, migrations and fresh-install schema are centralized here.
class AppDatabase {
  AppDatabase._();

  static const databaseName = 'sales_erp.db';
  static const version = 12;

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
      onUpgrade: (db, oldVersion, _) => runAppMigrations(db, oldVersion),
    );

    _database = database;
    await _cleanupExpiredInvoiceChanges(database);
    return database;
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
  }
}
