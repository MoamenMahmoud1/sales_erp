import 'package:dio/dio.dart';

import '../../../core/network/api_client.dart';
import '../domain/dashboard_repository.dart';
import '../domain/dashboard_snapshot.dart';
import 'local_dashboard_repository.dart';

class HybridDashboardRepository implements DashboardRepository {
  final ApiClient client;
  final LocalDashboardRepository local;

  HybridDashboardRepository(
    this.client, {
    this.local = const LocalDashboardRepository(),
  });

  @override
  Future<DashboardSnapshot> loadSnapshot() async {
    try {
      final now = DateTime.now();
      final today = _date(now);
      final weekStart = _date(DateTime(now.year, now.month, now.day - 6));
      final previousWeekStart = _date(DateTime(now.year, now.month, now.day - 13));
      final previousWeekEnd = _date(DateTime(now.year, now.month, now.day - 7));

      final responses = await Future.wait([
        client.dio.get('/accounting/analytics/overview/'),
        client.dio.get(
          '/accounting/analytics/overview/',
          queryParameters: {'from': weekStart, 'to': today},
        ),
        client.dio.get(
          '/accounting/analytics/overview/',
          queryParameters: {
            'from': previousWeekStart,
            'to': previousWeekEnd,
          },
        ),
      ]);

      final allTime = _map(responses[0].data);
      final week = _map(responses[1].data);
      final previousWeek = _map(responses[2].data);

      List<Map<String, dynamic>> invoices = const [];
      try {
        final response = await client.dio.get(
          '/invoices/',
          queryParameters: {
            'status': 'confirmed',
            'ordering': '-created_at',
            'page_size': 100,
          },
        );
        invoices = _invoiceRows(response.data);
      } on DioException {
        // Recent invoices are optional; dashboard analytics remain authoritative.
      }

      final weeklyRevenue = _weeklyRevenue(
        week['sales'] as Map<String, dynamic>? ?? const {},
        now,
      );
      final todayRevenue = _revenueForDate(weeklyRevenue, today);

      return DashboardSnapshot(
        totalRevenue: _number(
          (allTime['sales'] as Map<String, dynamic>?)?['gross_sales'],
        ),
        todayRevenue: todayRevenue,
        previousWeekRevenue: _number(
          (previousWeek['sales'] as Map<String, dynamic>?)?['gross_sales'],
        ),
        outstandingAmount: _outstanding(
          allTime['customer_balances'],
        ),
        productCount: _int(
          (allTime['counts'] as Map<String, dynamic>?)?['product_count'],
        ),
        customerCount: _int(
          (allTime['counts'] as Map<String, dynamic>?)?['customer_count'],
        ),
        invoiceCount: _int(
          (allTime['counts'] as Map<String, dynamic>?)?['invoice_count'],
        ),
        overdueInvoiceCount: _overdueCount(invoices, now),
        weeklyRevenue: weeklyRevenue,
        recentInvoices: _mapRecentInvoices(invoices.take(6)),
      );
    } on DioException {
      return local.loadSnapshot();
    }
  }

  Map<String, dynamic> _map(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
  }

  List<Map<String, dynamic>> _invoiceRows(dynamic value) {
    final payload = _map(value);
    final rows = payload['results'];
    if (rows is! List) return const [];
    return [
      for (final row in rows)
        if (row is Map) Map<String, dynamic>.from(row),
    ];
  }

  List<DashboardRevenuePoint> _weeklyRevenue(
    Map<String, dynamic> sales,
    DateTime now,
  ) {
    final trend = sales['trend'];
    final byDate = <String, double>{};

    if (trend is List) {
      for (final row in trend) {
        if (row is! Map) continue;
        final date = row['date']?.toString();
        if (date == null || date.isEmpty) continue;
        byDate[date] = _number(row['value']);
      }
    }

    return [
      for (var daysAgo = 6; daysAgo >= 0; daysAgo--)
        () {
          final date = DateTime(now.year, now.month, now.day - daysAgo);
          final key = _date(date);
          return DashboardRevenuePoint(
            date: date,
            revenue: byDate[key] ?? 0,
          );
        }(),
    ];
  }

  double _revenueForDate(
    List<DashboardRevenuePoint> points,
    String date,
  ) {
    for (final point in points) {
      if (_date(point.date) == date) return point.revenue;
    }
    return 0;
  }

  double _outstanding(dynamic value) {
    if (value is! List) return 0;
    return value.fold<double>(
      0,
      (sum, row) {
        if (row is! Map) return sum;
        final balance = _number(row['balance']);
        return sum + (balance > 0 ? balance : 0);
      },
    );
  }

  int _overdueCount(
    List<Map<String, dynamic>> invoices,
    DateTime now,
  ) {
    final cutoff = DateTime(now.year, now.month, now.day)
        .subtract(const Duration(days: 5));

    return invoices.where((invoice) {
      final createdAt = DateTime.tryParse(
        invoice['created_at']?.toString() ?? '',
      );
      if (createdAt == null || !createdAt.isBefore(cutoff)) return false;
      return _number(invoice['outstanding_amount']) > 0;
    }).length;
  }

  List<DashboardInvoiceSummary> _mapRecentInvoices(
    Iterable<Map<String, dynamic>> invoices,
  ) {
    return [
      for (final invoice in invoices)
        DashboardInvoiceSummary(
          id: _int(invoice['id']),
          total: _number(invoice['total']),
          createdAt: DateTime.tryParse(
                invoice['created_at']?.toString() ?? '',
              ) ??
              DateTime.fromMillisecondsSinceEpoch(0),
          customerName: invoice['customer_name']?.toString() ?? 'Customer',
          paymentStatus: _paymentStatus(invoice),
        ),
    ];
  }

  String _paymentStatus(Map<String, dynamic> invoice) {
    final outstanding = _number(invoice['outstanding_amount']);
    final paid = _number(invoice['paid_amount']);
    if (outstanding <= 0) return 'paid';
    if (paid > 0) return 'pending';
    return 'unpaid';
  }

  double _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  int _int(dynamic value) => _number(value).toInt();

  String _date(DateTime value) {
    return `${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}`;
  }
}
