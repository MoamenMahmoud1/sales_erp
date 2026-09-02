import '../entities/car_payment_allocation.dart';
import '../entities/car_payment_transaction.dart';
import '../entities/car_trip.dart';
import '../entities/money.dart';
import 'car_calculator.dart';

class CarPaymentAllocationPlan {
  final List<CarPaymentAllocation> allocations;
  final List<CarTrip> updatedTrips;
  final CarMoney unallocated;

  const CarPaymentAllocationPlan({
    required this.allocations,
    required this.updatedTrips,
    required this.unallocated,
  });

  bool get isFullyAllocated => unallocated == CarMoney.zero;
}

/// Applies one payment sequentially to the oldest outstanding Car invoices.
/// Cash and transfer amounts keep their identity throughout the allocation.
class CarPaymentAllocator {
  const CarPaymentAllocator({this.calculator = const CarCalculator()});

  final CarCalculator calculator;

  CarPaymentAllocationPlan allocate({
    required CarPaymentTransaction transaction,
    required List<CarTrip> trips,
  }) {
    var cashRemaining = transaction.cashAmount;
    var transferRemaining = transaction.transferAmount;
    final allocations = <CarPaymentAllocation>[];
    final updatedTrips = <CarTrip>[];

    final ordered = [...trips]
      ..sort((a, b) => a.openedAt.compareTo(b.openedAt));

    for (final trip in ordered) {
      final summary = calculator.summary(trip);
      var outstanding = calculator.remaining(trip, summaryOf: summary);
      if (outstanding == CarMoney.zero) continue;

      final cashAllocation = _min(cashRemaining, outstanding);
      outstanding -= cashAllocation;
      cashRemaining -= cashAllocation;

      final transferAllocation = _min(transferRemaining, outstanding);
      outstanding -= transferAllocation;
      transferRemaining -= transferAllocation;

      final applied = cashAllocation + transferAllocation;
      if (applied == CarMoney.zero) continue;

      final oldCash = trip.payment.cashAmount;
      final oldTransfer = trip.payment.transferAmount;
      final updated = trip.copyWith(
        payment: trip.payment.copyWith(
          cashAmount: oldCash + cashAllocation,
          transferAmount: oldTransfer + transferAllocation,
        ),
      );
      updatedTrips.add(updated);
      allocations.add(
        CarPaymentAllocation(
          transactionId: transaction.id,
          tripId: trip.id,
          cashAmount: cashAllocation,
          transferAmount: transferAllocation,
        ),
      );

      if (cashRemaining == CarMoney.zero &&
          transferRemaining == CarMoney.zero) {
        break;
      }
    }

    return CarPaymentAllocationPlan(
      allocations: List.unmodifiable(allocations),
      updatedTrips: List.unmodifiable(updatedTrips),
      unallocated: cashRemaining + transferRemaining,
    );
  }

  CarMoney _min(CarMoney a, CarMoney b) => a.minorUnits <= b.minorUnits ? a : b;
}
