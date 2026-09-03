import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_trip.dart';
import '../domain/services/car_calculator.dart';
import 'local_car_trip_command_repository.dart';

/// Keeps newly-created revision summary fields synchronized with the current
/// buying-side discount semantics.
class LocalCarTripCommandRepositoryV2 extends LocalCarTripCommandRepository {
  LocalCarTripCommandRepositoryV2({Future<Database> Function()? database})
      : super(database: database);

  static const _calculator = CarCalculator();

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
    final saved = await super.confirmTrip(
      trip,
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
      trip,
      triggeredBy: triggeredBy,
    );
    await _syncLatestRevision(saved);
    return saved;
  }

  Future<void> _syncLatestRevision(CarTrip trip) async {
    if (trip.id <= 0) return;
    final db = await AppDatabase.database;
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
