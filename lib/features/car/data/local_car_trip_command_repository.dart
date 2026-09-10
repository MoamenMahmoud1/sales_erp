import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_revision.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_deletion_result.dart';
import '../domain/entities/car_trip_filter.dart';
import '../domain/entities/car_trip_summary_view.dart';
import '../domain/repositories/car_trip_command_repository.dart';
import '../domain/services/car_calculator.dart';
import 'car_mappers.dart';
import 'local_car_trip_repository.dart';

/// Local write-side repository for Car trips.
///
/// Read/persistence primitives stay in LocalCarTripRepository. This class
/// composes that repository and owns only command-specific lifecycle rules.
class LocalCarTripCommandRepository implements CarTripCommandRepository {
  LocalCarTripCommandRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database),
        _reads = LocalCarTripRepository(database: database);

  final Future<Database> Function() _database;
  final LocalCarTripRepository _reads;
  static const _mappers = CarMappers();
  static const _calculator = CarCalculator();
  static const _draftPrefix = 'DRAFT|';

  @override
  Future<CarTrip> createTrip(CarTrip trip) => _reads.createTrip(trip);

  @override
  Future<CarTrip?> getTripById(int tripId) => _reads.getTripById(tripId);

  @override
  Future<CarTrip?> getTripByDisplayNumber(String displayNumber) =>
      _reads.getTripByDisplayNumber(displayNumber);

  @override
  Future<List<CarTrip>> getTrips({CarTripFilter? filter}) =>
      _reads.getTrips(filter: filter);

  @override
  Future<List<CarTripSummaryView>> getTripSummaries({CarTripFilter? filter}) =>
      _reads.getTripSummaries(filter: filter);

  @override
  Future<List<CarRevision>> getRevisionsForTrip(int tripId) =>
      _reads.getRevisionsForTrip(tripId);

  @override
  Future<CarRevision?> getRevision(int revisionId) =>
      _reads.getRevision(revisionId);

  @override
  Future<CarTripDeletionResult> deleteTrip(int tripId) async {
    if (tripId <= 0) throw ArgumentError('Invalid Car trip ID.');

    final db = await _database();
    return db.transaction((txn) async {
      final tripRows = await txn.query(
        'car_trips',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [tripId],
        limit: 1,
      );
      if (tripRows.isEmpty) throw StateError('Car trip $tripId was not found.');

      final transactionRows = await txn.rawQuery('''
        SELECT DISTINCT payment_transaction_id
        FROM car_payment_allocations
        WHERE trip_id = ?
        ORDER BY payment_transaction_id ASC
      ''', [tripId]);

      final deletedTransactionIds = <int>[];
      final recalculatedTripIds = <int>{};

      for (final transactionRow in transactionRows) {
        final transactionId =
            (transactionRow['payment_transaction_id'] as num).toInt();
        deletedTransactionIds.add(transactionId);

        final allocations = await txn.query(
          'car_payment_allocations',
          columns: ['trip_id', 'cash_amount_minor', 'transfer_amount_minor'],
          where: 'payment_transaction_id = ?',
          whereArgs: [transactionId],
          orderBy: 'id ASC',
        );

        for (final allocation in allocations) {
          final affectedTripId = (allocation['trip_id'] as num).toInt();
          if (affectedTripId == tripId) continue;

          final cash = (allocation['cash_amount_minor'] as num).toInt();
          final transfer =
              (allocation['transfer_amount_minor'] as num).toInt();
          final affectedRows = await txn.query(
            'car_trips',
            columns: ['paid_cash_minor', 'paid_transfer_minor'],
            where: 'id = ?',
            whereArgs: [affectedTripId],
            limit: 1,
          );
          if (affectedRows.isEmpty) {
            throw StateError(
              'Car trip $affectedTripId referenced by payment $transactionId was not found.',
            );
          }

          final currentCash =
              (affectedRows.single['paid_cash_minor'] as num).toInt();
          final currentTransfer =
              (affectedRows.single['paid_transfer_minor'] as num).toInt();
          if (currentCash < cash || currentTransfer < transfer) {
            throw StateError(
              'Cannot delete trip $tripId because payment $transactionId is no longer consistent.',
            );
          }

          final changed = await txn.update(
            'car_trips',
            {
              'paid_cash_minor': currentCash - cash,
              'paid_transfer_minor': currentTransfer - transfer,
              'updated_at': DateTime.now().toUtc().toIso8601String(),
            },
            where: 'id = ? AND paid_cash_minor = ? AND paid_transfer_minor = ?',
            whereArgs: [affectedTripId, currentCash, currentTransfer],
          );
          if (changed != 1) {
            throw StateError(
              'Car trip $affectedTripId changed while deleting trip $tripId.',
            );
          }
          recalculatedTripIds.add(affectedTripId);
        }

        await txn.delete(
          'car_payment_transactions',
          where: 'id = ?',
          whereArgs: [transactionId],
        );
      }

      final deleted = await txn.delete(
        'car_trips',
        where: 'id = ?',
        whereArgs: [tripId],
      );
      if (deleted != 1) {
        throw StateError('Car trip $tripId could not be deleted.');
      }

      final recalculatedTrips = <CarTrip>[];
      for (final affectedTripId in recalculatedTripIds) {
        final row = await txn.query(
          'car_trips',
          where: 'id = ?',
          whereArgs: [affectedTripId],
          limit: 1,
        );
        if (row.isEmpty) continue;

        final itemRows = await txn.query(
          'car_trip_items',
          where: 'trip_id = ?',
          whereArgs: [affectedTripId],
          orderBy: 'id ASC',
        );
        final items = <CarLoadItem>[
          for (final itemRow in itemRows) _mappers.itemFromRow(itemRow),
        ];
        recalculatedTrips.add(_mappers.tripFromRow(row.single, items));
      }

      return CarTripDeletionResult(
        deletedTripId: tripId,
        deletedPaymentTransactionIds: List.unmodifiable(deletedTransactionIds),
        recalculatedTrips: List.unmodifiable(recalculatedTrips),
      );
    });
  }

  @override
  Future<CarTrip> updateDraft(CarTrip trip) async {
    if (trip.id <= 0) return _reads.updateDraft(trip);

    final db = await _database();
    final rows = await db.query(
      'car_trips',
      columns: ['id', 'display_number', 'status'],
      where: 'id = ?',
      whereArgs: [trip.id],
      limit: 1,
    );
    if (rows.isEmpty) throw StateError('Car trip ${trip.id} was not found.');

    final status = rows.single['status'] as String?;
    final displayNumber = rows.single['display_number'] as String? ?? '';

    if (status == 'closed' && !displayNumber.startsWith(_draftPrefix)) {
      return _saveRevisionDraft(trip, sourceDisplayNumber: displayNumber);
    }
    return _reads.updateDraft(trip);
  }

  Future<CarTrip> _saveRevisionDraft(
    CarTrip trip, {
    required String sourceDisplayNumber,
  }) async {
    final draftDisplayNumber = '$_draftPrefix$sourceDisplayNumber';
    final draft = trip.copyWith(
      id: 0,
      displayNumber: draftDisplayNumber,
      status: CarTripStatus.open,
      closedAt: null,
    );
    final summary = _calculator.summary(draft);
    final db = await _database();

    return db.transaction((txn) async {
      final existing = await txn.query(
        'car_trips',
        columns: ['id'],
        where: 'display_number = ?',
        whereArgs: [draftDisplayNumber],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final draftId = (existing.single['id'] as num).toInt();
        final row = _mappers.tripToRow(
          draft.copyWith(id: draftId),
          summary,
          updatedAt: DateTime.now().toUtc(),
        )..remove('created_at');
        await txn.update(
          'car_trips',
          row,
          where: 'id = ? AND status = ?',
          whereArgs: [draftId, CarTripStatus.open.value],
        );
        await txn.delete(
          'car_trip_items',
          where: 'trip_id = ?',
          whereArgs: [draftId],
        );
        for (final item in draft.items) {
          await txn.insert('car_trip_items', _mappers.itemToRow(item, draftId));
        }
        return draft.copyWith(id: draftId);
      }

      final id = await txn.insert(
        'car_trips',
        _mappers.tripToRow(
          draft,
          summary,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      for (final item in draft.items) {
        await txn.insert('car_trip_items', _mappers.itemToRow(item, id));
      }
      return draft.copyWith(id: id);
    });
  }

  @override
  Future<CarTrip> createAndConfirmTrip(
    CarTrip trip, {
    String? triggeredBy,
  }) async {
    final saved = await _reads.createAndConfirmTrip(
      trip,
      triggeredBy: triggeredBy,
    );
    await _syncLatestRevision(saved);
    return saved;
  }

  @override
  Future<CarTrip> confirmTrip(
    CarTrip trip, {
    String? triggeredBy,
  }) async {
    if (trip.status != CarTripStatus.open) {
      return _reads.confirmTrip(trip, triggeredBy: triggeredBy);
    }

    if (trip.displayNumber.startsWith(_draftPrefix)) {
      final sourceDisplayNumber =
          trip.displayNumber.substring(_draftPrefix.length);
      final source = await _reads.getTripByDisplayNumber(sourceDisplayNumber);
      if (source == null || !source.isClosed) {
        throw StateError('The confirmed source invoice was not found.');
      }

      final finalized = trip.copyWith(
        id: source.id,
        displayNumber: source.displayNumber,
        status: CarTripStatus.closed,
        openedAt: source.openedAt,
        closedAt: DateTime.now().toUtc(),
        payment: source.payment,
      );
      final saved = await _reads.reviseClosedTrip(
        finalized,
        triggeredBy: triggeredBy,
      );

      final db = await _database();
      await db.delete(
        'car_trips',
        where: 'id = ? AND status = ? AND display_number = ?',
        whereArgs: [trip.id, CarTripStatus.open.value, trip.displayNumber],
      );
      await _syncLatestRevision(saved);
      return saved;
    }

    final saved = await _reads.confirmTrip(
      trip.copyWith(closedAt: DateTime.now().toUtc()),
      triggeredBy: triggeredBy,
    );
    await _syncLatestRevision(saved);
    return saved;
  }

  @override
  Future<CarTrip> reviseClosedTrip(
    CarTrip trip, {
    String? triggeredBy,
  }) async {
    final saved = await _reads.reviseClosedTrip(
      trip.copyWith(closedAt: DateTime.now().toUtc()),
      triggeredBy: triggeredBy,
    );
    await _syncLatestRevision(saved);
    return saved;
  }

  Future<void> _syncLatestRevision(CarTrip trip) async {
    if (trip.id <= 0) return;
    final db = await _database();
    final rows = await db.query(
      'car_revisions',
      columns: ['id'],
      where: 'trip_id = ?',
      whereArgs: [trip.id],
      orderBy: 'revision_number DESC',
      limit: 1,
    );
    if (rows.isEmpty) return;

    final summary = _calculator.summary(trip);
    await db.update(
      'car_revisions',
      {
        'gross_subtotal_minor': summary.grossSubtotal.minorUnits,
        'product_discount_total_minor': summary.productDiscountTotal.minorUnits,
        'subtotal_after_products_minor': summary.subtotalAfterProducts.minorUnits,
        'global_discount_amount_minor': summary.globalDiscountAmount.minorUnits,
        'final_total_value_minor': summary.finalTotalSoldValue.minorUnits,
        'total_loaded_cartons': summary.totalLoadedCartons,
        'total_returned_cartons': summary.totalReturnedCartons,
        'total_returned_value_minor': summary.totalReturnedValue.minorUnits,
        'total_sold_cartons': summary.totalSoldCartons,
      },
      where: 'id = ?',
      whereArgs: [rows.single['id']],
    );
  }
}
