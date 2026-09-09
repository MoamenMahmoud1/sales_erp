import 'package:flutter/foundation.dart';

class DashboardInvoiceSummary {
  final int id;
  final double total;
  final DateTime createdAt;
  final String customerName;
  final String? paymentStatus;

  const DashboardInvoiceSummary({
    required this.id,
    required this.total,
    required this.createdAt,
    required this.customerName,
    required this.paymentStatus,
  });
}

class DashboardRevenuePoint {
  final DateTime date;
  final double revenue;

  const DashboardRevenuePoint({
    required this.date,
    required this.revenue,
  });
}

@immutable
class DashboardSnapshot {
  final double totalRevenue;
  final double todayRevenue;
  final double previousWeekRevenue;
  final double outstandingAmount;
  final int productCount;
  final int customerCount;
  final int invoiceCount;
  final int overdueInvoiceCount;
  final List<DashboardRevenuePoint> weeklyRevenue;
  final List<DashboardInvoiceSummary> recentInvoices;

  const DashboardSnapshot({
    required this.totalRevenue,
    required this.todayRevenue,
    required this.previousWeekRevenue,
    required this.outstandingAmount,
    required this.productCount,
    required this.customerCount,
    required this.invoiceCount,
    required this.overdueInvoiceCount,
    required this.weeklyRevenue,
    required this.recentInvoices,
  });

  double get lastSevenDaysRevenue =>
      weeklyRevenue.fold<double>(0, (sum, point) => sum + point.revenue);

  double get revenueTrendPercentage {
    if (previousWeekRevenue <= 0) return 0;
    return ((lastSevenDaysRevenue - previousWeekRevenue) /
            previousWeekRevenue) *
        100;
  }

  double get maximumDailyRevenue {
    if (weeklyRevenue.isEmpty) return 1;
    final maximum = weeklyRevenue
        .map((point) => point.revenue)
        .reduce((left, right) => left > right ? left : right);
    return maximum > 0 ? maximum : 1;
  }
}
