import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../../customers/domain/payment_method.dart';
import '../domain/payment.dart';
import '../domain/payment_repository.dart';
import '../domain/payment_status.dart';

class LocalPaymentRepository implements PaymentRepository {
  Future<Database> get _database {
    return AppDatabase.database;
  }

  @override
  Future<int> createPayment({
    required int customerId,
    required int invoiceId,
    required double amount,
    required PaymentMethod method,
    String? reference,
  }) async {
    if (customerId <= 0) {
      throw ArgumentError('Invalid customer ID.');
    }

    if (invoiceId <= 0) {
      throw ArgumentError('Invalid invoice ID.');
    }

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }

    final database = await _database;

    final now = DateTime.now().toUtc().toIso8601String();
    final status =
        method == PaymentMethod.cash ? PaymentStatus.paid : PaymentStatus.pending;

    return database.transaction((transaction) async {
      final invoice = await transaction.query(
        'invoices',
        columns: ['id', 'customer_id', 'total'],
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );

      if (invoice.isEmpty) {
        throw StateError('Invoice not found.');
      }

      final invoiceCustomerId = invoice.first['customer_id'] as int;
      if (invoiceCustomerId != customerId) {
        throw StateError('Invoice does not belong to this customer.');
      }

      final total = (invoice.first['total'] as num).toDouble();
      final totals = await transaction.rawQuery('''
        SELECT
          COALESCE(SUM(CASE WHEN status = 'paid' THEN amount ELSE 0 END), 0) AS paid,
          COALESCE(SUM(CASE WHEN status = 'pending' AND amount > 0 THEN amount ELSE 0 END), 0) AS pending
        FROM payments
        WHERE invoice_id = ?
      ''', [invoiceId]);

      final paid = (totals.first['paid'] as num?)?.toDouble() ?? 0;
      final pending = (totals.first['pending'] as num?)?.toDouble() ?? 0;
      final alreadyAllocated = paid + pending;
      if (amount > total - alreadyAllocated) {
        throw StateError('Payment exceeds the remaining invoice balance.');
      }

      return transaction.insert(
        'payments',
        {
          'customer_id': customerId,
          'invoice_id': invoiceId,
          'amount': amount,
          'method': method.value,
          'status': status.value,
          'reference': _normalizeReference(reference),
          'created_at': now,
          'confirmed_at': status == PaymentStatus.paid ? now : null,
        },
      );
    });
  }

  @override
  Future<void> confirmTransfer(int paymentId) async {
    if (paymentId <= 0) {
      throw ArgumentError('Invalid payment ID.');
    }

    final database = await _database;

    await database.transaction((transaction) async {
      final pendingRows = await transaction.query(
        'payments',
        columns: ['id', 'invoice_id', 'amount', 'method', 'status'],
        where: 'id = ? AND method = ? AND status = ?',
        whereArgs: [
          paymentId,
          PaymentMethod.transfer.value,
          PaymentStatus.pending.value,
        ],
        limit: 1,
      );

      if (pendingRows.isEmpty) {
        throw StateError('Payment is not a pending transfer.');
      }

      final payment = pendingRows.single;
      final invoiceId = (payment['invoice_id'] as num).toInt();
      final amount = (payment['amount'] as num).toDouble();
      final invoice = await transaction.query(
        'invoices',
        columns: ['total'],
        where: 'id = ?',
        whereArgs: [invoiceId],
        limit: 1,
      );
      if (invoice.isEmpty) {
        throw StateError('Invoice not found.');
      }

      final total = (invoice.first['total'] as num).toDouble();
      final paidRows = await transaction.rawQuery('''
        SELECT COALESCE(SUM(amount), 0) AS paid
        FROM payments
        WHERE invoice_id = ? AND status = 'paid'
      ''', [invoiceId]);
      final paid = (paidRows.first['paid'] as num?)?.toDouble() ?? 0;
      if (paid + amount > total) {
        throw StateError(
          'Transfer cannot be confirmed because it exceeds the invoice balance.',
        );
      }

      final now = DateTime.now().toUtc().toIso8601String();
      final updated = await transaction.update(
        'payments',
        {
          'status': PaymentStatus.paid.value,
          'confirmed_at': now,
        },
        where: 'id = ? AND method = ? AND status = ?',
        whereArgs: [
          paymentId,
          PaymentMethod.transfer.value,
          PaymentStatus.pending.value,
        ],
      );

      if (updated != 1) {
        throw StateError('Payment changed while confirming transfer.');
      }
    });
  }

  @override
  Future<List<Payment>> getPayments() async {
    final database = await _database;

    final rows = await database.rawQuery('''
      SELECT
        p.id,
        p.customer_id,
        p.invoice_id,
        p.amount,
        p.method,
        p.status,
        p.reference,
        p.created_at,
        p.confirmed_at,
        c.name AS customer_name,
        c.phone AS customer_phone
      FROM payments p
      INNER JOIN customers c ON c.id = p.customer_id
      ORDER BY p.created_at DESC
    ''');

    return rows.map(Payment.fromMap).toList(growable: false);
  }

  @override
  Future<List<Payment>> getPendingTransfers() async {
    final database = await _database;

    final rows = await database.rawQuery('''
      SELECT
        p.id,
        p.customer_id,
        p.invoice_id,
        p.amount,
        p.method,
        p.status,
        p.reference,
        p.created_at,
        p.confirmed_at
      FROM payments p
      WHERE p.method = ?
        AND p.status = ?
        AND p.amount > 0
      ORDER BY p.created_at ASC
    ''', [
      PaymentMethod.transfer.value,
      PaymentStatus.pending.value,
    ]);

    return rows.map(Payment.fromMap).toList(growable: false);
  }

  @override
  Future<List<Payment>> getPaymentsForCustomer(int customerId) async {
    final database = await _database;

    final rows = await database.query(
      'payments',
      where: 'customer_id = ?',
      whereArgs: [customerId],
      orderBy: 'created_at DESC',
    );

    return rows.map(Payment.fromMap).toList(growable: false);
  }

  @override
  Future<List<Payment>> getPaidPaymentsForCustomer(int customerId) async {
    final database = await _database;

    final rows = await database.query(
      'payments',
      where: '''
        customer_id = ?
        AND status = ?
      ''',
      whereArgs: [customerId, PaymentStatus.paid.value],
      orderBy: 'created_at DESC',
    );

    return rows.map(Payment.fromMap).toList(growable: false);
  }

  @override
  Future<double> getPaidPaymentsTotal(int customerId) async {
    final database = await _database;

    final result = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customer_id = ?
        AND status = ?
    ''', [customerId, PaymentStatus.paid.value]);

    return (result.first['total'] as num).toDouble();
  }

  @override
  Future<double> getPendingTransfersTotal(int customerId) async {
    final database = await _database;

    final result = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customer_id = ?
        AND method = ?
        AND status = ?
        AND amount > 0
    ''', [
      customerId,
      PaymentMethod.transfer.value,
      PaymentStatus.pending.value,
    ]);

    return (result.first['total'] as num).toDouble();
  }

  @override
  Future<double> getPaidCashTotal(int customerId) async {
    final database = await _database;

    final result = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customer_id = ?
        AND method = ?
        AND status = ?
    ''', [
      customerId,
      PaymentMethod.cash.value,
      PaymentStatus.paid.value,
    ]);

    return (result.first['total'] as num).toDouble();
  }

  @override
  Future<double> getPaidTransferTotal(int customerId) async {
    final database = await _database;

    final result = await database.rawQuery('''
      SELECT COALESCE(SUM(amount), 0) AS total
      FROM payments
      WHERE customer_id = ?
        AND method = ?
        AND status = ?
    ''', [
      customerId,
      PaymentMethod.transfer.value,
      PaymentStatus.paid.value,
    ]);

    return (result.first['total'] as num).toDouble();
  }

  String? _normalizeReference(String? reference) {
    final value = reference?.trim();
    if (value == null || value.isEmpty) return null;
    return value;
  }
}
