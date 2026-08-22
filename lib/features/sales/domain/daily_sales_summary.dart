class DailySalesSummary {
  final DateTime date;

  final int invoiceCount;
  final int customerCount;

  final double subtotal;
  final double couponDiscount;
  final double total;

  final double cashCollected;
  final double transferCollected;
  final double pendingTransfers;

  final double collected;
  final double outstanding;

  const DailySalesSummary({
    required this.date,
    required this.invoiceCount,
    required this.customerCount,
    required this.subtotal,
    required this.couponDiscount,
    required this.total,
    required this.cashCollected,
    required this.transferCollected,
    required this.pendingTransfers,
    required this.collected,
    required this.outstanding,
  });

  double get netSales {
    return total;
  }
}