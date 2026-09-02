import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/sales_car.dart';
import '../domain/entities/warehouse.dart';
import '../domain/repositories/car_catalog_repository.dart';
import 'car_mappers.dart';

/// SQLite-backed Car and warehouse catalog repository.
class LocalCarCatalogRepository implements CarCatalogRepository {
  LocalCarCatalogRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database);

  final Future<Database> Function() _database;
  static const _mappers = CarMappers();

  @override
  Future<SalesCar> createCar(SalesCar car) async {
    final db = await _database();
    final id = await db.insert('sales_cars', _mappers.salesCarToInsertRow(car));
    return car.copyWith(id: id);
  }

  @override
  Future<List<SalesCar>> getCars({bool activeOnly = false}) async {
    final db = await _database();
    final rows = await db.query(
      'sales_cars',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_mappers.salesCarFromRow).toList(growable: false);
  }

  @override
  Future<Warehouse> createWarehouse(Warehouse warehouse) async {
    final db = await _database();
    final id = await db.insert(
      'warehouses',
      _mappers.warehouseToInsertRow(warehouse),
    );
    return warehouse.copyWith(id: id);
  }

  @override
  Future<List<Warehouse>> getWarehouses({bool activeOnly = false}) async {
    final db = await _database();
    final rows = await db.query(
      'warehouses',
      where: activeOnly ? 'is_active = ?' : null,
      whereArgs: activeOnly ? [1] : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows.map(_mappers.warehouseFromRow).toList(growable: false);
  }
}
