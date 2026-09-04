import '../entities/car_payment_allocation.dart';
import '../entities/car_payment_transaction.dart';
import '../entities/car_trip.dart';
import '../entities/money.dart';
import 'car_calculator.dart';

class CarPaymentAllocationPlan {
  final int transactionId;
  final List<CarPaymentAllocation> allocations;
  final List<CarTrip> updatedTrips;
  final CarMoney unallocated;

  const CarPaymentAllocationPlan({
    this.transactionId = 0,
    required this.allocations,
    required this.updatedTrips,
    required this.unallocated,
  });

  bool get isFullyAllocated => unallocated == CarMoney.zero;

  CarPaymentAllocationPlan withTransactionId(int id) =>
      CarPaymentAllocationPlan(
        transactionId: id,
        allocations: allocations,
        updatedTrips: updatedTrips,
        unallocated: unallocated,
      );
}

/// Allocates one real payment to finalized outstanding invoices from exactly
/// one Car + Warehouse group. Open trips are never eligible.
///
/// Payments are settled against the invoice's final buying cost, including
/// product/global buying-side discounts. Selling revenue is not used as the
/// payment balance.
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
      throw ArgumentError(
        'A payment scope must include both Car and Warehouse.',
      );
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
              (trip.salesCarId == salesCarId &&
                  trip.warehouseId == warehouseId),
        )
        .toList()
      ..sort((a, b) {
        final date = a.openedAt.compareTo(b.openedAt);
        return date != 0 ? date : a.id.compareTo(b.id);
      });

    for (final trip in eligibleTrips) {
      final summary = calculator.summary(trip);
      final paid = trip.payment.totalPaid;
      var outstanding = summary.totalPurchaseCost - paid;
      if (outstanding.isNegative) outstanding = CarMoney.zero;
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
