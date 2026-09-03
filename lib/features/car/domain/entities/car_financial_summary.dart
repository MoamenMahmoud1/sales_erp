import 'car_item_line.dart';
import 'money.dart';

/// Authoritative financial and carton summary produced by CarCalculator.
class CarFinancialSummary {
  final int totalLoadedCartons;
  final int totalReturnedCartons;
  final int totalSoldCartons;
  final CarMoney totalReturnedValue;

  final CarMoney grossSubtotal;
  final CarMoney productDiscountTotal;
  final CarMoney subtotalAfterProducts;
  final double globalDiscountPercent;
  final CarMoney globalDiscountAmount;
  final CarMoney finalTotalSoldValue;
  final CarMoney totalPurchaseCost;
  final CarMoney profit;
  final List<CarItemLine> items;

  const CarFinancialSummary({
    required this.totalLoadedCartons,
    required this.totalReturnedCartons,
    required this.totalSoldCartons,
    required this.totalReturnedValue,
    required this.grossSubtotal,
    required this.productDiscountTotal,
    required this.subtotalAfterProducts,
    required this.globalDiscountPercent,
    required this.globalDiscountAmount,
    required this.finalTotalSoldValue,
    this.totalPurchaseCost = CarMoney.zero,
    this.profit = CarMoney.zero,
    required this.items,
  });
}
