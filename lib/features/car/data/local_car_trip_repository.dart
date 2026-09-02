import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_financial_summary.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_filter.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/repositories/car_trip_repository.dart';
import '../domain/services/car_calculator.dart';
import '../domain/services/car_payment_evaluator.dart';
import '../domain/services/display_number.dart';
import 'car_mappers.dart';

/// Local trip persistence backed by the application's single AppDatabase.
/// List reads use compact summary rows; child items are batch-loaded only for
/// callers that explicitly request full trip details.
class LocalCarTripRepository implements CarTripRepository {
  LocalCarTripRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database);

  final Future<Database> Function() _database;
  static const _calculator = CarCalculator();
  static const _evaluator = CarPaymentEvaluator();
  static const _displayNumbers = CarDisplayNumber();
  static const _mappers = CarMappers();

  @override
  Future<CarTrip> createTrip(CarTrip trip) async {
    _ensureOpen(trip);
    final db = await _database();
    return db.transaction((txn) async => _insertTrip(txn, trip));
  }

  @override
  Future<CarTrip> createAndConfirmTrip(
    CarTrip trip, {
    String? triggeredBy,
  }) async {
    if (trip.id != 0) {
      throw ArgumentError('A new Car trip cannot already have an id.');
    }
    if (trip.status != CarTripStatus.open) {
      throw ArgumentError('A new Car trip must start open.');
    }

    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) throw ArgumentError(issues.first.message);

    final now = DateTime.now().toUtc();
    final finalized = trip.copyWith(
      status: CarTripStatus.closed,
      closedAt: trip.closedAt ?? now,
    );
    final summary = _calculator.summary(finalized);

    final db = await _database();
    return db.transaction((txn) async {
      final saved = await _insertTrip(
        txn,
        finalized,
        summary: summary,
      );
      await _insertRevision(
        txn,
        _revisionFrom(
          saved,
          revisionNumber: 1,
          triggeredBy: triggeredBy,
        ),
      );
      return saved;
    });
  }

  @override
  Future<CarTrip> updateDraft(CarTrip trip) async {
    if (trip.id <= 0) throw ArgumentError('A saved trip must have an id.');
    _ensureOpen(trip);
    final issues = _calculator.validate(trip);
    // Empty drafts are allowed; validation becomes mandatory on confirmation.
    final blocking =
        issues.where((issue) => issue.message.contains('cannot')).toList();
    if (blocking.isNotEmpty) throw ArgumentError(blocking.first.message);

    final db = await _database();
    final summary = _calculator.summary(trip);

    return db.transaction((txn) async {
      final updated = await txn.update(
        'car_trips',
        _mappers.tripToRow(trip, summary, updatedAt: DateTime.now())
          ..remove('created_at'),
        where: 'id = ? AND status = ?',
        whereArgs: [trip.id, CarTripStatus.open.value],
      );
      if (updated == 0) throw StateError('Open car trip was not found.');

      await txn.delete(
        'car_trip_items',
        where: 'trip_id = ?',
        whereArgs: [trip.id],
      );
      await _insertItems(txn, trip.id, trip.items);
      return trip;
    });
  }

  @override
  Future<CarTrip> confirmTrip(
    CarTrip trip, {
    String? triggeredBy,
  }) async {
    if (trip.id <= 0) throw ArgumentError('A saved trip must have an id.');
    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) throw ArgumentError(issues.first.message);

    final db = await _database();
    final now = DateTime.now().toUtc();
    final finalized = trip.copyWith(
      status: CarTripStatus.closed,
      closedAt: trip.closedAt ?? now,
    );
    final summary = _calculator.summary(finalized);

    final dbTotalPaid = trip.payment.totalPaid;
    if (dbTotalPaid > summary.finalTotalSoldValue) {
      throw StateError(
        'A Car invoice cannot be confirmed with payments above its final value.',
      );
    }

    return db.transaction((txn) async {
      final updated = await txn.update(
        'car_trips',
        _mappers.tripToRow(finalized, summary, updatedAt: now)
          ..remove('created_at'),
        where: 'id = ? AND status = ?',
        whereArgs: [trip.id, CarTripStatus.open.value],
      );
      if (updated == 0) {
        throw StateError('Only an open car trip can be confirmed.');
      }

      await txn.delete('car_trip_items', where: 'trip_id = ?', whereArgs: [trip.id]);
      await _insertItems(txn, trip.id, finalized.items);

      final latest = await txn.query(
        'car_revisions',
        columns: ['revision_number'],
        where: 'trip_id = ?',
        whereArgs: [trip.id],
        orderBy: 'revision_number DESC',
        limit: 1,
      );
      final revisionNumber = latest.isEmpty
          ? 1
          : (latest.first['revision_number'] as int) + 1;

      await _insertRevision(
        txn,
        _revisionFrom(
          finalized,
          revisionNumber: revisionNumber,
          triggeredBy: triggeredBy,
        ),
      );
      return finalized;
    });
  }

  @override
  Future<CarTrip> reviseClosedTrip(
    CarTrip trip, {
    String? triggeredBy,
  }) async {
    if (trip.id <= 0) throw ArgumentError('A saved trip must have an id.');
    if (!trip.isClosed) {
      throw StateError('Only a closed car trip can be revised.');
    }

    final issues = _calculator.validate(trip);
    if (issues.isNotEmpty) throw ArgumentError(issues.first.message);

    final now = DateTime.now().toUtc();
    final revised = trip.copyWith(
      status: CarTripStatus.closed,
      closedAt: trip.closedAt ?? now,
    );
    final summary = _calculator.summary(revised);

    if (revised.payment.totalPaid > summary.finalTotalSoldValue) {
      throw StateError(
        'A closed Car invoice cannot be revised below the amount already paid.',
      );
    }

    final db = await _database();
    return db.transaction((txn) async {
      final updated = await txn.update(
        'car_trips',
        _mappers.tripToRow(revised, summary, updatedAt: now)
          ..remove('created_at'),
        where: 'id = ? AND status = ?',
        whereArgs: [trip.id, CarTripStatus.closed.value],
      );
      if (updated == 0) {
        throw StateError('Only a closed car trip can be revised.');
      }

      await txn.delete('car_trip_items', where: 'trip_id = ?', whereArgs: [trip.id]);
      await _insertItems(txn, trip.id, revised.items);

      final latest = await txn.query(
        'car_revisions',
        columns: ['revision_number'],
        where: 'trip_id = ?',
        whereArgs: [trip.id],
        orderBy: 'revision_number DESC',
        limit: 1,
      );
      final revisionNumber = latest.isEmpty
          ? 1
          : (latest.first['revision_number'] as int) + 1;
      await _insertRevision(
        txn,
        _revisionFrom(
          revised,
          revisionNumber: revisionNumber,
          triggeredBy: triggeredBy,
        ),
      );
      return revised;
    });
  }

  @override
  Future<CarTrip?> getTripById(int tripId) async {
    final db = await _database();
    final rows = await db.query(
      'car_trips',
      where: 'id = ?',
      whereArgs: [tripId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await _loadItems(db, [tripId]);
    return _mappers.tripFromRow(rows.first, items[tripId] ?? const []);
  }

  @override
  Future<CarTrip?> getTripByDisplayNumber(String displayNumber) async {
    final db = await _database();
    final rows = await db.query(
      'car_trips',
      where: 'display_number = ?',
      whereArgs: [displayNumber],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final id = rows.first['id'] as int;
    final items = await _loadItems(db, [id]);
    return _mappers.tripFromRow(rows.first, items[id] ?? const []);
  }

  @override
  Future<List<CarTrip>> getTrips({CarTripFilter? filter}) async {
    final summaries = await getTripSummaries(filter: filter);
    if (summaries.isEmpty) return const [];
    final db = await _database();
    final ids = summaries.map((summary) => summary.id).toList(growable: false);
    final itemsByTrip = await _loadItems(db, ids);
    final rows = await db.query(
      'car_trips',
      where: 'id IN (${List.filled(ids.length, '?').join(',')})',
      whereArgs: ids,
    );
    final byId = {for (final row in rows) row['id'] as int: row};
    return [
      for (final summary in summaries)
        _mappers.tripFromRow(
          byId[summary.id]!,
          itemsByTrip[summary.id] ?? const [],
        ),
    ];
  }

  @override
  Future<List<CarTripSummaryView>> getTripSummaries({CarTripFilter? filter}) async {
    final db = await _database();
    final (where, args) = _buildWhere(filter);
    final rows = await db.query(
      'car_trips',
      where: where.isEmpty ? null : where,
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'opened_at DESC',
    );
    final now = DateTime.now();
    return rows
        .map(_mappers.tripSummaryFromRow)
        .where((view) =>
            filter?.paymentStatus == null ||
            view.paymentStatus(_evaluator, now) == filter!.paymentStatus)
        .toList(growable: false);
  }

  @override
  Future<List<CarRevision>> getRevisionsForTrip(int tripId) async {
    final db = await _database();
    final rows = await db.query(
      'car_revisions',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'revision_number ASC',
    );
    if (rows.isEmpty) return const [];
    final ids = rows.map((row) => row['id'] as int).toList(growable: false);
    final itemsByRevision = await _loadRevisionItems(db, ids);
    return rows
        .map(
          (row) => _mappers.revisionFromRow(
            row,
            itemsByRevision[row['id'] as int] ?? const [],
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<CarRevision?> getRevision(int revisionId) async {
    final db = await _database();
    final rows = await db.query(
      'car_revisions',
      where: 'id = ?',
      whereArgs: [revisionId],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final items = await _loadRevisionItems(db, [revisionId]);
    return _mappers.revisionFromRow(
      rows.first,
      items[revisionId] ?? const [],
    );
  }

  Future<CarTrip> _insertTrip(
    Transaction txn,
    CarTrip trip, {
    CarFinancialSummary? summary,
  }) async {
    final calculated = summary ?? _calculator.summary(trip);
    final placeholder = 'pending-${DateTime.now().microsecondsSinceEpoch}';
    final draft = trip.copyWith(displayNumber: placeholder);
    final now = DateTime.now().toUtc();
    final id = await txn.insert(
      'car_trips',
      _mappers.tripToRow(draft, calculated, updatedAt: now),
    );
    final displayNumber = _displayNumbers.create(
      year: draft.openedAt.year,
      sequence: id,
    );
    await txn.update(
      'car_trips',
      {'display_number': displayNumber},
      where: 'id = ?',
      whereArgs: [id],
    );
    await _insertItems(txn, id, draft.items);
    return draft.copyWith(id: id, displayNumber: displayNumber);
  }

  void _ensureOpen(CarTrip trip) {
    if (trip.status != CarTripStatus.open) {
      throw StateError('Only open car trips can be created or edited.');
    }
  }

  Future<void> _insertItems(
    Transaction txn,
    int tripId,
    List<CarLoadItem> items,
  ) async {
    for (final item in items) {
      await txn.insert('car_trip_items', _mappers.itemToRow(item, tripId));
    }
  }

  Future<void> _insertRevision(Transaction txn, CarRevision revision) async {
    final id = await txn.insert(
      'car_revisions',
      _mappers.revisionToRow(revision),
    );
    for (final item in revision.items) {
      await txn.insert(
        'car_revision_items',
        _mappers.revisionItemToRow(item, id),
      );
    }
  }

  CarRevision _revisionFrom(
    CarTrip trip, {
    required int revisionNumber,
    String? triggeredBy,
  }) =>
      CarRevision(
        tripId: trip.id,
        displayNumber: trip.displayNumber,
        revisionNumber: revisionNumber,
        createdAt: DateTime.now().toUtc(),
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

  Future<Map<int, List<CarLoadItem>>> _loadItems(
    DatabaseExecutor db,
    List<int> tripIds,
  ) async {
    if (tripIds.isEmpty) return const {};
    final placeholders = List.filled(tripIds.length, '?').join(',');
    final rows = await db.query(
      'car_trip_items',
      where: 'trip_id IN ($placeholders)',
      whereArgs: tripIds,
      orderBy: 'id ASC',
    );
    final result = <int, List<CarLoadItem>>{};
    for (final row in rows) {
      final id = row['trip_id'] as int;
      (result[id] ??= <CarLoadItem>[]).add(_mappers.itemFromRow(row));
    }
    return result;
  }

  Future<Map<int, List<CarLoadItem>>> _loadRevisionItems(
    DatabaseExecutor db,
    List<int> revisionIds,
  ) async {
    if (revisionIds.isEmpty) return const {};
    final placeholders = List.filled(revisionIds.length, '?').join(',');
    final rows = await db.query(
      'car_revision_items',
      where: 'revision_id IN ($placeholders)',
      whereArgs: revisionIds,
      orderBy: 'id ASC',
    );
    final result = <int, List<CarLoadItem>>{};
    for (final row in rows) {
      final id = row['revision_id'] as int;
      (result[id] ??= <CarLoadItem>[]).add(_mappers.itemFromRow(row));
    }
    return result;
  }

  (String, List<Object?>) _buildWhere(CarTripFilter? filter) {
    if (filter == null || filter.isEmpty) return ('', const []);
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
      clauses.add('opened_at < ?');
      args.add(filter.to!.toUtc().add(const Duration(days: 1)).toIso8601String());
    }
    final query = filter.query?.trim();
    if (query != null && query.isNotEmpty) {
      final pattern = '%$query%';
      clauses.add(
        '(display_number LIKE ? OR sales_car_name LIKE ? OR warehouse_name LIKE ?)',
      );
      args.addAll([pattern, pattern, pattern]);
    }
    return (clauses.join(' AND '), args);
  }
}
