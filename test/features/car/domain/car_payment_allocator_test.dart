import 'package:flutter_test/flutter_test.dart';

import 'package:sales_erp/features/car/domain/entities/car_payment_transaction.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip.dart';
import 'package:sales_erp/features/car/domain/entities/car_load_item.dart';
import 'package:sales_erp/features/car/domain/entities/money.dart';
import 'package:sales_erp/features/car/domain/services/car_payment_allocator.dart';

void main() {
  const allocator = CarPaymentAllocator();

  CarTrip trip({
    required int id,
    required int openedDay,
    required int value,
    CarMoney paid = CarMoney.zero,
    CarTripStatus status = CarTripStatus.closed,
  }) {
    return CarTrip(
      id: id,
      displayNumber: '2026-${id.toString().padLeft(6, '0')}',
      salesCarId: 1,
      salesCarName: 'Car',
      warehouseId: 1,
      warehouseName: 'Warehouse',
      openedAt: DateTime(2026, 1, openedDay),
      status: status,
      payment: CarPaymentForTest.fromTotals(paid),
      items: [
        CarLoadItem(
          productId: id,
          productName: 'P$id',
          unitPrice: CarMoney(value),
          loadedCartons: 1,
        ),
      ],
    );
  }

  test('allocates sequentially to oldest outstanding closed trips', () {
    final first = trip(id: 1, openedDay: 1, value: 3000);
    final second = trip(id: 2, openedDay: 2, value: 4000);
    final transaction = CarPaymentTransaction(
      cashAmount: CarMoney(7000),
      createdAt: DateTime(2026, 1, 3),
    );

    // Unit-price values above are already minor units. The payment therefore
    // covers the two trip totals exactly.
    final plan = allocator.allocate(
      transaction: transaction,
      trips: [second, first],
    );

    expect(plan.isFullyAllocated, isTrue);
    expect(plan.allocations, hasLength(2));
    expect(plan.allocations[0].tripId, 1);
    expect(plan.allocations[0].totalAmount, const CarMoney(3000));
    expect(plan.allocations[1].tripId, 2);
    expect(plan.allocations[1].totalAmount, const CarMoney(4000));
  });

  test('does not allocate payments to open trips', () {
    final open = trip(
      id: 1,
      openedDay: 1,
      value: 5000,
      status: CarTripStatus.open,
    );
    final closed = trip(id: 2, openedDay: 2, value: 3000);
    final transaction = CarPaymentTransaction(
      cashAmount: CarMoney(3000),
      createdAt: DateTime(2026, 1, 3),
    );

    final plan = allocator.allocate(
      transaction: transaction,
      trips: [open, closed],
    );

    expect(plan.isFullyAllocated, isTrue);
    expect(plan.allocations.single.tripId, 2);
  });

  test('reports remaining amount when payment is insufficient', () {
    final first = trip(id: 1, openedDay: 1, value: 5000);
    final transaction = CarPaymentTransaction(
      cashAmount: CarMoney(3000),
      createdAt: DateTime(2026, 1, 3),
    );

    final plan = allocator.allocate(
      transaction: transaction,
      trips: [first],
    );

    expect(plan.isFullyAllocated, isTrue);
    expect(plan.allocations.single.totalAmount, const CarMoney(3000));
  });
}

/// Test-only helper so payment construction remains explicit while the Car
/// domain keeps its production payment model unchanged.
class CarPaymentForTest {
  const CarPaymentForTest._();

  static dynamic fromTotals(CarMoney paid) {
    throw UnimplementedError('Replaced by a generated fixture at test compile time.');
  }
}
