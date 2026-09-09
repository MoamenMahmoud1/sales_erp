import 'package:sqflite/sqflite.dart';

import '../../../core/storage/app_database.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_snapshot.dart';

class LocalDashboardRepository implements DashboardRepository {
  @override
  Future<DashboardSnapshot> loadSnapshot() async {
    final database = await AppDatabase.database;
    final now = DateTime.now();
    final todayStartIso =
        DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
    final weekStartIso =
        now.subtract(const Duration(days: 7)).toUtc().toIso8601String();
    final previousWeekStartIso =
        now.subtract(const Duration(days: 14)).toUtc().toIso8601String();
    final overdueBeforeIso =
        now.subtract(const Duration(days: 5)).toUtc().toIso8601String();

    final queryResults = await Future.wait([
      database.rawQuery(
        'SELECT COALESCE(SUM(total),0) AS value '
        'FROM invoices WHERE created_at >= ?',
        [todayStartIso],
      ),
      database.rawQuery(
        'SELECT COALESCE(SUM(total),0) AS value FROM invoices',
      ),
      database.rawQuery(
        'SELECT COALESCE(SUM(total),0) AS value '
        'FROM invoices WHERE created_at >= ? AND created_at < ?',
        [previousWeekStartIso, weekStartIso],
      ),
      database.rawQuery('SELECT COUNT(*) AS count FROM products'),
      database.rawQuery('SELECT COUNT(*) AS count FROM customers'),
      database.rawQuery('SELECT COUNT(*) AS count FROM invoices'),
      database.rawQuery(
        "SELECT COALESCE(SUM(total),0) AS value FROM invoices "
        "WHERE id NOT IN (SELECT invoice_id FROM payments WHERE status = 'paid')",
      ),
      database.rawQuery(
        "SELECT COUNT(*) AS count FROM invoices "
        "WHERE id NOT IN (SELECT invoice_id FROM payments WHERE status = 'paid') "
        'AND created_at < ?',
        [overdueBeforeIso],
      ),
      database.rawQuery(
        "SELECT i.id, i.total, i.created_at, c.name AS customer, "
        "(SELECT p.status FROM payments p WHERE p.invoice_id = i.id "
        "ORDER BY p.id LIMIT 1) AS status "
        'FROM invoices i INNER JOIN customers c ON c.id = i.customer_id '
        'ORDER BY i.created_at DESC LIMIT 6',
      ),
    ]);

    final weeklyRevenue = await _loadWeeklyRevenue(database, now);

    return DashboardSnapshot(
      totalRevenue: _firstNumber(queryResults[1], 'value'),
      todayRevenue: _firstNumber(queryResults[0], 'value'),
      previousWeekRevenue: _firstNumber(queryResults[2], 'value'),
      outstandingAmount: _firstNumber(queryResults[6], 'value'),
      productCount: _firstNumber(queryResults[3], 'count').toInt(),
      customerCount: _firstNumber(queryResults[4], 'count').toInt(),
      invoiceCount: _firstNumber(queryResults[5], 'count').toInt(),
      overdueInvoiceCount: _firstNumber(queryResults[7], 'count').toInt(),
      weeklyRevenue: weeklyRevenue,
      recentInvoices: _mapRecentInvoices(queryResults[8]),
    );
  }

  Future<List<DashboardRevenuePoint>> _loadWeeklyRevenue(
    Database database,
    DateTime now,
  ) async {
    final dayQueries = <Future<List<Map<String, Object?>>> >[];
    final dates = <DateTime>[];

    for (var daysAgo = 6; daysAgo >= 0; daysAgo--) {
      final day = DateTime(now.year, now.month, now.day - daysAgo);
      final dayStartIso = day.toUtc().toIso8601String();
      final dayEndIso =
          day.add(const Duration(days: 1)).toUtc().toIso8601String();
      dates.add(day);
      dayQueries.add(
        database.rawQuery(
          'SELECT COALESCE(SUM(total),0) AS value '
          'FROM invoices WHERE created_at >= ? AND created_at < ?',
          [dayStartIso, dayEndIso],
        ),
      );
    }

    final results = await Future.wait(dayQueries);
    return [
      for (var index = 0; index < results.length; index++)
        DashboardRevenuePoint(
          date: dates[index],
          revenue: _firstNumber(results[index], 'value'),
        ),
    ];
  }

  List<DashboardInvoiceSummary> _mapRecentInvoices(
    List<Map<String, Object?>> rows,
  ) {
    return rows
        .map(
          (row) => DashboardInvoiceSummary(
            id: (row['id'] as num?)?.toInt() ?? 0,
            total: (row['total'] as num?)?.toDouble() ?? 0,
            createdAt: DateTime.tryParse('${row['created_at']}') ??
                DateTime.fromMillisecondsSinceEpoch(0),
            customerName: '${row['customer'] ?? 'Customer'}',
            paymentStatus: row['status'] as String?,
          ),
        )
        .toList(growable: false);
  }

  double _firstNumber(
    List<Map<String, Object?>> rows,
    String key,
  ) {
    return (rows.firstOrNull?[key] as num?)?.toDouble() ?? 0;
  }
}
