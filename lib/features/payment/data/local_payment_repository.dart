import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/payment.dart';
import '../../customers/domain/payment_method.dart';

class LocalPaymentRepository {
  Future<Database> get _database async {
    return AppDatabase.database;
  }

  Future<int> createPayment({
    required int customerId,
    required int invoiceId,
    required double amount,
    required PaymentMethod method,
    String? reference,
  }) async {
    if (amount <= 0) {
      throw ArgumentError(
        'Payment amount must be greater than zero.',
      );
    }

    final database = await _database;

    final status = method == PaymentMethod.cash
        ? PaymentStatus.paid
        : PaymentStatus.pending;

    final now =
        DateTime.now().toUtc().toIso8601String();

    return database.insert(
      'payments',
      {
        'customer_id': customerId,
        'invoice_id': invoiceId,
        'amount': amount,
        'method': method.value,
        'status': status.name,
        'reference': reference,
        'created_at': now,
        'confirmed_at':
            status == PaymentStatus.paid
                ? now
                : null,
      },
    );
  }

  Future<void> confirmTransfer(
    int paymentId,
  ) async {
    final database = await _database;

    final now =
        DateTime.now().toUtc().toIso8601String();

    await database.update(
      'payments',
      {
        'status': PaymentStatus.paid.name,
        'confirmed_at': now,
      },
      where: '''
        id = ?
        AND method = ?
        AND status = ?
      ''',
      whereArgs: [
        paymentId,
        PaymentMethod.transfer.value,
        PaymentStatus.pending.name,
      ],
    );
  }

  Future<List<Payment>> getPendingTransfers() async {
    final database = await _database;

    final rows = await database.query(
      'payments',
      where: '''
        method = ?
        AND status = ?
      ''',
      whereArgs: [
        PaymentMethod.transfer.value,
        PaymentStatus.pending.name,
      ],
      orderBy: 'created_at ASC',
    );

    return rows
        .map(Payment.fromMap)
        .toList(growable: false);
  }

  Future<List<Payment>> getPaymentsForCustomer(
    int customerId,
  ) async {
    final database = await _database;

    final rows = await database.query(
      'payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    return rows
        .map(Payment.fromMap)
        .toList(growable: false);
  }

  Future<List<Payment>> getPaidPaymentsForCustomer(
    int customerId,
  ) async {
    final database = await _database;

    final rows = await database.query(
      'payments',
      where: '''
        customer_id = ?
        AND status = ?
      ''',
      whereArgs: [
        customerId,
        PaymentStatus.paid.name,
      ],
      orderBy: 'created_at DESC',
    );

    return rows
        .map(Payment.fromMap)
        .toList(growable: false);
  }

  Future<double> getPaidPaymentsTotal(
    int customerId,
  ) async {
    final database = await _database;

    final result = await database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customer_id = ?
        AND status = ?
      ''',
      [
        customerId,
        PaymentStatus.paid.name,
      ],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getPendingTransfersTotal(
    int customerId,
  ) async {
    final database = await _database;

    final result = await database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customer_id = ?
        AND method = ?
        AND status = ?
      ''',
      [
        customerId,
        PaymentMethod.transfer.value,
        PaymentStatus.pending.name,
      ],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getPaidCashTotal(
    int customerId,
  ) async {
    final database = await _database;

    final result = await database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customer_id = ?
        AND method = ?
        AND status = ?
      ''',
      [
        customerId,
        PaymentMethod.cash.value,
        PaymentStatus.paid.name,
      ],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getPaidTransferTotal(
    int customerId,
  ) async {
    final database = await _database;

    final result = await database.rawQuery(
      '''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customer_id = ?
        AND method = ?
        AND status = ?
      ''',
      [
        customerId,
        PaymentMethod.transfer.value,
        PaymentStatus.paid.name,
      ],
    );

    return (result.first['total'] as num).toDouble();
  }
}