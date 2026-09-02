import 'package:sqflite/sqflite.dart';

/// Keeps Car returned monetary values materialized in both fresh and
/// previously-created databases. Safe to run on every database open.
Future<void> ensureCarReturnedValueColumns(DatabaseExecutor db) async {
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

Future<void> _ensureColumn(
  DatabaseExecutor db,
  String table,
  String column,
  String definition,
) async {
  if (!await _tableExists(db, table)) return;
  final columns = await db.rawQuery('PRAGMA table_info($table)');
  final names = {for (final row in columns) row['name'] as String};
  if (names.contains(column)) return;
  await db.execute('ALTER TABLE $table ADD COLUMN $column $definition');
}

Future<bool> _tableExists(DatabaseExecutor db, String tableName) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [tableName],
  );
  return rows.isNotEmpty;
}
