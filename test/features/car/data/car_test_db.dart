import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sales_erp/core/storage/car_tables.dart';

/// Companion to the persistence tests — builds a fresh SQLite database with
/// the Car schema (via [createCarTables]) and exposes a `Future<Database>`
/// provider for [`LocalCarRepository`].
class CarTestDb {
  Database? _db;
  final String _name;

  CarTestDb(this._name);

  Future<Database> open() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    _db = await databaseFactory.openDatabase(
      _name,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await createCarTables(db);
        },
      ),
    );
    return _db!;
  }

  /// Yields a provider that re-opens the DB lazily if needed.
  Future<Database> Function() get provider => () async {
        final existing = _db;
        if (existing != null && existing.isOpen) return existing;
        return open();
      };

  Future<Database?> close() async {
    final db = _db;
    _db = null;
    await db?.close();
    return null;
  }
}