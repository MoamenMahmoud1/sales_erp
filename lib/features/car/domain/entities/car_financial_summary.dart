import 'car_item_line.dart';
import 'money.dart';

/// The authoritative, pre-computed financial result of a car trip.
///
/// Produced by the calculator service and consumed directly by widgets and
/// reports so presentation code contains no business calculations.
///
/// Calculation order (explicit, no silent double discounting):
/// 1. Gross value before discounts (sum of product gross sold values)
/// 2. − Product-level discounts
/// 3. = Subtotal after product discounts
/// 4. − Global discount (applied to the subtotal after product discounts)
/// 5. = Final sold value
class CarFinancialSummary {
  final int totalLoadedCartons;
  final int totalReturnedCartons;
  final int totalSoldCartons;

  final CarMoney grossSubtotal;
  final CarMoney productDiscountTotal;
  final CarMoney subtotalAfterProducts;

  final double globalDiscountPercent;
  final CarMoney globalDiscountAmount;
  final CarMoney finalTotalSoldValue;

  final List<CarItemLine> items;

  const CarFinancialSummary({
    required this.totalLoadedCartons,
    required this.totalReturnedCartons,
    required this.totalSoldCartons,
    required this.grossSubtotal,
    required this.productDiscountTotal,
    required this.subtotalAfterProducts,
    required this.globalDiscountPercent,
    required this.globalDiscountAmount,
    required this.finalTotalSoldValue,
    required this.items,
  });
}