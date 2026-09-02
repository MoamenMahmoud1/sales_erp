import '../entities/car_financial_summary.dart';
import '../entities/car_payment_status.dart';
import '../entities/car_trip.dart';
import '../entities/money.dart';
import 'car_calculator.dart';

/// Derives payment/overdue state for a car trip (or its summary view) at a
/// point in time.
class CarPaymentEvaluator {
  const CarPaymentEvaluator();

  /// Low-level status computation used by both full trips and summary views,
  /// centralizing the rule so widgets never derive it themselves.
  CarPaymentStatus statusFor({
    required CarMoney totalValue,
    required CarMoney paid,
    DateTime? dueDate,
    required DateTime now,
  }) {
    final remaining = _remaining(totalValue, paid);

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
    if (_remaining(totalValue, paid) == CarMoney.zero) {
      return 0;
    }
    if (dueDate == null || !now.isAfter(dueDate)) {
      return 0;
    }
    return now.difference(dueDate).inDays;
  }

  /// Remaining amount (pre-computed) with a zero-clamp.
  CarMoney remaining(CarTrip trip, CarFinancialSummary summary) {
    final value = summary.finalTotalSoldValue - trip.payment.totalPaid;
    return value.isNegative ? CarMoney.zero : value;
  }

  CarPaymentStatus statusOf(
    CarTrip trip,
    CarFinancialSummary summary,
    DateTime now,
  ) {
    return statusFor(
      totalValue: summary.finalTotalSoldValue,
      paid: trip.payment.totalPaid,
      dueDate: trip.dueDate,
      now: now,
    );
  }

  /// Whole days the trip is overdue; 0 when not overdue, no due date, or the
  /// balance is fully paid.
  int daysOverdue(
    CarTrip trip,
    DateTime now, {
    CarFinancialSummary? summary,
  }) {
    return daysOverdueFor(
      totalValue:
          (summary ?? /* unreachable fallback */ _fallbackSummary(trip))
              .finalTotalSoldValue,
      paid: trip.payment.totalPaid,
      dueDate: trip.dueDate,
      now: now,
    );
  }

  CarFinancialSummary _fallbackSummary(CarTrip trip) =>
      const CarCalculator().summary(trip);

  CarMoney _remaining(CarMoney totalValue, CarMoney paid) {
    final value = totalValue - paid;
    return value.isNegative ? CarMoney.zero : value;
  }
}