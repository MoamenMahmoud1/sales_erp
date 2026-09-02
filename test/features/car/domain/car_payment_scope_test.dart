import 'package:flutter_test/flutter_test.dart';

import 'package:sales_erp/features/car/domain/entities/car_load_item.dart';
import 'package:sales_erp/features/car/domain/entities/car_payment_transaction.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip.dart';
import 'package:sales_erp/features/car/domain/entities/money.dart';
import 'package:sales_erp/features/car/domain/services/car_payment_allocator.dart';

void main() {
  const allocator = CarPaymentAllocator();

  CarTrip trip({
    required int id,
    required int carId,
    required int warehouseId,
    required int value,
    required int day,
  }) {
    return CarTrip(
      id: id,
      displayNumber: '2026-${id.toString().padLeft(6, '0')}',
      salesCarId: carId,
      salesCarName: 'Car $carId',
      warehouseId: warehouseId,
      warehouseName: 'Warehouse $warehouseId',
      openedAt: DateTime(2026, 1, day),
      items: [
        CarLoadItem(
          productId: id,
          productName: 'Product $id',
          unitPrice: CarMoney(value),
          loadedCartons: 1,
        ),
      ],
    );
  }

  test('allocates only inside the selected Car + Warehouse group', () {
    final selectedGroupFirst = trip(
      id: 1,
      carId: 1,
      warehouseId: 1,
      value: 3000,
      day: 1,
    );
    final selectedGroupSecond = trip(
      id: 2,
      carId: 1,
      warehouseId: 1,
      value: 4000,
      day: 2,
    );
    final differentCar = trip(
      id: 3,
      carId: 2,
      warehouseId: 1,
      value: 9000,
      day: 3,
    );

    final plan = allocator.allocate(
      transaction: CarPaymentTransaction(
        cashAmount: CarMoney(7000),
        createdAt: DateTime(2026, 1, 4),
      ),
      trips: [differentCar, selectedGroupSecond, selectedGroupFirst],
      salesCarId: 1,
      warehouseId: 1,
    );

    expect(plan.isFullyAllocated, isTrue);
    expect(plan.allocations.map((item) => item.tripId), [1, 2]);
    expect(plan.allocations.any((item) => item.tripId == 3), isFalse);
  });

  test('rejects an unscoped payment when multiple Car + Warehouse groups are mixed', () {
    final first = trip(
      id: 1,
      carId: 1,
      warehouseId: 1,
      value: 3000,
      day: 1,
    );
    final second = trip(
      id: 2,
      carId: 2,
      warehouseId: 1,
      value: 4000,
      day: 2,
    );

    expect(
      () => allocator.allocate(
        transaction: CarPaymentTransaction(
          cashAmount: CarMoney(7000),
          createdAt: DateTime(2026, 1, 3),
        ),
        trips: [first, second],
      ),
      throwsA(isA<StateError>()),
    );
  });
}
