import '../entities/car_financial_summary.dart';
import '../entities/car_item_line.dart';
import '../entities/car_load_item.dart';
import '../entities/car_trip.dart';
import '../entities/car_validation_issue.dart';
import '../entities/money.dart';

/// Authoritative quantity and buying-side discount calculations for Car trips.
class CarCalculator {
  const CarCalculator();

  int soldCartons(CarLoadItem item) => item.loadedCartons - item.returnedCartons;

  CarItemLine itemLine(CarLoadItem item) {
    final sold = soldCartons(item);
    final sellingValue = item.sellingPrice * sold;
    final purchaseCost = item.purchasePrice * sold;
    final discount = purchaseCost.percentOf(item.discountPercent);
    final purchaseAfterDiscount = purchaseCost - discount;

    return CarItemLine(
      item: item,
      soldCartons: sold,
      grossValue: sellingValue,
      discountAmount: discount,
      netValue: sellingValue,
      purchaseCost: purchaseCost,
      profitBeforeGlobalDiscount: sellingValue - purchaseAfterDiscount,
    );
  }

  CarFinancialSummary summary(CarTrip trip) {
    var totalLoaded = 0;
    var totalReturned = 0;
    var totalSold = 0;
    var totalReturnedValue = CarMoney.zero;
    var sellingRevenue = CarMoney.zero;
    var productDiscounts = CarMoney.zero;
    var purchaseCost = CarMoney.zero;
    final lines = <CarItemLine>[];

    for (final item in trip.items) {
      final line = itemLine(item);
      lines.add(line);
      totalLoaded += item.loadedCartons;
      totalReturned += item.returnedCartons;
      totalSold += line.soldCartons;
      totalReturnedValue += item.sellingPrice * item.returnedCartons;
      sellingRevenue += line.grossValue;
      productDiscounts += line.discountAmount;
      purchaseCost += line.purchaseCost;
    }

    final purchaseAfterProducts = purchaseCost - productDiscounts;
    final globalPercentAmount =
        purchaseAfterProducts.percentOf(trip.globalDiscountPercent);
    final afterPercent = purchaseAfterProducts - globalPercentAmount;
    final fixedGlobalAmount =
        trip.globalDiscountEgp.minorUnits > afterPercent.minorUnits
            ? afterPercent
            : trip.globalDiscountEgp;
    final globalDiscountAmount = globalPercentAmount + fixedGlobalAmount;
    final finalPurchaseCost = afterPercent - fixedGlobalAmount;
    final profit = sellingRevenue - finalPurchaseCost;

    return CarFinancialSummary(
      totalLoadedCartons: totalLoaded,
      totalReturnedCartons: totalReturned,
      totalSoldCartons: totalSold,
      totalReturnedValue: totalReturnedValue,
      grossSubtotal: sellingRevenue,
      productDiscountTotal: productDiscounts,
      subtotalAfterProducts: purchaseAfterProducts,
      globalDiscountPercent: trip.globalDiscountPercent,
      globalDiscountPercentAmount: globalPercentAmount,
      globalDiscountFixedAmount: fixedGlobalAmount,
      globalDiscountAmount: globalDiscountAmount,
      finalTotalSoldValue: sellingRevenue,
      totalPurchaseCost: finalPurchaseCost,
      profit: profit,
      items: List<CarItemLine>.unmodifiable(lines),
    );
  }

  CarMoney remaining(CarTrip trip, {CarFinancialSummary? summaryOf}) {
    final computed = summaryOf ?? summary(trip);
    final remaining = computed.finalTotalSoldValue - trip.payment.totalPaid;
    return remaining.isNegative ? CarMoney.zero : remaining;
  }

  List<CarValidationIssue> validate(CarTrip trip) {
    final issues = <CarValidationIssue>[];
    if (trip.items.isEmpty) {
      issues.add(const CarValidationIssue(
        message: 'A car trip must contain at least one product.',
      ));
    }

    for (var i = 0; i < trip.items.length; i++) {
      final item = trip.items[i];
      final label = item.productName.isEmpty ? 'Product ${i + 1}' : item.productName;

      if (item.loadedCartons < 0) {
        issues.add(CarValidationIssue(
          message: '$label: loaded cartons cannot be negative.',
          productIndex: i,
        ));
      }
      if (item.returnedCartons < 0) {
        issues.add(CarValidationIssue(
          message: '$label: returned cartons cannot be negative.',
          productIndex: i,
        ));
      }
      if (item.returnedCartons > item.loadedCartons) {
        issues.add(CarValidationIssue(
          message: '$label: returned cartons cannot exceed loaded cartons.',
          productIndex: i,
        ));
      }
      if (item.sellingPrice.minorUnits <= 0) {
        issues.add(CarValidationIssue(
          message: '$label: selling price must be greater than zero.',
          productIndex: i,
        ));
      }
      if (item.purchasePrice.minorUnits < 0) {
        issues.add(CarValidationIssue(
          message: '$label: purchase price cannot be negative.',
          productIndex: i,
        ));
      }
      if (item.discountPercent < 0 || item.discountPercent > 100) {
        issues.add(CarValidationIssue(
          message: '$label: discount must be between 0 and 100%.',
          productIndex: i,
        ));
      }
    }

    if (trip.globalDiscountPercent < 0 || trip.globalDiscountPercent > 100) {
      issues.add(const CarValidationIssue(
        message: 'Global discount must be between 0 and 100%.',
      ));
    }
    if (trip.globalDiscountEgp.isNegative) {
      issues.add(const CarValidationIssue(
        message: 'Global discount EGP cannot be negative.',
      ));
    }

    final computed = summary(trip);
    final maxFixed = computed.subtotalAfterProducts -
        computed.globalDiscountPercentAmount;
    if (trip.globalDiscountEgp > maxFixed) {
      issues.add(const CarValidationIssue(
        message: 'Global discount EGP cannot exceed the remaining buying cost.',
      ));
    }

    return issues;
  }

  bool canBeClosed(CarTrip trip) =>
      validate(trip).isEmpty && trip.items.isNotEmpty;
}
