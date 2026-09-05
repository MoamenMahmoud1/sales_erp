import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import 'local_payment_repository.dart';
import '../domain/payment.dart';

extension PaymentDateActions on LocalPaymentRepository {
  Future<List<Payment>> getPaymentsForInvoice(int invoiceId) async {
    if (invoiceId <= 0) return const [];
    final db = await AppDatabase.database;
    final rows = await db.query(
      'payments',
      where: 'invoice_id = ?',
      whereArgs: [invoiceId],
      orderBy: 'id DESC',
    );
    return rows.map(Payment.fromMap).toList(growable: false);
  }

  Future<void> setPaymentDate(int paymentId, DateTime paymentAt) async {
    if (paymentId <= 0) {
      throw ArgumentError('Invalid payment ID.');
    }
    final db = await AppDatabase.database;
    final updated = await db.update(
      'payments',
      {'payment_at': paymentAt.toUtc().toIso8601String()},
      where: 'id = ?',
      whereArgs: [paymentId],
    );
    if (updated != 1) {
      throw StateError('Payment date could not be updated.');
    }
  }
}
