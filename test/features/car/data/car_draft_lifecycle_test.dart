import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:sales_erp/core/storage/app_schema.dart';
import 'package:sales_erp/features/car/data/local_car_catalog_repository.dart';
import 'package:sales_erp/features/car/data/local_car_trip_command_repository.dart';
import 'package:sales_erp/features/car/domain/entities/car_load_item.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip_filter.dart';
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

  tearDown(() => database.close());

  Future<int> product(String name, double price) => database.insert('products', {
        'name': name,
        'price': price,
        'created_at': DateTime(2026, 1, 1).toIso8601String(),
        'updated_at': DateTime(2026, 1, 1).toIso8601String(),
      });

  test(
    'saving an edit as draft leaves the confirmed invoice unchanged until confirm',
    () async {
      final catalog = LocalCarCatalogRepository(database: () async => database);
      final repository = LocalCarTripCommandRepository(
        database: () async => database,
      );

      final productId = await product('Water', 100);
      final car = await catalog.createCar(
        SalesCar(name: 'Route 1', createdAt: DateTime(2026, 9, 2)),
      );
      final warehouse = await catalog.createWarehouse(
        Warehouse(name: 'Main', createdAt: DateTime(2026, 9, 2)),
      );

      final created = await repository.createTrip(
        CarTrip(
          salesCarId: car.id,
          salesCarName: car.name,
          warehouseId: warehouse.id,
          warehouseName: warehouse.name,
          openedAt: DateTime(2026, 9, 2, 9),
          items: [
            CarLoadItem(
              productId: productId,
              productName: 'Water',
              unitPrice: const CarMoney(10000),
              purchasePrice: const CarMoney(6000),
              loadedCartons: 10,
            ),
          ],
        ),
      );
      final confirmed = await repository.confirmTrip(created);
      final oldTotal = const CarMoney(100000);

      final editedDraft = await repository.updateDraft(
        confirmed.copyWith(
          items: [
            CarLoadItem(
              productId: productId,
              productName: 'Water',
              unitPrice: const CarMoney(10000),
              purchasePrice: const CarMoney(6000),
              loadedCartons: 14,
            ),
          ],
        ),
      );

      expect(editedDraft.status, CarTripStatus.open);
      expect(editedDraft.displayNumber, startsWith('DRAFT|'));
      expect(editedDraft.id, isNot(confirmed.id));

      final unchanged = await repository.getTripById(confirmed.id);
      expect(unchanged, isNotNull);
      expect(unchanged!.status, CarTripStatus.closed);
      expect(unchanged.items.single.loadedCartons, 10);

      final closedSummaries = await repository.getTripSummaries(
        filter: const CarTripFilter(status: CarTripStatus.closed),
      );
      expect(closedSummaries, hasLength(1));
      expect(closedSummaries.single.id, confirmed.id);
      expect(closedSummaries.single.totalLoadedCartons, 10);
      expect(closedSummaries.single.finalValue, oldTotal);

      final openSummaries = await repository.getTripSummaries(
        filter: const CarTripFilter(status: CarTripStatus.open),
      );
      expect(openSummaries, hasLength(1));
      expect(openSummaries.single.id, editedDraft.id);

      final finalized = await repository.confirmTrip(
        editedDraft,
        triggeredBy: 'draft_confirm_test',
      );

      expect(finalized.id, confirmed.id);
      expect(finalized.status, CarTripStatus.closed);
      expect(finalized.items.single.loadedCartons, 14);
      expect(finalized.closedAt, isNotNull);

      final replaced = await repository.getTripById(confirmed.id);
      expect(replaced, isNotNull);
      expect(replaced!.status, CarTripStatus.closed);
      expect(replaced.items.single.loadedCartons, 14);

      final deletedDraft = await repository.getTripById(editedDraft.id);
      expect(deletedDraft, isNull);

      final revisions = await repository.getRevisionsForTrip(confirmed.id);
      expect(revisions, hasLength(2));
      expect(revisions.first.items.single.loadedCartons, 10);
      expect(revisions.last.items.single.loadedCartons, 14);
    },
  );
}
