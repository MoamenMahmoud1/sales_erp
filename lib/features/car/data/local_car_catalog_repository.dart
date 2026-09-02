import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/sales_car.dart';
import '../domain/entities/warehouse.dart';
import '../domain/repositories/car_catalog_repository.dart';

class LocalCarCatalogRepository implements CarCatalogRepository {
  final Future<Database> Function() _database;

  LocalCarCatalogRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database);

  @override
  Future<SalesCar> createCar(SalesCar car) async {
    final db = await _database();
    final id = await db.insert('sales_cars', {
      'name': car.name.trim(),
      'plate': car.plate.trim(),
      'is_active': car.isActive ? 1 : 0,
      'created_at': car.createdAt.toUtc().toIso8601String(),
    });
    return car.copyWith(id: id);
  }

  @override
  Future<List<SalesCar>> getCars({bool activeOnly = false}) async {
    final db = await _database();
    final rows = await db.query(
      'sales_cars',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => SalesCar(
            id: row['id'] as int,
            name: row['name'] as String,
            plate: (row['plate'] as String?) ?? '',
            isActive: (row['is_active'] as int?) != 0,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<Warehouse> createWarehouse(Warehouse warehouse) async {
    final db = await _database();
    final id = await db.insert('warehouses', {
      'name': warehouse.name.trim(),
      'location': warehouse.location?.trim(),
      'is_active': warehouse.isActive ? 1 : 0,
      'created_at': warehouse.createdAt.toUtc().toIso8601String(),
    });
    return warehouse.copyWith(id: id);
  }

  @override
  Future<List<Warehouse>> getWarehouses({bool activeOnly = false}) async {
    final db = await _database();
    final rows = await db.query(
      'warehouses',
      where: activeOnly ? 'is_active = 1' : null,
      orderBy: 'name COLLATE NOCASE ASC',
    );
    return rows
        .map(
          (row) => Warehouse(
            id: row['id'] as int,
            name: row['name'] as String,
            location: row['location'] as String?,
            isActive: (row['is_active'] as int?) != 0,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList(growable: false);
  }
}
