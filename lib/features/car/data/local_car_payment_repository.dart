import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_payment_allocation.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_trip.dart';
import '../domain/repositories/car_payment_repository.dart';

/// Persists payment events and allocations atomically in AppDatabase.
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
    if (transaction.totalAmount.isNegative || transaction.totalAmount == 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    if (allocations.isEmpty) throw ArgumentError('Payment has no allocations.');

    final db = await _database();
    await db.transaction((txn) async {
      final transactionId = await txn.insert('car_payment_transactions', {
        'cash_amount_minor': transaction.cashAmount.minorUnits,
        'transfer_amount_minor': transaction.transferAmount.minorUnits,
        'reference': transaction.reference?.trim().isEmpty == true
            ? null
            : transaction.reference?.trim(),
        'created_at': transaction.createdAt.toUtc().toIso8601String(),
      });

      var allocatedTotal = 0;
      for (final allocation in allocations) {
        if (allocation.tripId <= 0 || allocation.totalAmount.minorUnits <= 0) {
          throw ArgumentError('Invalid payment allocation.');
        }
        allocatedTotal += allocation.totalAmount.minorUnits;
        await txn.insert('car_payment_allocations', {
          'payment_transaction_id': transactionId,
          'trip_id': allocation.tripId,
          'cash_amount_minor': allocation.cashAmount.minorUnits,
          'transfer_amount_minor': allocation.transferAmount.minorUnits,
        });
      }

      if (allocatedTotal != transaction.totalAmount.minorUnits) {
        throw StateError('Payment allocations must equal the payment amount.');
      }

      final now = DateTime.now().toUtc().toIso8601String();
      for (final trip in updatedTrips) {
        final updated = await txn.update(
          'car_trips',
          {
            'paid_cash_minor': trip.payment.cashAmount.minorUnits,
            'paid_transfer_minor': trip.payment.transferAmount.minorUnits,
            'updated_at': now,
          },
          where: 'id = ?',
          whereArgs: [trip.id],
        );
        if (updated == 0) throw StateError('Car trip ${trip.id} was not found.');
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
