import 'money.dart';

/// Aggregate quantities, finances and payment-status counts across car trips.
///
/// All monetary fields are integer minor units. Used by the Car dashboard and
/// reports; computed in the data layer from stored summary columns.
class CarTotals {
  final int totalLoadedCartons;
  final int totalReturnedCartons;
  final int totalSoldCartons;

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