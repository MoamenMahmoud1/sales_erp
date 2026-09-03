import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_trip.dart';
import '../domain/services/car_calculator.dart';
import 'car_mappers.dart';
import 'local_car_trip_command_repository.dart';

/// Keeps newly-created revision summary fields synchronized with the current
/// buying-side discount semantics and provides isolated edit drafts for
/// already-confirmed invoices.
class LocalCarTripCommandRepositoryV2 extends LocalCarTripCommandRepository {
  LocalCarTripCommandRepositoryV2({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database),
        super(database: database);

  final Future<Database> Function() _database;
  static const _calculator = CarCalculator();
  static const _draftPrefix = 'DRAFT|';

  @override
  Future<CarTrip> updateDraft(CarTrip trip) async {
    if (trip.id <= 0) return super.updateDraft(trip);

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

    // Never overwrite a confirmed invoice when its editor uses Save as draft.
    if (status == 'closed' && !displayNumber.startsWith(_draftPrefix)) {
      return _saveRevisionDraft(trip, sourceDisplayNumber: displayNumber);
    }
    return super.updateDraft(trip);
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
        final row = CarMappers().tripToRow(
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
          await txn.insert('car_trip_items', CarMappers().itemToRow(item, draftId));
        }
        return draft.copyWith(id: draftId);
      }

      final id = await txn.insert(
        'car_trips',
        CarMappers().tripToRow(
          draft,
          summary,
          updatedAt: DateTime.now().toUtc(),
        ),
      );
      for (final item in draft.items) {
        await txn.insert('car_trip_items', CarMappers().itemToRow(item, id));
      }
      return draft.copyWith(id: id);
    });
  }

  @override
  Future<CarTrip> createAndConfirmTrip(
    CarTrip trip, {
    String? triggeredBy,
  }) async {
    final saved = await super.createAndConfirmTrip(
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
      return super.confirmTrip(trip, triggeredBy: triggeredBy);
    }

    if (trip.displayNumber.startsWith(_draftPrefix)) {
      final sourceDisplayNumber =
          trip.displayNumber.substring(_draftPrefix.length);
      final source = await getTripByDisplayNumber(sourceDisplayNumber);
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
      final saved = await super.reviseClosedTrip(
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

    final saved = await super.confirmTrip(
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
    final saved = await super.reviseClosedTrip(
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
