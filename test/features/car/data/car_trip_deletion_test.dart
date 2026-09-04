import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sales_erp/core/storage/app_schema.dart';
import 'package:sales_erp/features/car/data/local_car_catalog_repository.dart';
import 'package:sales_erp/features/car/data/local_car_payment_repository.dart';
import 'package:sales_erp/features/car/data/local_car_trip_command_repository.dart';
import 'package:sales_erp/features/car/domain/entities/car_load_item.dart';
import 'package:sales_erp/features/car/domain/entities/car_payment_allocation.dart';
import 'package:sales_erp/features/car/domain/entities/car_payment_transaction.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip.dart';
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

  tearDown(() async => database.close());

  Future<int> product() => database.insert('products', {
        'name': 'Water',
        'price': 100.0,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'updated_at': DateTime(2026, 1, 1).toIso8601String(),
      });

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

  Future<CarTrip> trip({required int productId, required SalesCar car, required Warehouse warehouse, required DateTime openedAt}) {
    final repo = LocalCarTripCommandRepository(database: () async => database);
    return repo.createAndConfirmTrip(
      CarTrip(
        salesCarId: car.id,
        salesCarName: car.name,
        warehouseId: warehouse.id,
        warehouseName: warehouse.name,
        openedAt: openedAt,
        items: [
          CarLoadItem(
            productId: productId,
            productName: 'Water',
            unitPrice: CarMoney.fromUnits(100),
            purchasePrice: CarMoney.fromUnits(100),
            loadedCartons: 1,
          ),
        ],
      ),
    );
  }

  test('deleting a paid trip removes its linked payment and restores shared trip balances', () async {
    final productId = await product();
    final (car, warehouse) = await catalog();
    final repo = LocalCarTripCommandRepository(database: () async => database);
    final payments = LocalCarPaymentRepository(database: () async => database);

    final first = await trip(
      productId: productId,
      car: car,
      warehouse: warehouse,
      openedAt: DateTime(2026, 9, 2, 9),
    );
    final second = await trip(
      productId: productId,
      car: car,
      warehouse: warehouse,
      openedAt: DateTime(2026, 9, 2, 10),
    );

    final transactionId = await payments.persistPayment(
      transaction: CarPaymentTransaction(
        createdAt: DateTime(2026, 9, 2, 12).toUtc(),
        cashAmount: CarMoney.fromUnits(150),
      ),
      allocations: [
        CarPaymentAllocation(
          transactionId: 0,
          tripId: first.id,
          cashAmount: CarMoney.fromUnits(100),
        ),
        CarPaymentAllocation(
          transactionId: 0,
          tripId: second.id,
          cashAmount: CarMoney.fromUnits(50),
        ),
      ],
      updatedTrips: [
        first.copyWith(payment: CarPayment(cashAmount: CarMoney.fromUnits(100))),
        second.copyWith(payment: CarPayment(cashAmount: CarMoney.fromUnits(50))),
      ],
    );

    expect(transactionId, greaterThan(0));
    expect(await payments.getAllocationsForTrip(first.id), hasLength(1));
    expect(await payments.getAllocationsForTrip(second.id), hasLength(1));

    final result = await repo.deleteTrip(first.id);

    expect(result.deletedTripId, first.id);
    expect(result.deletedPaymentTransactionIds, contains(transactionId));
    expect(result.recalculatedTrips.map((trip) => trip.id), contains(second.id));
    expect(await repo.getTripById(first.id), isNull);
    expect((await repo.getTripById(second.id))!.payment.totalPaid, CarMoney.zero);
    expect(await database.query('car_revisions'), hasLength(1));
    expect(await database.query('car_trip_items'), hasLength(1));
    expect(await payments.getTransactions(), isEmpty);
    expect(await payments.getAllocations(), isEmpty);
  });
}
