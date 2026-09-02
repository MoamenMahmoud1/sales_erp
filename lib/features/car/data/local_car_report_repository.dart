import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/entities/car_totals.dart';
import '../domain/entities/money.dart';
import '../domain/repositories/car_report_repository.dart';

class LocalCarReportRepository implements CarReportRepository {
  LocalCarReportRepository({Future<Database> Function()? database})
      : _database = database ?? (() => AppDatabase.database);

  final Future<Database> Function() _database;

  @override
  Future<CarTotals> getTotals({DateTime? from, DateTime? to}) async {
    final db = await _database();
    final where = <String>[];
    final args = <Object?>[];

    if (from != null) {
      where.add('opened_at >= ?');
      args.add(from.toUtc().toIso8601String());
    }
    if (to != null) {
      where.add('opened_at < ?');
      args.add(to.toUtc().add(const Duration(days: 1)).toIso8601String());
    }

    final clause = where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}';
    final row = (await db.rawQuery('''
      SELECT
        COALESCE(SUM(total_loaded_cartons), 0) AS loaded,
        COALESCE(SUM(total_returned_cartons), 0) AS returned,
        COALESCE(SUM(total_sold_cartons), 0) AS sold,
        COALESCE(SUM(gross_subtotal_minor), 0) AS gross,
        COALESCE(SUM(product_discount_total_minor), 0) AS product_discount,
        COALESCE(SUM(subtotal_after_products_minor), 0) AS subtotal_after,
        COALESCE(SUM(global_discount_amount_minor), 0) AS global_discount,
        COALESCE(SUM(final_total_value_minor), 0) AS final_value,
        COALESCE(SUM(paid_cash_minor + paid_transfer_minor), 0) AS paid,
        COALESCE(SUM(
          CASE
            WHEN final_total_value_minor > (paid_cash_minor + paid_transfer_minor)
            THEN final_total_value_minor - (paid_cash_minor + paid_transfer_minor)
            ELSE 0
          END
        ), 0) AS remaining,
        COALESCE(SUM(CASE WHEN status = 'open' THEN 1 ELSE 0 END), 0) AS open_count,
        COALESCE(SUM(CASE WHEN status = 'closed' THEN 1 ELSE 0 END), 0) AS closed_count
      FROM car_trips
      $clause
    ''', args)).first;

    // Payment state counts depend on the current time and due date, so they
    // are evaluated from compact summary rows rather than loading trip items.
    final paymentRows = await db.query(
      'car_trips',
      columns: [
        'final_total_value_minor',
        'paid_cash_minor',
        'paid_transfer_minor',
        'due_date',
      ],
      where: clause.isEmpty ? null : clause.substring(6),
      whereArgs: args,
    );

    var paidCount = 0;
    var partialCount = 0;
    var unpaidCount = 0;
    var overdueCount = 0;
    final now = DateTime.now();
    for (final paymentRow in paymentRows) {
      final total = (paymentRow['final_total_value_minor'] as num).toInt();
      final paid =
          (paymentRow['paid_cash_minor'] as num).toInt() +
          (paymentRow['paid_transfer_minor'] as num).toInt();
      final remaining = total > paid ? total - paid : 0;
      if (remaining == 0) {
        paidCount++;
        continue;
      }
      final due = paymentRow['due_date'] as String?;
      if (due != null && now.isAfter(DateTime.parse(due))) {
        overdueCount++;
      } else if (paid == 0) {
        unpaidCount++;
      } else {
        partialCount++;
      }
    }

    int value(String key) => (row[key] as num?)?.toInt() ?? 0;
    return CarTotals(
      totalLoadedCartons: value('loaded'),
      totalReturnedCartons: value('returned'),
      totalSoldCartons: value('sold'),
      grossSubtotal: CarMoney(value('gross')),
      productDiscountTotal: CarMoney(value('product_discount')),
      subtotalAfterProducts: CarMoney(value('subtotal_after')),
      globalDiscountAmount: CarMoney(value('global_discount')),
      finalValue: CarMoney(value('final_value')),
      totalPaid: CarMoney(value('paid')),
      totalRemaining: CarMoney(value('remaining')),
      openCount: value('open_count'),
      closedCount: value('closed_count'),
      paidCount: paidCount,
      partiallyPaidCount: partialCount,
      unpaidCount: unpaidCount,
      overdueCount: overdueCount,
    );
  }
}
