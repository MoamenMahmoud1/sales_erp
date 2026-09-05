import '../entities/car_payment_allocation.dart';
import '../entities/car_payment_transaction.dart';
import '../entities/car_trip.dart';

abstract interface class CarPaymentRepository {
  Future<int> persistPayment({
    required CarPaymentTransaction transaction,
    required List<CarPaymentAllocation> allocations,
    required List<CarTrip> updatedTrips,
  });

  Future<List<CarPaymentTransaction>> getTransactions();
  Future<List<CarPaymentAllocation>> getAllocations();
  Future<List<CarPaymentAllocation>> getAllocationsForTransaction(int transactionId);
  Future<List<CarPaymentAllocation>> getAllocationsForTrip(int tripId);

  Future<void> updateAllocationPaymentDates({
    required int transactionId,
    required Map<int, DateTime> paymentDates,
  });

  /// Reverses every allocation and removes the payment event atomically.
  /// Returns the affected trip IDs so the UI can refresh only those trips.
  Future<List<int>> deleteTransaction(int transactionId);
}
