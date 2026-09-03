import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_load_item.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_deletion_result.dart';
import '../domain/repositories/car_trip_command_repository.dart';
import 'car_mappers.dart';
import 'local_car_trip_repository.dart';

/// Write-side extension for trip deletion.
///
/// Deleting a trip removes every payment transaction that allocated to it.
/// If one of those payments also covered other trips, their paid amounts are
/// reversed atomically before the shared payment transaction is removed.
class LocalCarTripCommandRepository extends LocalCarTripRepository
    implements CarTripCommandRepository {
  LocalCarTripCommandRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database),
        super(database: database);

  final Future<Database> Function() _database;
  static const _mappers = CarMappers();

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
        final transactionId = (transactionRow['payment_transaction_id'] as num).toInt();
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
          final transfer = (allocation['transfer_amount_minor'] as num).toInt();
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

          final currentCash = (affectedRows.single['paid_cash_minor'] as num).toInt();
          final currentTransfer = (affectedRows.single['paid_transfer_minor'] as num).toInt();
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
      if (deleted != 1) throw StateError('Car trip $tripId could not be deleted.');

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
}
