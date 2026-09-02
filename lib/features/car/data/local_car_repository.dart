import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_payment_allocation.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_payment_status.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_totals.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_filter.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/entities/money.dart';
import '../domain/entities/sales_car.dart';
import '../domain/entities/warehouse.dart';
import '../domain/repositories/car_repository.dart';
import '../domain/services/car_calculator.dart';
import '../domain/services/car_payment_evaluator.dart';
import 'car_mappers.dart';

/// SQLite-backed [CarRepository].
///
/// The database provider is injectable so tests can point it at a temp
/// database while the app uses the shared [AppDatabase]. All business math is
/// delegated to the domain calculators; this layer only maps results to/from
/// rows.
class LocalCarRepository implements CarRepository {
  final Future<Database> Function() _database;
  final CarMappers _mappers = const CarMappers();
  static const CarCalculator _calculator = CarCalculator();
  static const CarPaymentEvaluator _evaluator = CarPaymentEvaluator();

  LocalCarRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database);

  // ---------------------------------------------------------------
  // Cars & warehouses
  // ---------------------------------------------------------------

  @override
  Future<SalesCar> saveCar(SalesCar car) async {
    final db = await _database();
    final id = await db.insert('sales_cars', _mappers.salesCarToInsertRow(car));
    return car.copyWith(id: id);
  }

  @override
  Future<List<SalesCar>> getCars() async {
    final db = await _database();
    final rows =
        await db.query('sales_cars', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(_mappers.salesCarFromRow).toList(growable: false);
  }

  @override
  Future<Warehouse> saveWarehouse(Warehouse warehouse) async {
    final db = await _database();
    final id =
        await db.insert('warehouses', _mappers.warehouseToInsertRow(warehouse));
    return warehouse.copyWith(id: id);
  }

  @override
  Future<List<Warehouse>> getWarehouses() async {
    final db = await _database();
    final rows =
        await db.query('warehouses', orderBy: 'name COLLATE NOCASE ASC');
    return rows.map(_mappers.warehouseFromRow).toList(growable: false);
  }

  // ---------------------------------------------------------------
  // Trips
  // ---------------------------------------------------------------

  @override
  Future<CarTrip> createTrip(CarTrip trip) async {
    final db = await _database();
    final summary = _calculator.summary(trip);
    return db.transaction((txn) async {
      final id = await txn.insert(
        'car_trips',
        _mappers.tripToRow(trip, summary, updatedAt: DateTime.now()),
      );
      for (final item in trip.items) {
        await txn.insert('car_trip_items', _mappers.itemToRow(item, id));
      }
      return trip.copyWith(id: id);
    });
  }

  @override
  Future<CarTrip> updateTrip(CarTrip trip) async {
    final db = await _database();
    final summary = _calculator.summary(trip);
    return db.transaction((txn) async {
      final row = _mappers.tripToRow(trip, summary, updatedAt: DateTime.now())
        ..remove('created_at');
      await txn.update('car_trips', row,
          where: 'id = ?', whereArgs: [trip.id]);
      await txn.delete('car_trip_items',
          where: 'trip_id = ?', whereArgs: [trip.id]);
      for (final item in trip.items) {
        await txn.insert('car_trip_items', _mappers.itemToRow(item, trip.id));
      }
      return trip;
    });
  }
@override
  Future<CarTrip> confirmTrip(
    CarTrip trip, {
    required int revisionNumber,
    String? triggeredBy,
  }) async {
    final db = await _database();
    final summary = _calculator.summary(trip);
    return db.transaction((txn) async {
      final row = _mappers.tripToRow(trip, summary, updatedAt: DateTime.now())
        ..remove('created_at');
      await txn.update('car_trips', row,
          where: 'id = ?', whereArgs: [trip.id]);
      await txn.delete('car_trip_items',
          where: 'trip_id = ?', whereArgs: [trip.id]);
      for (final item in trip.items) {
        await txn.insert('car_trip_items', _mappers.itemToRow(item, trip.id));
      }
      await _insertRevision(
        txn,
        _revisionFrom(trip, revisionNumber, triggeredBy,
            createdAt: trip.closedAt ?? DateTime.now()),
      );
      return trip;
    });
  }

  @override
  Future<void> saveRevision(
    CarTrip trip, {
    required int revisionNumber,
    String? triggeredBy,
  }) async {
    final db = await _database();
    await db.transaction((txn) async {
      await _insertRevision(
        txn,
        _revisionFrom(trip, revisionNumber, triggeredBy,
            createdAt: DateTime.now()),
      );
    });
  }

  // ---------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------

  @override
  Future<CarTrip?> getTripById(int tripId) async {
    final db = await _database();
    final rows = await db.query('car_trips',
        where: 'id = ?', whereArgs: [tripId], limit: 1);
    if (rows.isEmpty) return null;
    return _loadTripWithItems(db, rows.first);
  }

  @override
  Future<CarTrip?> getTripByDisplayNumber(String displayNumber) async {
    final db = await _database();
    final rows = await db.query('car_trips',
        where: 'display_number = ?',
        whereArgs: [displayNumber],
        limit: 1);
    if (rows.isEmpty) return null;
    return _loadTripWithItems(db, rows.first);
  }

  @override
  Future<List<CarTrip>> getTrips({CarTripFilter? filter}) async {
    final db = await _database();
    final (where, args) = _buildWhere(filter);
    final now = DateTime.now();
    final rows = await db.query('car_trips',
        where: where.isEmpty ? null : where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'opened_at DESC');
    final trips = <CarTrip>[];
    for (final row in rows) {
      final trip = await _loadTripWithItems(db, row);
      if (filter?.paymentStatus != null) {
        final summary = _calculator.summary(trip);
        if (_evaluator.statusOf(trip, summary, now) !=
            filter!.paymentStatus) {
          continue;
        }
      }
      trips.add(trip);
    }
    return trips;
  }

  @override
  Future<List<CarTripSummaryView>> getTripSummaries(
      {CarTripFilter? filter}) async {
    final db = await _database();
    final (where, args) = _buildWhere(filter);
    final now = DateTime.now();
    final rows = await db.query('car_trips',
        where: where.isEmpty ? null : where,
        whereArgs: args.isEmpty ? null : args,
        orderBy: 'opened_at DESC');
    final views = <CarTripSummaryView>[];
    for (final row in rows) {
      final view = _mappers.tripSummaryFromRow(row);
      if (filter?.paymentStatus != null &&
          view.paymentStatus(_evaluator, now) != filter!.paymentStatus) {
        continue;
      }
      views.add(view);
    }
    return views;
  }

  @override
  Future<List<CarRevision>> getRevisionsForTrip(int tripId) async {
    final db = await _database();
    final rows = await db.query('car_revisions',
        where: 'trip_id = ?',
        whereArgs: [tripId],
        orderBy: 'revision_number ASC');
    final revisions = <CarRevision>[];
    for (final row in rows) {
      final items = await _loadRevisionItems(db, row['id'] as int);
      revisions.add(_mappers.revisionFromRow(row, items));
    }
    return revisions;
  }

  @override
  Future<CarRevision?> getRevision(int revisionId) async {
    final db = await _database();
    final rows = await db.query('car_revisions',
        where: 'id = ?', whereArgs: [revisionId], limit: 1);
    if (rows.isEmpty) return null;
    final items = await _loadRevisionItems(db, rows.first['id'] as int);
    return _mappers.revisionFromRow(rows.first, items);
  }

  // ---------------------------------------------------------------
  // Payments
  // ---------------------------------------------------------------

  @override
  Future<void> persistPaymentAllocation({
    required CarPaymentTransaction transaction,
    required List<CarPaymentAllocation> allocations,
    required List<CarTrip> updatedTrips,
  }) async {
    final db = await _database();
    await db.transaction((txn) async {
      final txnId = await txn.insert(
        'car_payment_transactions',
        _mappers.paymentTransactionToRow(transaction),
      );
      for (final allocation in allocations) {
        await txn.insert(
          'car_payment_allocations',
          _mappers.allocationToRow(allocation, txnId),
        );
      }
      final now = DateTime.now().toUtc().toIso8601String();
      for (final trip in updatedTrips) {
        await txn.update(
          'car_trips',
          {
            'paid_cash_minor': trip.payment.cashAmount.minorUnits,
            'paid_transfer_minor': trip.payment.transferAmount.minorUnits,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [trip.id],
        );
      }
    });
  }

  @override
  Future<List<CarPaymentTransaction>> getPaymentTransactions() async {
    final db = await _database();
    final rows =
        await db.query('car_payment_transactions', orderBy: 'created_at DESC');
    return rows
        .map(_mappers.paymentTransactionFromRow)
        .toList(growable: false);
  }

  @override
  Future<List<CarPaymentAllocation>> getAllocationsForTransaction(
      int transactionId) async {
    final db = await _database();
    final rows = await db.query('car_payment_allocations',
        where: 'payment_transaction_id = ?', whereArgs: [transactionId]);
    return rows.map(_mappers.allocationFromRow).toList(growable: false);
  }

  @override
  Future<List<CarPaymentAllocation>> getAllocationsForTrip(int tripId) async {
    final db = await _database();
    final rows = await db.query('car_payment_allocations',
        where: 'trip_id = ?', whereArgs: [tripId]);
    return rows.map(_mappers.allocationFromRow).toList(growable: false);
  }
// ---------------------------------------------------------------
  // Reporting
  // ---------------------------------------------------------------

  @override
  Future<CarTotals> computeTotals() async {
    final db = await _database();
    final now = DateTime.now();
    final rows = await db.query('car_trips');

    var loaded = 0, returned = 0, sold = 0;
    var gross = 0,
        productDiscount = 0,
        subtotalAfter = 0,
        globalDiscount = 0,
        finalValue = 0,
        paid = 0,
        remaining = 0;
    var openCount = 0, closedCount = 0;
    var paidCount = 0, partialCount = 0, unpaidCount = 0, overdueCount = 0;

    for (final row in rows) {
      final view = _mappers.tripSummaryFromRow(row);
      loaded += view.totalLoadedCartons;
      returned += view.totalReturnedCartons;
      sold += view.totalSoldCartons;
      gross += view.grossSubtotal.minorUnits;
      productDiscount += view.productDiscountTotal.minorUnits;
      subtotalAfter += view.subtotalAfterProducts.minorUnits;
      globalDiscount += view.globalDiscountAmount.minorUnits;
      finalValue += view.finalValue.minorUnits;
      paid += view.paidTotal.minorUnits;
      remaining += view.remaining.minorUnits;
      if (view.status.value == 'closed') {
        closedCount++;
      } else {
        openCount++;
      }
      switch (view.paymentStatus(_evaluator, now)) {
        case CarPaymentStatus.paid:
          paidCount++;
          break;
        case CarPaymentStatus.partiallyPaid:
          partialCount++;
          break;
        case CarPaymentStatus.unpaid:
          unpaidCount++;
          break;
        case CarPaymentStatus.overdue:
          overdueCount++;
          break;
      }
    }

    return CarTotals(
      totalLoadedCartons: loaded,
      totalReturnedCartons: returned,
      totalSoldCartons: sold,
      grossSubtotal: CarMoney(gross),
      productDiscountTotal: CarMoney(productDiscount),
      subtotalAfterProducts: CarMoney(subtotalAfter),
      globalDiscountAmount: CarMoney(globalDiscount),
      finalValue: CarMoney(finalValue),
      totalPaid: CarMoney(paid),
      totalRemaining: CarMoney(remaining),
      openCount: openCount,
      closedCount: closedCount,
      paidCount: paidCount,
      partiallyPaidCount: partialCount,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
    );
  }

  // ---------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------

  Future<CarTrip> _loadTripWithItems(
      DatabaseExecutor db, Map<String, Object?> row) async {
    final itemRows = await db.query('car_trip_items',
        where: 'trip_id = ?', whereArgs: [row['id']], orderBy: 'id ASC');
    final items = itemRows.map(_mappers.itemFromRow).toList(growable: false);
    return _mappers.tripFromRow(row, items);
  }

  Future<List<CarLoadItem>> _loadRevisionItems(
      DatabaseExecutor db, int revisionId) async {
    final rows = await db.query('car_revision_items',
        where: 'revision_id = ?', whereArgs: [revisionId], orderBy: 'id ASC');
    return rows.map(_mappers.itemFromRow).toList(growable: false);
  }

  (String, List<Object?>) _buildWhere(CarTripFilter? filter) {
    if (filter == null || filter.isEmpty) {
      return ('', const []);
    }
    final clauses = <String>[];
    final args = <Object?>[];
    if (filter.status != null) {
      clauses.add('status = ?');
      args.add(filter.status!.value);
    }
    if (filter.carId != null) {
      clauses.add('sales_car_id = ?');
      args.add(filter.carId);
    }
    if (filter.warehouseId != null) {
      clauses.add('warehouse_id = ?');
      args.add(filter.warehouseId);
    }
    if (filter.from != null) {
      clauses.add('opened_at >= ?');
      args.add(filter.from!.toUtc().toIso8601String());
    }
    if (filter.to != null) {
      clauses.add('opened_at <= ?');
      args.add(filter.to!.toUtc().toIso8601String());
    }
    final query = filter.query?.trim();
    if (query != null && query.isNotEmpty) {
      final q = '%$query%';
      clauses.add('(display_number LIKE ? OR sales_car_name LIKE ?)');
      args.addAll([q, q]);
    }
    return (clauses.join(' AND '), args);
  }

  Future<void> _insertRevision(DatabaseExecutor txn, CarRevision r) async {
    final id = await txn.insert('car_revisions', _mappers.revisionToRow(r));
    for (final item in r.items) {
      await txn.insert(
          'car_revision_items', _mappers.revisionItemToRow(item, id));
    }
  }

  CarRevision _revisionFrom(
    CarTrip trip,
    int revisionNumber,
    String? triggeredBy, {
    required DateTime createdAt,
  }) {
    return CarRevision(
      tripId: trip.id,
      displayNumber: trip.displayNumber,
      revisionNumber: revisionNumber,
      createdAt: createdAt,
      triggeredBy: triggeredBy,
      status: trip.status,
      openedAt: trip.openedAt,
      closedAt: trip.closedAt,
      dueDate: trip.dueDate,
      items: trip.items,
      globalDiscountPercent: trip.globalDiscountPercent,
      payment: trip.payment,
    );
  }
}