import 'car_item_line.dart';
import 'money.dart';

/// Authoritative financial and carton summary produced by CarCalculator.
class CarFinancialSummary {
  final int totalLoadedCartons;
  final int totalReturnedCartons;
  final int totalSoldCartons;
  final CarMoney totalReturnedValue;

  /// Customer-facing selling revenue. Discounts never reduce this value.
  final CarMoney grossSubtotal;

  /// Product discounts are cost-side discounts applied to buying cost.
  final CarMoney productDiscountTotal;

  /// Buying cost after product-level discounts, before global discounts.
  final CarMoney subtotalAfterProducts;

  final double globalDiscountPercent;
  final CarMoney globalDiscountPercentAmount;
  final CarMoney globalDiscountFixedAmount;
  final CarMoney globalDiscountAmount;

  /// Final customer selling total. This remains the full selling revenue.
  final CarMoney finalTotalSoldValue;

  /// Final buying cost after all product/global discounts.
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
    this.globalDiscountPercentAmount = CarMoney.zero,
    this.globalDiscountFixedAmount = CarMoney.zero,
    required this.globalDiscountAmount,
    required this.finalTotalSoldValue,
    this.totalPurchaseCost = CarMoney.zero,
    this.profit = CarMoney.zero,
    required this.items,
  });
}
