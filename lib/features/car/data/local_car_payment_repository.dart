import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_payment_allocation.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/money.dart';
import '../domain/repositories/car_payment_repository.dart';

/// Persists payment events and allocations atomically in AppDatabase.
///
/// The database is authoritative for the current paid balances. The caller
/// may provide projected trips for the presentation/domain flow, but balances
/// are always derived from the transaction allocations inside the same SQLite
/// transaction. This prevents stale objects from overwriting newer payments.
class LocalCarPaymentRepository implements CarPaymentRepository {
  LocalCarPaymentRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database);

  final Future<Database> Function() _database;

  @override
  Future<void> persistPayment({
    required CarPaymentTransaction transaction,
    required List<CarPaymentAllocation> allocations,
    required List<CarTrip> updatedTrips,
  }) async {
    final cash = transaction.cashAmount.minorUnits;
    final transfer = transaction.transferAmount.minorUnits;
    final total = cash + transfer;

    if (cash < 0 || transfer < 0 || total <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    if (allocations.isEmpty) {
      throw ArgumentError('Payment has no allocations.');
    }

    final allocationTripIds = <int>{};
    var allocatedCash = 0;
    var allocatedTransfer = 0;

    for (final allocation in allocations) {
      final id = allocation.tripId;
      if (id <= 0 || allocation.totalAmount.minorUnits <= 0) {
        throw ArgumentError('Invalid payment allocation.');
      }
      if (!allocationTripIds.add(id)) {
        throw ArgumentError('A payment can allocate to each trip only once.');
      }
      if (allocation.cashAmount.minorUnits < 0 ||
          allocation.transferAmount.minorUnits < 0) {
        throw ArgumentError('Payment allocation amounts cannot be negative.');
      }
      allocatedCash += allocation.cashAmount.minorUnits;
      allocatedTransfer += allocation.transferAmount.minorUnits;
    }

    if (allocatedCash != cash || allocatedTransfer != transfer) {
      throw StateError(
        'Payment allocations must match the cash and transfer amounts exactly.',
      );
    }

    final updatedTripIds = updatedTrips.map((trip) => trip.id).toSet();
    if (updatedTripIds.length != allocationTripIds.length ||
        !updatedTripIds.containsAll(allocationTripIds)) {
      throw ArgumentError(
        'Updated trips must match the payment allocation trip set.',
      );
    }

    final db = await _database();
    await db.transaction((txn) async {
      final transactionId = await txn.insert('car_payment_transactions', {
        'cash_amount_minor': cash,
        'transfer_amount_minor': transfer,
        'reference': transaction.reference?.trim().isEmpty == true
            ? null
            : transaction.reference?.trim(),
        'created_at': transaction.createdAt.toUtc().toIso8601String(),
      });

      for (final allocation in allocations) {
        final tripRows = await txn.query(
          'car_trips',
          columns: [
            'id',
            'status',
            'final_total_value_minor',
            'paid_cash_minor',
            'paid_transfer_minor',
          ],
          where: 'id = ?',
          whereArgs: [allocation.tripId],
          limit: 1,
        );
        if (tripRows.isEmpty) {
          throw StateError('Car trip ${allocation.tripId} was not found.');
        }

        final row = tripRows.single;
        if (row['status'] != CarTripStatus.closed.value) {
          throw StateError('Payments can only be allocated to closed trips.');
        }

        final currentPaidCash = (row['paid_cash_minor'] as num).toInt();
        final currentPaidTransfer =
            (row['paid_transfer_minor'] as num).toInt();
        final finalValue = (row['final_total_value_minor'] as num).toInt();
        final allocationTotal = allocation.totalAmount.minorUnits;
        if (currentPaidCash + currentPaidTransfer + allocationTotal >
            finalValue) {
          throw StateError(
            'Payment exceeds the remaining balance of car trip ${allocation.tripId}.',
          );
        }

        await txn.insert('car_payment_allocations', {
          'payment_transaction_id': transactionId,
          'trip_id': allocation.tripId,
          'cash_amount_minor': allocation.cashAmount.minorUnits,
          'transfer_amount_minor': allocation.transferAmount.minorUnits,
        });

        final nextCash = currentPaidCash + allocation.cashAmount.minorUnits;
        final nextTransfer =
            currentPaidTransfer + allocation.transferAmount.minorUnits;
        final updated = await txn.update(
          'car_trips',
          {
            'paid_cash_minor': nextCash,
            'paid_transfer_minor': nextTransfer,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: '''
            id = ? AND status = ?
            AND paid_cash_minor = ? AND paid_transfer_minor = ?
          ''',
          whereArgs: [
            allocation.tripId,
            CarTripStatus.closed.value,
            currentPaidCash,
            currentPaidTransfer,
          ],
        );
        if (updated != 1) {
          throw StateError(
            'Car trip ${allocation.tripId} changed while recording payment.',
          );
        }
      }
    });
  }

  @override
  Future<List<CarPaymentTransaction>> getTransactions() async {
    final db = await _database();
    final rows = await db.query(
      'car_payment_transactions',
      orderBy: 'created_at DESC',
    );
    return rows
        .map(
          (row) => CarPaymentTransaction(
            id: row['id'] as int,
            cashAmount: CarMoney((row['cash_amount_minor'] as num).toInt()),
            transferAmount:
                CarMoney((row['transfer_amount_minor'] as num).toInt()),
            reference: row['reference'] as String?,
            createdAt: DateTime.parse(row['created_at'] as String),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<List<CarPaymentAllocation>> getAllocationsForTransaction(
    int transactionId,
  ) async {
    if (transactionId <= 0) return const [];
    final db = await _database();
    final rows = await db.query(
      'car_payment_allocations',
      where: 'payment_transaction_id = ?',
      whereArgs: [transactionId],
      orderBy: 'id ASC',
    );
    return rows.map(_allocationFromRow).toList(growable: false);
  }

  @override
  Future<List<CarPaymentAllocation>> getAllocationsForTrip(int tripId) async {
    if (tripId <= 0) return const [];
    final db = await _database();
    final rows = await db.query(
      'car_payment_allocations',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'id ASC',
    );
    return rows.map(_allocationFromRow).toList(growable: false);
  }

  CarPaymentAllocation _allocationFromRow(Map<String, Object?> row) =>
      CarPaymentAllocation(
        id: row['id'] as int,
        transactionId: row['payment_transaction_id'] as int,
        tripId: row['trip_id'] as int,
        cashAmount: CarMoney((row['cash_amount_minor'] as num).toInt()),
        transferAmount:
            CarMoney((row['transfer_amount_minor'] as num).toInt()),
      );
}
