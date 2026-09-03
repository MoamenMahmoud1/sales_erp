import 'package:flutter_test/flutter_test.dart';

import 'package:sales_erp/features/car/domain/entities/car_load_item.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip.dart';
import 'package:sales_erp/features/car/domain/entities/money.dart';
import 'package:sales_erp/features/car/domain/services/car_calculator.dart';

void main() {
  const calculator = CarCalculator();

  CarLoadItem item({
    required String name,
    required int priceMinor,
    required int loaded,
    int returned = 0,
    int? purchaseMinor,
    double discountPercent = 0,
  }) {
    return CarLoadItem(
      productId: name.hashCode,
      productName: name,
      unitPrice: CarMoney(priceMinor),
      purchasePrice: CarMoney(purchaseMinor ?? priceMinor),
      loadedCartons: loaded,
      returnedCartons: returned,
      discountPercent: discountPercent,
    );
  }

  CarTrip trip({
    List<CarLoadItem> items = const [],
    double globalDiscountPercent = 0,
    CarMoney globalDiscountEgp = CarMoney.zero,
  }) {
    return CarTrip(
      id: 1,
      displayNumber: '2026-000001',
      salesCarId: 1,
      salesCarName: 'Truck A',
      warehouseId: 1,
      warehouseName: 'Main',
      openedAt: DateTime(2026, 1, 1),
      items: items,
      globalDiscountPercent: globalDiscountPercent,
      globalDiscountEgp: globalDiscountEgp,
    );
  }

  group('sold = loaded - returned', () {
    test('loaded 100 returned 20 => sold 80', () {
      final line = calculator.itemLine(
        item(name: 'P', priceMinor: 10000, loaded: 100, returned: 20),
      );
      expect(line.soldCartons, 80);
      expect(line.grossValue, const CarMoney(800000));
      expect(line.netValue, const CarMoney(800000));
    });

    test('nothing returned => sold equals loaded', () {
      final line = calculator.itemLine(item(name: 'P', priceMinor: 10000, loaded: 100));
      expect(line.soldCartons, 100);
    });
  });

  group('returned / quantity validation', () {
    test('returned cannot exceed loaded', () {
      final t = trip(items: [
        item(name: 'P', priceMinor: 10000, loaded: 10, returned: 12),
      ]);
      final issues = calculator.validate(t);
      expect(issues.any((i) => i.message.contains('cannot exceed loaded')), isTrue);
      expect(calculator.canBeClosed(t), isFalse);
    });

    test('negative quantities rejected', () {
      final t = trip(items: [
        item(name: 'P', priceMinor: 10000, loaded: -1),
        item(name: 'Q', priceMinor: 10000, loaded: 5, returned: -2),
      ]);
      final issues = calculator.validate(t);
      expect(issues.any((i) => i.message.contains('loaded cartons cannot be negative')), isTrue);
      expect(issues.any((i) => i.message.contains('returned cartons cannot be negative')), isTrue);
    });

    test('empty product list rejected on close', () {
      expect(calculator.canBeClosed(trip()), isFalse);
      expect(calculator.validate(trip()), isNotEmpty);
    });

    test('invalid discount percentages listed', () {
      final t = trip(
        items: [item(name: 'P', priceMinor: 10000, loaded: 5, discountPercent: 120)],
        globalDiscountPercent: 101,
      );
      expect(calculator.validate(t), hasLength(2));
    });
  });

  group('buying-side product discount', () {
    test('product discounts reduce buying cost, never selling revenue', () {
      final t = trip(items: [
        item(name: 'A', priceMinor: 10000, purchaseMinor: 8000, loaded: 10, discountPercent: 5),
        item(name: 'B', priceMinor: 15000, purchaseMinor: 12000, loaded: 20, discountPercent: 10),
      ]);
      final summary = calculator.summary(t);
      expect(summary.grossSubtotal, const CarMoney(400000));
      expect(summary.finalTotalSoldValue, const CarMoney(400000));
      expect(summary.productDiscountTotal, const CarMoney(28000));
      expect(summary.subtotalAfterProducts, const CarMoney(292000));
      expect(summary.totalPurchaseCost, const CarMoney(292000));
      expect(summary.profit, const CarMoney(108000));
      expect(summary.items[0].netValue, const CarMoney(100000));
      expect(summary.items[0].purchaseCost, const CarMoney(80000));
      expect(summary.items[0].discountAmount, const CarMoney(4000));
    });

    test('rounds once using integer minor units', () {
      final t = trip(items: [
        item(name: 'A', priceMinor: 500, purchaseMinor: 333, loaded: 3, discountPercent: 50),
      ]);
      final summary = calculator.summary(t);
      expect(summary.productDiscountTotal, const CarMoney(500));
      expect(summary.subtotalAfterProducts, const CarMoney(499));
      expect(summary.finalTotalSoldValue, const CarMoney(1500));
    });
  });

  group('global buying discounts', () {
    test('percentage applies to buying cost while selling stays unchanged', () {
      final t = trip(
        items: [
          item(name: 'A', priceMinor: 10000, purchaseMinor: 8000, loaded: 10),
        ],
        globalDiscountPercent: 10,
      );
      final summary = calculator.summary(t);
      expect(summary.finalTotalSoldValue, const CarMoney(100000));
      expect(summary.totalPurchaseCost, const CarMoney(72000));
    });

    test('fixed EGP discount is added on buying cost only', () {
      final t = trip(
        items: [
          item(name: 'A', priceMinor: 10000, purchaseMinor: 8000, loaded: 10),
        ],
        globalDiscountEgp: const CarMoney(5000),
      );
      final summary = calculator.summary(t);
      expect(summary.finalTotalSoldValue, const CarMoney(100000));
      expect(summary.totalPurchaseCost, const CarMoney(75000));
    });

    test('fixed discount cannot exceed remaining buying cost', () {
      final t = trip(
        items: [
          item(name: 'A', priceMinor: 10000, purchaseMinor: 8000, loaded: 10),
        ],
        globalDiscountEgp: const CarMoney(90000),
      );
      expect(calculator.validate(t), isNotEmpty);
    });

    test('carton totals aggregate correctly', () {
      final t = trip(items: [
        item(name: 'A', priceMinor: 10000, loaded: 10, returned: 2),
        item(name: 'B', priceMinor: 5000, loaded: 5, returned: 1),
      ]);
      final summary = calculator.summary(t);
      expect(summary.totalLoadedCartons, 15);
      expect(summary.totalReturnedCartons, 3);
      expect(summary.totalSoldCartons, 12);
    });
  });
}
