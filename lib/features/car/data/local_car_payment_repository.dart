import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_payment_allocation.dart';
import '../domain/entities/car_payment_transaction.dart';
import '../domain/entities/car_trip.dart';
import '../domain/entities/car_trip_status.dart';
import '../domain/entities/money.dart';
import '../domain/repositories/car_payment_repository.dart';
import '../domain/services/car_calculator.dart';
import 'car_mappers.dart';

/// Persists payment events and allocations atomically in AppDatabase.
///
/// A single payment transaction must never allocate across different
/// Car + Warehouse groups. The database validates that rule again so UI/domain
/// mistakes cannot corrupt payment attribution.
class LocalCarPaymentRepository implements CarPaymentRepository {
  LocalCarPaymentRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database);

  final Future<Database> Function() _database;
  static const _calculator = CarCalculator();
  static const _mappers = CarMappers();

  @override
  Future<int> persistPayment({
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
    var createdTransactionId = 0;

    await db.transaction((txn) async {
      final transactionDate = transaction.createdAt.toUtc().toIso8601String();
      createdTransactionId = await txn.insert('car_payment_transactions', {
        'cash_amount_minor': cash,
        'transfer_amount_minor': transfer,
        'reference': transaction.reference?.trim().isEmpty == true
            ? null
            : transaction.reference?.trim(),
        'created_at': transactionDate,
        'payment_at': transactionDate,
      });

      int? scopeCarId;
      int? scopeWarehouseId;

      for (final allocation in allocations) {
        final tripRows = await txn.query(
          'car_trips',
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

        final tripItems = await txn.query(
          'car_trip_items',
          where: 'trip_id = ?',
          whereArgs: [allocation.tripId],
          orderBy: 'id ASC',
        );
        final trip = _mappers.tripFromRow(row, [
          for (final itemRow in tripItems) _mappers.itemFromRow(itemRow),
        ]);
        final finalPurchaseCost =
            _calculator.summary(trip).totalPurchaseCost.minorUnits;

        final tripCarId = (row['sales_car_id'] as num).toInt();
        final tripWarehouseId = (row['warehouse_id'] as num).toInt();
        scopeCarId ??= tripCarId;
        scopeWarehouseId ??= tripWarehouseId;

        if (tripCarId != scopeCarId || tripWarehouseId != scopeWarehouseId) {
          throw StateError(
            'A single payment cannot mix different Cars or Warehouses.',
          );
        }

        final currentPaidCash = (row['paid_cash_minor'] as num).toInt();
        final currentPaidTransfer =
            (row['paid_transfer_minor'] as num).toInt();
        final allocationTotal = allocation.totalAmount.minorUnits;
        if (currentPaidCash + currentPaidTransfer + allocationTotal >
            finalPurchaseCost) {
          throw StateError(
            'Payment exceeds the remaining buying cost of car trip ${allocation.tripId}.',
          );
        }

        final paymentDate =
            (allocation.paymentAt ?? transaction.createdAt).toUtc().toIso8601String();
        await txn.insert('car_payment_allocations', {
          'payment_transaction_id': createdTransactionId,
          'trip_id': allocation.tripId,
          'cash_amount_minor': allocation.cashAmount.minorUnits,
          'transfer_amount_minor': allocation.transferAmount.minorUnits,
          'payment_at': paymentDate,
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

    return createdTransactionId;
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
  Future<List<CarPaymentAllocation>> getAllocations() async {
    final db = await _database();
    final rows = await db.query(
      'car_payment_allocations',
      orderBy: 'id ASC',
    );
    return rows.map(_allocationFromRow).toList(growable: false);
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

  @override
  Future<void> updateAllocationPaymentDates({
    required int transactionId,
    required Map<int, DateTime> paymentDates,
  }) async {
    if (transactionId <= 0) {
      throw ArgumentError('Invalid payment transaction ID.');
    }
    if (paymentDates.isEmpty) {
      throw ArgumentError('Payment dates are required.');
    }

    final db = await _database();
    await db.transaction((txn) async {
      final rows = await txn.query(
        'car_payment_allocations',
        columns: ['id'],
        where: 'payment_transaction_id = ?',
        whereArgs: [transactionId],
        orderBy: 'id ASC',
      );
      if (rows.isEmpty) {
        throw StateError('Payment transaction has no allocations.');
      }

      final expectedIds = rows.map((row) => (row['id'] as num).toInt()).toSet();
      final providedIds = paymentDates.keys.toSet();
      if (expectedIds.length != providedIds.length ||
          !expectedIds.containsAll(providedIds)) {
        throw StateError('Payment dates must be provided for every invoice allocation.');
      }

      for (final entry in paymentDates.entries) {
        await txn.update(
          'car_payment_allocations',
          {'payment_at': entry.value.toUtc().toIso8601String()},
          where: 'id = ? AND payment_transaction_id = ?',
          whereArgs: [entry.key, transactionId],
        );
      }
    });
  }

  @override
  Future<List<int>> deleteTransaction(int transactionId) async {
    if (transactionId <= 0) {
      throw ArgumentError('Invalid payment transaction ID.');
    }

    final db = await _database();
    final affectedTripIds = <int>[];

    await db.transaction((txn) async {
      final transactionRows = await txn.query(
        'car_payment_transactions',
        columns: ['id'],
        where: 'id = ?',
        whereArgs: [transactionId],
        limit: 1,
      );
      if (transactionRows.isEmpty) {
        throw StateError('Payment transaction was not found.');
      }

      final allocations = await txn.query(
        'car_payment_allocations',
        columns: [
          'trip_id',
          'cash_amount_minor',
          'transfer_amount_minor',
        ],
        where: 'payment_transaction_id = ?',
        whereArgs: [transactionId],
        orderBy: 'id ASC',
      );
      if (allocations.isEmpty) {
        throw StateError('Payment transaction has no allocations.');
      }

      for (final allocation in allocations) {
        final tripId = (allocation['trip_id'] as num).toInt();
        final cash = (allocation['cash_amount_minor'] as num).toInt();
        final transfer = (allocation['transfer_amount_minor'] as num).toInt();

        final tripRows = await txn.query(
          'car_trips',
          columns: ['id', 'paid_cash_minor', 'paid_transfer_minor'],
          where: 'id = ?',
          whereArgs: [tripId],
          limit: 1,
        );
        if (tripRows.isEmpty) {
          throw StateError('Car trip $tripId was not found.');
        }

        final row = tripRows.single;
        final paidCash = (row['paid_cash_minor'] as num).toInt();
        final paidTransfer = (row['paid_transfer_minor'] as num).toInt();
        if (paidCash < cash || paidTransfer < transfer) {
          throw StateError(
            'Payment ${transactionId} cannot be deleted because the trip balance changed.',
          );
        }

        final updated = await txn.update(
          'car_trips',
          {
            'paid_cash_minor': paidCash - cash,
            'paid_transfer_minor': paidTransfer - transfer,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          where: '''
            id = ?
            AND paid_cash_minor = ?
            AND paid_transfer_minor = ?
          ''',
          whereArgs: [tripId, paidCash, paidTransfer],
        );
        if (updated != 1) {
          throw StateError(
            'Car trip $tripId changed while deleting payment $transactionId.',
          );
        }
        affectedTripIds.add(tripId);
      }

      await txn.delete(
        'car_payment_allocations',
        where: 'payment_transaction_id = ?',
        whereArgs: [transactionId],
      );
      await txn.delete(
        'car_payment_transactions',
        where: 'id = ?',
        whereArgs: [transactionId],
      );
    });

    return List.unmodifiable(affectedTripIds);
  }

  CarPaymentAllocation _allocationFromRow(Map<String, Object?> row) =>
      CarPaymentAllocation(
        id: row['id'] as int,
        transactionId: row['payment_transaction_id'] as int,
        tripId: row['trip_id'] as int,
        cashAmount: CarMoney((row['cash_amount_minor'] as num).toInt()),
        transferAmount: CarMoney((row['transfer_amount_minor'] as num).toInt()),
        paymentAt: row['payment_at'] == null
            ? null
            : DateTime.parse(row['payment_at'] as String),
      );
}
