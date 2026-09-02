import 'money.dart';

/// Aggregate operational and financial totals across Car trips.
class CarTotals {
  final int totalLoadedCartons;
  final int totalReturnedCartons;
  final int totalSoldCartons;
  final CarMoney totalReturnedValue;

  final CarMoney grossSubtotal;
  final CarMoney productDiscountTotal;
  final CarMoney subtotalAfterProducts;
  final CarMoney globalDiscountAmount;
  final CarMoney finalValue;
  final CarMoney totalPaid;
  final CarMoney totalRemaining;

  final int openCount;
  final int closedCount;
  final int paidCount;
  final int partiallyPaidCount;
  final int unpaidCount;
  final int overdueCount;

  const CarTotals({
    required this.totalLoadedCartons,
    required this.totalReturnedCartons,
    required this.totalSoldCartons,
    required this.totalReturnedValue,
    required this.grossSubtotal,
    required this.productDiscountTotal,
    required this.subtotalAfterProducts,
    required this.globalDiscountAmount,
    required this.finalValue,
    required this.totalPaid,
    required this.totalRemaining,
    required this.openCount,
    required this.closedCount,
    required this.paidCount,
    required this.partiallyPaidCount,
    required this.unpaidCount,
    required this.overdueCount,
  });
}
