import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

import 'package:sales_erp/core/storage/app_schema.dart';
import 'package:sales_erp/features/car/data/local_car_catalog_repository.dart';
import 'package:sales_erp/features/car/data/local_car_trip_repository.dart';
import 'package:sales_erp/features/car/domain/entities/car_load_item.dart';
import 'package:sales_erp/features/car/domain/entities/car_payment.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip_status.dart';
import 'package:sales_erp/features/car/domain/entities/money.dart';
import 'package:sales_erp/features/car/domain/entities/sales_car.dart';
import 'package:sales_erp/features/car/domain/entities/warehouse.dart';

void main() {
  late Database database;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    database = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, _) async => createAppSchema(db),
      ),
    );
  });

  tearDown(() async {
    await database.close();
  });

  Future<int> product(String name, double price) => database.insert(
        'products',
        {
          'name': name,
          'price': price,
          'created_at': DateTime(2026, 1, 1).toIso8601String(),
          'updated_at': DateTime(2026, 1, 1).toIso8601String(),
        },
      );

  Future<(SalesCar, Warehouse)> catalog() async {
    final repo = LocalCarCatalogRepository(database: () async => database);
    final car = await repo.createCar(
      SalesCar(name: 'Route 1', createdAt: DateTime(2026, 1, 1)),
    );
    final warehouse = await repo.createWarehouse(
      Warehouse(name: 'Main warehouse', createdAt: DateTime(2026, 1, 1)),
    );
    return (car, warehouse);
  }

  test('new confirmed trip is persisted atomically as one closed invoice', () async {
    final productId = await product('Water', 100);
    final (car, warehouse) = await catalog();
    final repo = LocalCarTripRepository(database: () async => database);

    final created = await repo.createAndConfirmTrip(
      CarTrip(
        salesCarId: car.id,
        salesCarName: car.name,
        warehouseId: warehouse.id,
        warehouseName: warehouse.name,
        openedAt: DateTime(2026, 1, 2),
        items: [
          CarLoadItem(
            productId: productId,
            productName: 'Water',
            unitPrice: CarMoney.fromUnits(100),
            loadedCartons: 10,
            returnedCartons: 2,
          ),
        ],
      ),
      triggeredBy: 'invoice_close',
    );

    expect(created.id, greaterThan(0));
    expect(created.status, CarTripStatus.closed);
    expect(await database.query('car_trips'), hasLength(1));
    expect(
      (await database.query('car_trips')).single['status'],
      CarTripStatus.closed.value,
    );
    expect(await database.query('car_revisions'), hasLength(1));
    expect(
      (await database.query('car_revisions')).single['revision_number'],
      1,
    );
  });

  test('revision rejects a final value below money already paid', () async {
    final productId = await product('Juice', 10);
    final (car, warehouse) = await catalog();
    final repo = LocalCarTripRepository(database: () async => database);

    final closed = await repo.createAndConfirmTrip(
      CarTrip(
        salesCarId: car.id,
        salesCarName: car.name,
        warehouseId: warehouse.id,
        warehouseName: warehouse.name,
        openedAt: DateTime(2026, 1, 2),
        items: [
          CarLoadItem(
            productId: productId,
            productName: 'Juice',
            unitPrice: CarMoney.fromUnits(10),
            loadedCartons: 100,
          ),
        ],
      ),
    );

    final revisedAttempt = closed.copyWith(
      payment: const CarPayment(cashAmount: CarMoney.fromUnits(1000)),
      items: [
        CarLoadItem(
          productId: productId,
          productName: 'Juice',
          unitPrice: CarMoney.fromUnits(9),
          loadedCartons: 100,
        ),
      ],
    );

    await expectLater(
      repo.reviseClosedTrip(revisedAttempt, triggeredBy: 'invoice_edit'),
      throwsA(isA<StateError>()),
    );

    final stored = await repo.getTripById(closed.id);
    expect(stored, isNotNull);
    expect(stored!.payment.totalPaid, CarMoney.zero);
    expect(stored.items.single.unitPrice, CarMoney.fromUnits(10));
    expect(await repo.getRevisionsForTrip(closed.id), hasLength(1));
  });

  test('revision preserves the original product snapshot after catalog price changes', () async {
    final productId = await product('Water', 100);
    final (car, warehouse) = await catalog();
    final repo = LocalCarTripRepository(database: () async => database);

    final closed = await repo.createAndConfirmTrip(
      CarTrip(
        salesCarId: car.id,
        salesCarName: car.name,
        warehouseId: warehouse.id,
        warehouseName: warehouse.name,
        openedAt: DateTime(2026, 1, 2),
        items: [
          CarLoadItem(
            productId: productId,
            productName: 'Water',
            unitPrice: CarMoney.fromUnits(100),
            loadedCartons: 10,
          ),
        ],
      ),
    );

    await database.update(
      'products',
      {
        'name': 'Water Premium',
        'price': 150.0,
        'updated_at': DateTime(2026, 1, 3).toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [productId],
    );

    final unchanged = await repo.getTripById(closed.id);
    expect(unchanged, isNotNull);
    expect(unchanged!.items.single.productName, 'Water');
    expect(unchanged.items.single.unitPrice, CarMoney.fromUnits(100));

    final revisions = await repo.getRevisionsForTrip(closed.id);
    expect(revisions, hasLength(1));
    expect(revisions.single.items.single.productName, 'Water');
    expect(revisions.single.items.single.unitPrice, CarMoney.fromUnits(100));
  });
}
