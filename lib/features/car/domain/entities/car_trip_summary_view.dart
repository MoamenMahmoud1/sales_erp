import 'car_payment_status.dart';
import 'car_trip_status.dart';
import 'money.dart';
import '../services/car_payment_evaluator.dart';

/// Lightweight projection used by Car lists and dashboards.
class CarTripSummaryView {
  final int id;
  final String displayNumber;
  final String salesCarName;
  final String warehouseName;
  final DateTime openedAt;
  final DateTime? closedAt;
  final DateTime? dueDate;
  final CarTripStatus status;

  final int totalLoadedCartons;
  final int totalReturnedCartons;
  final int totalSoldCartons;
  final CarMoney totalReturnedValue;
  final CarMoney grossSubtotal;
  final CarMoney productDiscountTotal;
  final CarMoney subtotalAfterProducts;
  final CarMoney globalDiscountAmount;
  final CarMoney finalValue;
  final CarMoney paidCash;
  final CarMoney paidTransfer;

  const CarTripSummaryView({
    required this.id,
    required this.displayNumber,
    required this.salesCarName,
    required this.warehouseName,
    required this.openedAt,
    this.closedAt,
    this.dueDate,
    required this.status,
    required this.totalLoadedCartons,
    required this.totalReturnedCartons,
    required this.totalSoldCartons,
    this.totalReturnedValue = CarMoney.zero,
    required this.grossSubtotal,
    required this.productDiscountTotal,
    required this.subtotalAfterProducts,
    required this.globalDiscountAmount,
    required this.finalValue,
    required this.paidCash,
    required this.paidTransfer,
  });

  CarMoney get paidTotal => paidCash + paidTransfer;

  /// Final buying cost after product-level and global buying discounts.
  CarMoney get purchaseValue => subtotalAfterProducts - globalDiscountAmount;

  /// Selling revenue minus the final buying cost.
  CarMoney get profitValue => finalValue - purchaseValue;

  CarMoney get remaining {
    final value = finalValue - paidTotal;
    return value.isNegative ? CarMoney.zero : value;
  }

  CarPaymentStatus paymentStatus(CarPaymentEvaluator evaluator, DateTime now) =>
      evaluator.statusFor(
        totalValue: finalValue,
        paid: paidTotal,
        dueDate: dueDate,
        now: now,
      );
}
