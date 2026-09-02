import '../../domain/entities/car_payment_transaction.dart';
import '../../domain/entities/car_trip.dart';
import '../../domain/repositories/car_payment_repository.dart';
import '../../domain/services/car_payment_allocator.dart';

class AllocateCarPayment {
  final CarPaymentRepository repository;
  final CarPaymentAllocator allocator;

  const AllocateCarPayment({
    required this.repository,
    this.allocator = const CarPaymentAllocator(),
  });

  Future<CarPaymentAllocationPlan> call({
    required CarPaymentTransaction transaction,
    required List<CarTrip> trips,
    int? salesCarId,
    int? warehouseId,
  }) async {
    final plan = allocator.allocate(
      transaction: transaction,
      trips: trips,
      salesCarId: salesCarId,
      warehouseId: warehouseId,
    );
    if (!plan.isFullyAllocated) {
      throw StateError(
        'Payment exceeds the outstanding balance for the selected Car + Warehouse group by ${plan.unallocated.units.toStringAsFixed(2)}.',
      );
    }
    await repository.persistPayment(
      transaction: transaction,
      allocations: plan.allocations,
      updatedTrips: plan.updatedTrips,
    );
    return plan;
  }
}
