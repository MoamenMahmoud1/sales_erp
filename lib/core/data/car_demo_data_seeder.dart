import 'package:sqflite/sqflite.dart';

import '../../features/car/domain/entities/car_load_item.dart';
import '../../features/car/domain/entities/car_trip.dart';
import '../../features/car/domain/entities/money.dart';
import '../../features/car/domain/entities/sales_car.dart';
import '../../features/car/domain/entities/warehouse.dart';
import '../repositories/app_services.dart';
import '../storage/app_database.dart';

/// Seeds a small, believable Car dataset for fresh/demo installs.
///
/// Existing Car trips are never touched. The emptiness check is the source of
/// truth so the seeder is also safe to call on every application startup.
class CarDemoDataSeeder {
  Future<void> seedIfNeeded() async {
    final database = await AppDatabase.database;
    final existingTrips = await database.query(
      'car_trips',
      columns: ['id'],
      limit: 1,
    );
    if (existingTrips.isNotEmpty) return;

    await _ensureProducts(database);
    final catalog = AppServices.instance.carCatalogRepository;
    final cars = await catalog.getCars(activeOnly: true);
    final warehouses = await catalog.getWarehouses(activeOnly: true);

    final car = cars.isNotEmpty
        ? cars.first
        : await catalog.createCar(
            SalesCar(
              name: 'Route 01',
              plate: 'CAR-001',
              createdAt: DateTime.now().toUtc(),
            ),
          );
    final warehouse = warehouses.isNotEmpty
        ? warehouses.first
        : await catalog.createWarehouse(
            Warehouse(
              name: 'Main Warehouse',
              location: 'Main branch',
              createdAt: DateTime.now().toUtc(),
            ),
          );

    final productRows = await database.query(
      'products',
      columns: ['id', 'name', 'price', 'purchase_price'],
      orderBy: 'id ASC',
      limit: 3,
    );
    if (productRows.isEmpty) return;

    final now = DateTime.now();
    final dayStart = DateTime(now.year, now.month, now.day);
    final confirmedOpened = dayStart.add(const Duration(minutes: 30));
    final confirmedClosed = dayStart.add(const Duration(hours: 2));
    final draftOpened = dayStart.add(const Duration(hours: 3));

    final items = <CarLoadItem>[
      for (var i = 0; i < productRows.length && i < 2; i++)
        _item(
          productRows[i],
          loaded: i == 0 ? 20 : 12,
          returned: i == 0 ? 3 : 2,
        ),
    ];

    final repository = AppServices.instance.carTripRepository;
    await repository.createAndConfirmTrip(
      CarTrip(
        salesCarId: car.id,
        salesCarName: car.name,
        warehouseId: warehouse.id,
        warehouseName: warehouse.name,
        openedAt: confirmedOpened.toUtc(),
        closedAt: confirmedClosed.toUtc(),
        items: items,
        dueDate: dayStart.add(const Duration(days: 7)).toUtc(),
      ),
      triggeredBy: 'car_demo_seed',
    );

    await repository.createTrip(
      CarTrip(
        salesCarId: car.id,
        salesCarName: car.name,
        warehouseId: warehouse.id,
        warehouseName: warehouse.name,
        openedAt: draftOpened.toUtc(),
        items: [_item(productRows.first, loaded: 8)],
      ),
    );
  }

  CarLoadItem _item(
    Map<String, Object?> row, {
    required int loaded,
    int returned = 0,
  }) {
    final selling = (row['price'] as num?)?.toDouble() ?? 0;
    final storedPurchase = (row['purchase_price'] as num?)?.toDouble() ?? 0;
    final purchase = storedPurchase > 0 ? storedPurchase : selling * .8;

    return CarLoadItem(
      productId: (row['id'] as num).toInt(),
      productName: row['name'] as String,
      unitPrice: CarMoney.fromUnits(selling),
      purchasePrice: CarMoney.fromUnits(purchase),
      loadedCartons: loaded,
      returnedCartons: returned,
    );
  }

  Future<void> _ensureProducts(Database database) async {
    final count = Sqflite.firstIntValue(
          await database.rawQuery('SELECT COUNT(*) FROM products'),
        ) ??
        0;
    if (count > 0) return;

    final timestamp = DateTime.now().toUtc().toIso8601String();
    const products = [
      ('Sunflower Oil 5L', 320.0, 255.0),
      ('Basmati Rice 10kg', 540.0, 430.0),
      ('Granulated Sugar 25kg', 720.0, 575.0),
    ];

    for (final product in products) {
      await database.insert('products', {
        'name': product.$1,
        'category': 'Car Sales',
        'price': product.$2,
        'purchase_price': product.$3,
        'created_at': timestamp,
        'updated_at': timestamp,
      });
    }
  }
}
