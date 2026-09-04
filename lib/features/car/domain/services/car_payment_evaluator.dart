import '../entities/car_financial_summary.dart';
import '../entities/car_payment_status.dart';
import '../entities/car_trip.dart';
import '../entities/money.dart';

/// Pure payment-state rules for Car transactions.
///
/// Payment state is based on the invoice's final buying cost, not its
/// customer-facing selling revenue.
class CarPaymentEvaluator {
  const CarPaymentEvaluator();

  CarMoney remainingAmount({
    required CarMoney totalValue,
    required CarMoney paid,
  }) {
    final value = totalValue - paid;
    return value.isNegative ? CarMoney.zero : value;
  }

  CarPaymentStatus statusFor({
    required CarMoney totalValue,
    required CarMoney paid,
    DateTime? dueDate,
    required DateTime now,
  }) {
    final remaining = remainingAmount(totalValue: totalValue, paid: paid);

    if (remaining == CarMoney.zero) {
      return CarPaymentStatus.paid;
    }

    if (dueDate != null && now.isAfter(dueDate)) {
      return CarPaymentStatus.overdue;
    }

    return paid == CarMoney.zero
        ? CarPaymentStatus.unpaid
        : CarPaymentStatus.partiallyPaid;
  }

  int daysOverdueFor({
    required CarMoney totalValue,
    required CarMoney paid,
    DateTime? dueDate,
    required DateTime now,
  }) {
    if (remainingAmount(totalValue: totalValue, paid: paid) == CarMoney.zero) {
      return 0;
    }
    if (dueDate == null || !now.isAfter(dueDate)) {
      return 0;
    }
    return now.difference(dueDate).inDays;
  }

  CarMoney remaining(
    CarTrip trip,
    CarFinancialSummary summary,
  ) =>
      remainingAmount(
        totalValue: summary.totalPurchaseCost,
        paid: trip.payment.totalPaid,
      );

  CarPaymentStatus statusOf(
    CarTrip trip,
    CarFinancialSummary summary,
    DateTime now,
  ) =>
      statusFor(
        totalValue: summary.totalPurchaseCost,
        paid: trip.payment.totalPaid,
        dueDate: trip.dueDate,
        now: now,
      );

  int daysOverdue(
    CarTrip trip,
    DateTime now, {
    required CarFinancialSummary summary,
  }) =>
      daysOverdueFor(
        totalValue: summary.totalPurchaseCost,
        paid: trip.payment.totalPaid,
        dueDate: trip.dueDate,
        now: now,
      );
}
