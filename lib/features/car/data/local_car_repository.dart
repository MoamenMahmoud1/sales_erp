import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_financial_summary.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_payment_status.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_filter.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/entities/money.dart';
import '../domain/services/car_calculator.dart';
import '../domain/services/car_payment_evaluator.dart';
import '../domain/repositories/car_trip_repository.dart';
import 'car_mappers.dart';

/// Local persistence for the Car trip aggregate.
class LocalCarTripRepository implements CarTripRepository {
  LocalCarTripRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database);

  final Future<Database> Function() _database;
  static const _mappers = CarMappers();
  static const _calculator = CarCalculator();
  static const _evaluator = CarPaymentEvaluator();

  @override
  Future<List<CarTrip>> getTrips({CarTripFilter? filter}) async {
    final db = await _database();
    final (where, args) = _buildWhere(filter);
    final rows = await db.query(
      'car_trips',
      where: where.isEmpty ? null : where,
      whereArgs: args,
      orderBy: 'opened_at DESC, id DESC',
    );
    final trips = <CarTrip>[];
    for (final row in rows) {
      trips.add(await _loadTripWithItems(db, row));
    }
    return List.unmodifiable(trips);
  }

  @override
  Future<CarTrip?> getTripById(int id) async {
    final db = await _database();
    final rows = await db.query('car_trips', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return _loadTripWithItems(db, rows.first);
  }

  @override
  Future<List<CarTripSummaryView>> getTripSummaries({CarTripFilter? filter}) async {
    final db = await _database();
    final (where, args) = _buildWhere(filter);
    final rows = await db.query(
      'car_trips',
      where: where.isEmpty ? null : where,
      whereArgs: args,
      orderBy: 'opened_at DESC, id DESC',
    );
    return rows.map(_mappers.tripSummaryFromRow).toList(growable: false);
  }

  @override
  Future<CarTrip> createDraft(CarTrip trip) async {
    if (trip.items.isEmpty) throw StateError('A Car trip must contain at least one product.');
    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) throw StateError(issues.first.message);
    final db = await _database();
    return db.transaction((txn) async {
      final now = DateTime.now().toUtc();
      final displayNumber = trip.displayNumber.isEmpty
          ? await _nextDisplayNumber(txn, now.year)
          : trip.displayNumber;
      final normalized = trip.copyWith(
        displayNumber: displayNumber,
        status: trip.status,
      );
      final summary = _calculator.summary(normalized);
      final id = await txn.insert(
        'car_trips',
        _mappers.tripToRow(normalized, summary, updatedAt: now),
      );
      for (final item in normalized.items) {
        await txn.insert('car_trip_items', _mappers.itemToRow(item, id));
      }
      return normalized.copyWith(id: id, displayNumber: displayNumber);
    });
  }

  @override
  Future<CarTrip> updateDraft(CarTrip trip) async {
    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) throw StateError(issues.first.message);
    final db = await _database();
    return db.transaction((txn) async {
      final current = await txn.query('car_trips', where: 'id = ?', whereArgs: [trip.id], limit: 1);
      if (current.isEmpty) throw StateError('Car invoice not found.');
      if ((current.first['status'] as String?) == 'closed') {
        throw StateError('Closed Car invoices must be revised, not overwritten.');
      }
      final now = DateTime.now().toUtc();
      final summary = _calculator.summary(trip);
      await txn.update(
        'car_trips',
        _mappers.tripToRow(trip, summary, updatedAt: now),
        where: 'id = ? AND status = ?',
        whereArgs: [trip.id, 'open'],
      );
      await txn.delete('car_trip_items', where: 'trip_id = ?', whereArgs: [trip.id]);
      for (final item in trip.items) {
        await txn.insert('car_trip_items', _mappers.itemToRow(item, trip.id));
      }
      return trip.copyWith(status: trip.status);
    });
  }

  @override
  Future<CarTrip> confirmTrip(CarTrip trip, {String? triggeredBy}) async {
    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) throw StateError(issues.first.message);
    final db = await _database();
    return db.transaction((txn) async {
      final currentRows = await txn.query('car_trips', where: 'id = ?', whereArgs: [trip.id], limit: 1);
      if (currentRows.isEmpty) throw StateError('Car invoice not found.');
      final current = await _loadTripWithItems(txn, currentRows.first);
      if (current.isClosed) return current;
      final now = DateTime.now().toUtc();
      final closed = trip.copyWith(status: current.status, closedAt: trip.closedAt ?? now);
      final finalTrip = closed.copyWith(status: current.status == current.status ? current.status : closed.status);
      final confirmed = finalTrip.copyWith(status: current.status == CarTripStatus.closed ? CarTripStatus.closed : CarTripStatus.closed);
      final summary = _calculator.summary(confirmed);
      await txn.update(
        'car_trips',
        {
          ..._mappers.tripToRow(confirmed, summary, updatedAt: now),
          'status': CarTripStatus.closed.value,
          'closed_at': (confirmed.closedAt ?? now).toUtc().toIso8601String(),
        },
        where: 'id = ? AND status = ?',
        whereArgs: [trip.id, CarTripStatus.open.value],
      );
      final stored = confirmed.copyWith(status: CarTripStatus.closed, closedAt: confirmed.closedAt ?? now);
      final revisionNumber = await _nextRevisionNumber(txn, trip.id);
      await _insertRevision(txn, _revisionFrom(stored, revisionNumber, triggeredBy, createdAt: now));
      return stored;
    });
  }

  @override
  Future<CarTrip> reviseClosedTrip(CarTrip trip, {String? triggeredBy}) async {
    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) throw StateError(issues.first.message);
    final db = await _database();
    return db.transaction((txn) async {
      final currentRows = await txn.query('car_trips', where: 'id = ?', whereArgs: [trip.id], limit: 1);
      if (currentRows.isEmpty) throw StateError('Car invoice not found.');
      final current = await _loadTripWithItems(txn, currentRows.first);
      if (!current.isClosed) throw StateError('Only closed Car invoices can be revised.');
      final now = DateTime.now().toUtc();
      final revised = trip.copyWith(status: CarTripStatus.closed, closedAt: trip.closedAt ?? now);
      final summary = _calculator.summary(revised);
      await txn.update(
        'car_trips',
        _mappers.tripToRow(revised, summary, updatedAt: now),
        where: 'id = ?',
        whereArgs: [trip.id],
      );
      await txn.delete('car_trip_items', where: 'trip_id = ?', whereArgs: [trip.id]);
      for (final item in revised.items) {
        await txn.insert('car_trip_items', _mappers.itemToRow(item, trip.id));
      }
      final revisionNumber = await _nextRevisionNumber(txn, trip.id);
      await _insertRevision(txn, _revisionFrom(revised, revisionNumber, triggeredBy, createdAt: now));
      return revised;
    });
  }

  @override
  Future<List<CarRevision>> getRevisions(int tripId) async {
    final db = await _database();
    final rows = await db.query('car_revisions', where: 'trip_id = ?', whereArgs: [tripId], orderBy: 'revision_number DESC');
    final revisions = <CarRevision>[];
    for (final row in rows) {
      revisions.add(_mappers.revisionFromRow(row, await _loadRevisionItems(db, row['id'] as int)));
    }
    return List.unmodifiable(revisions);
  }

  @override
  Future<CarTotals> getTotals({CarTripFilter? filter}) async {
    final views = await getTripSummaries(filter: filter);
    final now = DateTime.now();
    var loaded = 0, returned = 0, sold = 0;
    var returnedValue = 0;
    var gross = 0, productDiscount = 0, subtotalAfter = 0, globalDiscount = 0, finalValue = 0, paid = 0, remaining = 0;
    var openCount = 0, closedCount = 0;
    var paidCount = 0, partialCount = 0, unpaidCount = 0, overdueCount = 0;

    for (final view in views) {
      loaded += view.totalLoadedCartons;
      returned += view.totalReturnedCartons;
      returnedValue += view.totalReturnedValue.minorUnits;
      sold += view.totalSoldCartons;
      gross += view.grossSubtotal.minorUnits;
      productDiscount += view.productDiscountTotal.minorUnits;
      subtotalAfter += view.subtotalAfterProducts.minorUnits;
      globalDiscount += view.globalDiscountAmount.minorUnits;
      finalValue += view.finalValue.minorUnits;
      paid += view.paidTotal.minorUnits;
      remaining += view.remaining.minorUnits;
      if (view.status.value == CarTripStatus.closed.value) {
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
      totalReturnedValue: CarMoney(returnedValue),
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

  Future<CarTrip> _loadTripWithItems(DatabaseExecutor db, Map<String, Object?> row) async {
    final itemRows = await db.query('car_trip_items', where: 'trip_id = ?', whereArgs: [row['id']], orderBy: 'id ASC');
    return _mappers.tripFromRow(row, itemRows.map(_mappers.itemFromRow).toList(growable: false));
  }

  Future<List<CarLoadItem>> _loadRevisionItems(DatabaseExecutor db, int revisionId) async {
    final rows = await db.query('car_revision_items', where: 'revision_id = ?', whereArgs: [revisionId], orderBy: 'id ASC');
    return rows.map(_mappers.itemFromRow).toList(growable: false);
  }

  (String, List<Object?>) _buildWhere(CarTripFilter? filter) {
    if (filter == null || filter.isEmpty) return ('', const []);
    final clauses = <String>[];
    final args = <Object?>[];
    if (filter.status != null) { clauses.add('status = ?'); args.add(filter.status!.value); }
    if (filter.carId != null) { clauses.add('sales_car_id = ?'); args.add(filter.carId); }
    if (filter.warehouseId != null) { clauses.add('warehouse_id = ?'); args.add(filter.warehouseId); }
    if (filter.from != null) { clauses.add('opened_at >= ?'); args.add(filter.from!.toUtc().toIso8601String()); }
    if (filter.to != null) { clauses.add('opened_at <= ?'); args.add(filter.to!.toUtc().toIso8601String()); }
    final query = filter.query?.trim();
    if (query != null && query.isNotEmpty) { final q = '%$query%'; clauses.add('(display_number LIKE ? OR sales_car_name LIKE ? OR warehouse_name LIKE ?)'); args.addAll([q, q, q]); }
    return (clauses.join(' AND '), args);
  }

  Future<int> _nextRevisionNumber(DatabaseExecutor db, int tripId) async {
    final rows = await db.rawQuery('SELECT COALESCE(MAX(revision_number), 0) AS n FROM car_revisions WHERE trip_id = ?', [tripId]);
    return ((rows.first['n'] as num?)?.toInt() ?? 0) + 1;
  }

  Future<String> _nextDisplayNumber(DatabaseExecutor db, int year) async {
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM car_trips WHERE display_number LIKE ?', ['$year-%']);
    final next = ((rows.first['n'] as num?)?.toInt() ?? 0) + 1;
    return '$year-${next.toString().padLeft(6, '0')}';
  }

  Future<void> _insertRevision(DatabaseExecutor txn, CarRevision r) async {
    final id = await txn.insert('car_revisions', _mappers.revisionToRow(r));
    for (final item in r.items) {
      await txn.insert('car_revision_items', _mappers.revisionItemToRow(item, id));
    }
  }

  CarRevision _revisionFrom(CarTrip trip, int revisionNumber, String? triggeredBy, {required DateTime createdAt}) {
    return CarRevision(
      tripId: trip.id,
      displayNumber: trip.displayNumber,
      revisionNumber: revisionNumber,
      createdAt: createdAt,
      triggeredBy: triggeredBy,
      salesCarId: trip.salesCarId,
      salesCarName: trip.salesCarName,
      warehouseId: trip.warehouseId,
      warehouseName: trip.warehouseName,
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
