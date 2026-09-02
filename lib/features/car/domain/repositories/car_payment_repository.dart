import '../entities/car_payment_allocation.dart';
import '../entities/car_payment_transaction.dart';
import '../entities/car_trip.dart';

abstract interface class CarPaymentRepository {
  Future<void> persistPayment({
    required CarPaymentTransaction transaction,
    required List<CarPaymentAllocation> allocations,
    required List<CarTrip> updatedTrips,
  });

  Future<List<CarPaymentTransaction>> getTransactions();
  Future<List<CarPaymentAllocation>> getAllocationsForTransaction(int transactionId);
  Future<List<CarPaymentAllocation>> getAllocationsForTrip(int tripId);
}
