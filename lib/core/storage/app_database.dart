import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart' as legacy_sqflite;
import 'package:sqflite_sqlcipher/sqflite.dart' as cipher;

import 'app_latest_migrations.dart';
import 'app_migrations.dart';
import 'app_schema.dart';

class AppDatabase {
  AppDatabase._();

  static const databaseName = 'sales_erp.db';
  static const version = 18;
  static const _keyName = 'sales_erp_sqlcipher_key_v1';

  static cipher.Database? _database;
  static Future<cipher.Database>? _opening;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  static Future<cipher.Database> get database async {
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

  static Future<cipher.Database> _open() async {
    final root = await legacy_sqflite.getDatabasesPath();
    final path = join(root, databaseName);
    final key = await _databaseKey();

    final database = await _openEncrypted(path, key);
    await _cleanupPlaintextBackup(path);
    _database = database;
    await _cleanupExpiredInvoiceChanges(database);
    return database;
  }

  static Future<void> _cleanupPlaintextBackup(String path) async {
    final backup = File('$path.plaintext-migration');
    if (await backup.exists()) await backup.delete();
  }

  static Future<String> _databaseKey() async {
    final existing = await _secureStorage.read(key: _keyName);
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64Url.encode(bytes);
    await _secureStorage.write(key: _keyName, value: key);
    return key;
  }

  static Future<cipher.Database> _openEncrypted(String path, String key) async {
    try {
      return await cipher.openDatabase(
        path,
        password: key,
        version: version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) => createAppSchema(db),
        onUpgrade: (db, oldVersion, _) async {
          await runAppMigrations(db, oldVersion);
          await runLatestMigrations(db, oldVersion);
        },
      );
    } catch (error) {
      if (!await _isPlaintextSqliteFile(path)) rethrow;
      return _migratePlaintextDatabase(path, key, originalError: error);
    }
  }

  static Future<bool> _isPlaintextSqliteFile(String path) async {
    final file = File(path);
    if (!await file.exists()) return false;
    final handle = await file.open();
    try {
      final bytes = await handle.read(16);
      const header = 'SQLite format 3\u0000';
      if (bytes.length != header.length) return false;
      return utf8.decode(bytes, allowMalformed: true) == header;
    } finally {
      await handle.close();
    }
  }

  static Future<cipher.Database> _migratePlaintextDatabase(
    String path,
    String key, {
    required Object originalError,
  }) async {
    final sourcePath = '$path.plaintext-migration';
    final sourceFile = File(path);
    final sourceBackup = File(sourcePath);
    cipher.Database? target;
    if (await sourceBackup.exists()) {
      throw StateError(
        'A previous plaintext database migration is incomplete. '
        'Manual recovery is required before opening the application: $originalError',
      );
    }

    await sourceFile.rename(sourcePath);
    try {
      target = await cipher.openDatabase(
        path,
        password: key,
        version: version,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = OFF');
        },
        onCreate: (db, _) => createAppSchema(db),
        onUpgrade: (db, oldVersion, _) async {
          await runAppMigrations(db, oldVersion);
          await runLatestMigrations(db, oldVersion);
        },
      );
      final source = await legacy_sqflite.openDatabase(sourcePath, readOnly: true);
      try {
        await _copySharedTables(source, target);
      } finally {
        await source.close();
      }
      await target.execute('PRAGMA foreign_keys = ON');
      final violations = await target.rawQuery('PRAGMA foreign_key_check');
      if (violations.isNotEmpty) {
        throw StateError('Encrypted local database migration produced foreign key violations.');
      }
      await sourceBackup.delete();
      return target;
    } catch (error) {
      try {
        final encrypted = File(path);
        if (target != null && target!.isOpen) await target!.close();
        if (await encrypted.exists()) await encrypted.delete();
      } catch (_) {}
      await sourceBackup.rename(path);
      Error.throwWithStackTrace(error, StackTrace.current);
    }
  }

  static Future<void> _copySharedTables(
    legacy_sqflite.Database source,
    cipher.Database target,
  ) async {
    final sourceRows = await source.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final targetRows = await target.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' AND name NOT LIKE 'sqlite_%' ORDER BY name",
    );
    final sourceTables = sourceRows.map((row) => row['name'] as String).toSet();
    final targetTables = targetRows.map((row) => row['name'] as String).toSet();

    await target.transaction((txn) async {
      for (final table in targetTables.intersection(sourceTables)) {
        final sourceColumns = await source.rawQuery('PRAGMA table_info($table)');
        final targetColumns = await txn.rawQuery('PRAGMA table_info($table)');
        final sourceNames = sourceColumns.map((row) => row['name'] as String).toSet();
        final columns = targetColumns
            .map((row) => row['name'] as String)
            .where(sourceNames.contains)
            .toList();
        if (columns.isEmpty) continue;

        final rows = await source.query(table, columns: columns);
        if (rows.isEmpty) continue;

        final batch = txn.batch();
        for (final row in rows) {
          batch.insert(
            table,
            {for (final column in columns) column: row[column]},
            conflictAlgorithm: cipher.ConflictAlgorithm.replace,
          );
        }
        await batch.commit(noResult: true);
      }
    });
  }

  static Future<void> _cleanupExpiredInvoiceChanges(cipher.Database db) async {
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

  static Future<void> resetDatabase() async {
    final root = await getDatabasesPath();
    final path = join(root, databaseName);
    final existing = _database;

    _database = null;
    _opening = null;
    if (existing != null && existing.isOpen) {
      await existing.close();
    }
    await legacy_sqflite.deleteDatabase(path);
    final backup = File('$path.plaintext-migration');
    if (await backup.exists()) await backup.delete();
    await _secureStorage.delete(key: _keyName);
    await database;
  }
}
