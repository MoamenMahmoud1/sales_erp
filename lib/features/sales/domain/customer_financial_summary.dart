class CustomerFinancialSummary {
  final double subtotal;
  final double couponDiscount;
  final double total;
  final double paid;
  final double pendingTransfers;
  final double balance;

  const CustomerFinancialSummary({
    required this.subtotal,
    required this.couponDiscount,
    required this.total,
    required this.paid,
    required this.pendingTransfers,
    required this.balance,
  });

  bool get hasBalance {
    return balance > 0;
  }

  bool get hasPendingTransfers {
    return pendingTransfers > 0;
  }
}