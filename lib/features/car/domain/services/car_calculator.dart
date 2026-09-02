import '../entities/car_financial_summary.dart';
import '../entities/car_item_line.dart';
import '../entities/car_load_item.dart';
import '../entities/car_trip.dart';
import '../entities/car_validation_issue.dart';
import '../entities/money.dart';

/// Centralized calculation + validation for car trips.
///
/// All money math lives here (and in [CarMoney]) so widgets never compute
/// `sold = loaded - returned`, discounts, totals or remaining amounts.
class CarCalculator {
  const CarCalculator();

  /// Number of cartons actually sold for an item.
  int soldCartons(CarLoadItem item) => item.loadedCartons - item.returnedCartons;

  /// Produces the fully computed line for a single item.
  CarItemLine itemLine(CarLoadItem item) {
    final sold = soldCartons(item);
    final gross = item.unitPrice * sold;
    final discount = gross.percentOf(item.discountPercent);
    return CarItemLine(
      item: item,
      soldCartons: sold,
      grossValue: gross,
      discountAmount: discount,
      netValue: gross - discount,
    );
  }

  /// Computes the complete quantity + financial summary of a trip.
  ///
  /// Order is fixed:
  /// ```
  /// loaded ─▶ returned ─▶ sold
  /// sold   ─▶ grossSubtotal
  /// grossSubtotal − productDiscounts ─▶ subtotalAfterProducts
  /// subtotalAfterProducts − globalDiscount ─▶ finalTotalSoldValue
  /// ```
  CarFinancialSummary summary(CarTrip trip) {
    var totalLoaded = 0;
    var totalReturned = 0;
    var totalSold = 0;
    var gross = CarMoney.zero;
    var productDiscounts = CarMoney.zero;
    final lines = <CarItemLine>[];

    for (final item in trip.items) {
      final line = itemLine(item);
      lines.add(line);
      totalLoaded += item.loadedCartons;
      totalReturned += item.returnedCartons;
      totalSold += line.soldCartons;
      gross += line.grossValue;
      productDiscounts += line.discountAmount;
    }

    final subtotalAfterProducts = gross - productDiscounts;
    final globalDiscount = subtotalAfterProducts.percentOf(trip.globalDiscountPercent);
    final finalValue = subtotalAfterProducts - globalDiscount;

    return CarFinancialSummary(
      totalLoadedCartons: totalLoaded,
      totalReturnedCartons: totalReturned,
      totalSoldCartons: totalSold,
      grossSubtotal: gross,
      productDiscountTotal: productDiscounts,
      subtotalAfterProducts: subtotalAfterProducts,
      globalDiscountPercent: trip.globalDiscountPercent,
      globalDiscountAmount: globalDiscount,
      finalTotalSoldValue: finalValue,
      items: List<CarItemLine>.unmodifiable(lines),
    );
  }

  /// Remaining balance for a trip after payments.
  ///
  /// Clamped at zero so an overpaid trip never reports a negative balance.
  CarMoney remaining(CarTrip trip, {CarFinancialSummary? summaryOf}) {
    final computed = summaryOf ?? summary(trip);
    final remaining = computed.finalTotalSoldValue - trip.payment.totalPaid;
    return remaining.isNegative ? CarMoney.zero : remaining;
  }

  /// Aggregated validation issues. Returns an empty list when the trip is valid.
  List<CarValidationIssue> validate(CarTrip trip) {
    final issues = <CarValidationIssue>[];

    if (trip.items.isEmpty) {
      issues.add(const CarValidationIssue(
        message: 'A car trip must contain at least one product.',
      ));
    }

    for (var i = 0; i < trip.items.length; i++) {
      final item = trip.items[i];
      final label = item.productName.isEmpty ? 'Product #${i + 1}' : item.productName;

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
      if (item.unitPrice.isNegative) {
        issues.add(CarValidationIssue(
          message: '$label: unit price cannot be negative.',
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

    return issues;
  }

  /// Whether a trip can be closed (valid quantity/product data present).
  bool canBeClosed(CarTrip trip) =>
      trip.items.isNotEmpty && validate(trip).isEmpty;
}