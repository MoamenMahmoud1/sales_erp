import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sales_erp/core/storage/app_schema.dart';
import 'package:sales_erp/features/car/data/local_car_catalog_repository.dart';
import 'package:sales_erp/features/car/data/local_car_payment_repository.dart';
import 'package:sales_erp/features/car/data/local_car_trip_repository.dart';
import 'package:sales_erp/features/car/domain/entities/car_load_item.dart';
import 'package:sales_erp/features/car/domain/entities/car_payment.dart';
import 'package:sales_erp/features/car/domain/entities/car_payment_transaction.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip_status.dart';
import 'package:sales_erp/features/car/domain/entities/money.dart';
import 'package:sales_erp/features/car/domain/entities/sales_car.dart';
import 'package:sales_erp/features/car/domain/entities/warehouse.dart';
import 'package:sales_erp/features/car/domain/services/car_calculator.dart';
import 'package:sales_erp/features/car/domain/services/car_payment_allocator.dart';

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

  Future<int> product(String name, double price) => database.insert('products', {
        'name': name,
        'price': price,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'updated_at': DateTime(2026, 1, 1).toIso8601String(),
      });

  test('persists one Car trip, closes it, and preserves revision snapshot', () async {
    final productId = await product('Water', 100.0);
    final carRepo = LocalCarCatalogRepository(database: () async => database);
    final tripRepo = LocalCarTripRepository(database: () async => database);

    final car = await carRepo.createCar(
      SalesCar(name: 'Route 1', createdAt: DateTime(2026, 1, 1)),
    );
    final warehouse = await carRepo.createWarehouse(
      Warehouse(name: 'Main warehouse', createdAt: DateTime(2026, 1, 1)),
    );

    final trip = CarTrip(
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
          discountPercent: 5,
        ),
      ],
    );

    final draft = await tripRepo.createTrip(trip);
    expect(draft.id, greaterThan(0));
    expect(draft.displayNumber, startsWith('2026-'));

    final closed = await tripRepo.confirmTrip(draft);
    expect(closed.status, CarTripStatus.closed);
    expect(closed.closedAt, isNotNull);

    final stored = await tripRepo.getTripById(closed.id);
    expect(stored, isNotNull);
    expect(stored!.items.single.productName, 'Water');

    final revisions = await tripRepo.getRevisionsForTrip(closed.id);
    expect(revisions, hasLength(1));
    expect(revisions.single.salesCarName, 'Route 1');
    expect(revisions.single.warehouseName, 'Main warehouse');
    expect(revisions.single.items.single.productName, 'Water');
    expect(
      const CarCalculator().summary(closed).totalSoldCartons,
      8,
    );
  });

  test('persists payment transaction and allocations atomically', () async {
    final tripRepo = LocalCarTripRepository(database: () async => database);
    final paymentRepo = LocalCarPaymentRepository(database: () async => database);

    final car = await LocalCarCatalogRepository(database: () async => database).createCar(
      SalesCar(name: 'Route 1', createdAt: DateTime(2026, 1, 1)),
    );
    final warehouse = await LocalCarCatalogRepository(database: () async => database).createWarehouse(
      Warehouse(name: 'Main', createdAt: DateTime(2026, 1, 1)),
    );
    await product('Juice', 50);

    final first = await tripRepo.createTrip(CarTrip(
      salesCarId: car.id,
      salesCarName: car.name,
      warehouseId: warehouse.id,
      warehouseName: warehouse.name,
      openedAt: DateTime(2026, 1, 1),
      items: [
        const CarLoadItem(
          productId: 1,
          productName: 'Juice',
          unitPrice: CarMoney(5000),
          loadedCartons: 1,
        ),
      ],
    ));
    final second = await tripRepo.createTrip(CarTrip(
      salesCarId: car.id,
      salesCarName: car.name,
      warehouseId: warehouse.id,
      warehouseName: warehouse.name,
      openedAt: DateTime(2026, 1, 2),
      items: [
        const CarLoadItem(
          productId: 1,
          productName: 'Juice',
          unitPrice: CarMoney(7000),
          loadedCartons: 1,
        ),
      ],
    ));
    final closedFirst = await tripRepo.confirmTrip(first);
    final closedSecond = await tripRepo.confirmTrip(second);

    const allocator = CarPaymentAllocator();
    final payment = CarPaymentTransaction(
      cashAmount: CarMoney(12000),
      createdAt: DateTime(2026, 1, 3),
    );
    final plan = allocator.allocate(
      transaction: payment,
      trips: [closedSecond, closedFirst],
    );
    expect(plan.isFullyAllocated, isTrue);

    await paymentRepo.persistPayment(
      transaction: payment,
      allocations: plan.allocations,
      updatedTrips: plan.updatedTrips,
    );

    expect(await database.query('car_payment_transactions'), hasLength(1));
    expect(await database.query('car_payment_allocations'), hasLength(2));
  });
}
