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

/// Allocates one real payment to finalized outstanding invoices from exactly
/// one Car + Warehouse group. Open trips are never eligible.
class CarPaymentAllocator {
  const CarPaymentAllocator({this.calculator = const CarCalculator()});

  final CarCalculator calculator;

  CarPaymentAllocationPlan allocate({
    required CarPaymentTransaction transaction,
    required List<CarTrip> trips,
    int? salesCarId,
    int? warehouseId,
  }) {
    if (transaction.totalAmount.minorUnits <= 0) {
      throw ArgumentError('Payment amount must be greater than zero.');
    }
    if ((salesCarId == null) != (warehouseId == null)) {
      throw ArgumentError('A payment scope must include both Car and Warehouse.');
    }

    var cashRemaining = transaction.cashAmount;
    var transferRemaining = transaction.transferAmount;
    final allocations = <CarPaymentAllocation>[];
    final updatedTrips = <CarTrip>[];

    final closedTrips = trips.where((trip) => trip.isClosed).toList();

    if (salesCarId == null) {
      final groups = closedTrips
          .map((trip) => (trip.salesCarId, trip.warehouseId))
          .toSet();
      if (groups.length > 1) {
        throw StateError(
          'A payment cannot span different Cars or Warehouses. Select one Car + Warehouse group.',
        );
      }
    }

    final eligibleTrips = closedTrips
        .where(
          (trip) =>
              salesCarId == null ||
              (trip.salesCarId == salesCarId && trip.warehouseId == warehouseId),
        )
        .toList()
      ..sort((a, b) {
        final date = a.openedAt.compareTo(b.openedAt);
        return date != 0 ? date : a.id.compareTo(b.id);
      });

    for (final trip in eligibleTrips) {
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

      updatedTrips.add(
        trip.copyWith(
          payment: trip.payment.copyWith(
            cashAmount: trip.payment.cashAmount + cashAllocation,
            transferAmount: trip.payment.transferAmount + transferAllocation,
          ),
        ),
      );
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

  CarMoney _min(CarMoney a, CarMoney b) =>
      a.minorUnits <= b.minorUnits ? a : b;
}
