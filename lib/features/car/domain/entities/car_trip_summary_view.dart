import 'car_payment_status.dart';
import 'car_trip_status.dart';
import 'money.dart';
import '../services/car_payment_evaluator.dart';

/// Lightweight, fully queryable projection of a car trip used in lists and
/// reports. Unlike a full [CarTrip], it carries no product items, so large
/// lists/reports can be served efficiently from stored summary columns.
///
/// Financial rows are integer minor units (never doubles). Payment/overdue
/// status is derived via the domain evaluator, never computed in widgets.
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
    required this.grossSubtotal,
    required this.productDiscountTotal,
    required this.subtotalAfterProducts,
    required this.globalDiscountAmount,
    required this.finalValue,
    required this.paidCash,
    required this.paidTransfer,
  });

  CarMoney get paidTotal => paidCash + paidTransfer;

  /// Remaining balance (clamped at zero). Pure derivation — no float math.
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

  int daysOverdue(CarPaymentEvaluator evaluator, DateTime now) =>
      evaluator.daysOverdueFor(
        totalValue: finalValue,
        paid: paidTotal,
        dueDate: dueDate,
        now: now,
      );
}