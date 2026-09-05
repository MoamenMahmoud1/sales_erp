import 'package:sqflite/sqflite.dart';

/// Adds explicit payment-occurrence timestamps without changing existing
/// creation/audit timestamps.
Future<void> runPaymentDateMigration(Database db, int oldVersion) async {
  if (oldVersion >= 17) return;

  await db.transaction((txn) async {
    final paymentColumns = await _columns(txn, 'payments');
    if (paymentColumns.isNotEmpty && !paymentColumns.contains('payment_at')) {
      await txn.execute('ALTER TABLE payments ADD COLUMN payment_at TEXT');
      await txn.execute('UPDATE payments SET payment_at = created_at WHERE payment_at IS NULL');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_payments_payment_at ON payments(payment_at)',
      );
    }

    final transactionColumns = await _columns(txn, 'car_payment_transactions');
    if (transactionColumns.isNotEmpty && !transactionColumns.contains('payment_at')) {
      await txn.execute(
        'ALTER TABLE car_payment_transactions ADD COLUMN payment_at TEXT',
      );
      await txn.execute(
        'UPDATE car_payment_transactions SET payment_at = created_at WHERE payment_at IS NULL',
      );
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_car_pmt_tx_payment_at ON car_payment_transactions(payment_at)',
      );
    }

    final allocationColumns = await _columns(txn, 'car_payment_allocations');
    if (allocationColumns.isNotEmpty && !allocationColumns.contains('payment_at')) {
      await txn.execute(
        'ALTER TABLE car_payment_allocations ADD COLUMN payment_at TEXT',
      );
      await txn.execute('''
        UPDATE car_payment_allocations
        SET payment_at = (
          SELECT COALESCE(cpt.payment_at, cpt.created_at)
          FROM car_payment_transactions cpt
          WHERE cpt.id = car_payment_allocations.payment_transaction_id
        )
        WHERE payment_at IS NULL
      ''');
      await txn.execute(
        'CREATE INDEX IF NOT EXISTS idx_car_pmt_alloc_payment_at ON car_payment_allocations(payment_at)',
      );
    }
  });
}

Future<Set<String>> _columns(DatabaseExecutor db, String table) async {
  final rows = await db.rawQuery('PRAGMA table_info($table)');
  return {for (final row in rows) row['name'] as String};
}
