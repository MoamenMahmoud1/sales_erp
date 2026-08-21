import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/payment.dart';

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
    String? note,
  }) async {
    final database = await _database;

    final status = method == PaymentMethod.cash
        ? PaymentStatus.paid
        : PaymentStatus.pending;

    final now = DateTime.now().toUtc().toIso8601String();

    return database.insert(
      'payments',
      {
        'customer_id': customerId,
        'invoice_id': invoiceId,
        'amount': amount,
        'method': method.name,
        'status': status.name,
        'created_at': now,
        'confirmed_at': status == PaymentStatus.paid ? now : null,
        'reference': reference,
        'note': note,
      },
    );
  }

  Future<void> confirmTransfer(int paymentId) async {
    final database = await _database;

    final now = DateTime.now().toUtc().toIso8601String();

    await database.update(
      'payments',
      {
        'status': PaymentStatus.paid.name,
        'confirmed_at': now,
      },
      where: 'id = ? AND method = ? AND status = ?',
      whereArgs: [
        paymentId,
        PaymentMethod.transfer.name,
        PaymentStatus.pending.name,
      ],
    );
  }

  Future<List<Payment>> getPendingTransfers() async {
    final database = await _database;

    final rows = await database.query(
      'payments',
      where: 'method = ? AND status = ?',
      whereArgs: [
        PaymentMethod.transfer.name,
        PaymentStatus.pending.name,
      ],
      orderBy: 'created_at ASC',
    );

    return rows.map(Payment.fromMap).toList(growable: false);
  }

  Future<List<Payment>> getConfirmedPaymentsForCustomer(
    int customerId,
  ) async {
    final database = await _database;

    final rows = await database.query(
      'payments',
      where: 'customer_id = ? AND status = ?',
      whereArgs: [
        customerId,
        PaymentStatus.paid.name,
      ],
      orderBy: 'created_at DESC',
    );

    return rows.map(Payment.fromMap).toList(growable: false);
  }

  Future<double> getConfirmedPaymentsTotal(
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
        PaymentMethod.transfer.name,
        PaymentStatus.pending.name,
      ],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getConfirmedCashTotal(
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
        PaymentMethod.cash.name,
        PaymentStatus.paid.name,
      ],
    );

    return (result.first['total'] as num).toDouble();
  }

  Future<double> getConfirmedTransferTotal(
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
        PaymentMethod.transfer.name,
        PaymentStatus.paid.name,
      ],
    );

    return (result.first['total'] as num).toDouble();
  }
}

