import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'app_migrations.dart';
import 'app_schema.dart';

/// Single SQLite database for the entire application.
///
/// Features own repositories/data sources, but database lifecycle, schema
/// creation, migrations, foreign-key configuration and reset are centralized
/// here.
class AppDatabase {
  AppDatabase._();

  static const databaseName = 'sales_erp.db';
  static const version = 12;

  static Database? _database;
  static Future<Database>? _opening;

  static Future<Database> get database async {
    final existing = _database;
    if (existing != null && existing.isOpen) return existing;

    final opening = _opening;
    if (opening != null) return opening;

    final future = _open();
    _opening = future;
    try {
      return await future;
    } finally {
      _opening = null;
    }
  }

  static Future<Database> _open() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, databaseName);

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
    final tables = await db.rawQuery('''
      SELECT name FROM sqlite_master
      WHERE type = 'table' AND name = 'invoice_changes'
    ''');
    if (tables.isEmpty) return;

    await db.delete(
      'invoice_changes',
      where: 'expires_at <= ?',
      whereArgs: [DateTime.now().toUtc().toIso8601String()],
    );
  }

  static Future<void> cleanupExpiredInvoiceChanges() async {
    await _cleanupExpiredInvoiceChanges(await database);
  }

  /// Development-only reset. Production flows should use explicit migrations.
  static Future<void> resetDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, databaseName);

    final existing = _database;
    _database = null;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    _opening = null;
    await deleteDatabase(path);
  }
}
