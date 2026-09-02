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
    double discountPercent = 0,
  }) {
    return CarLoadItem(
      productId: name.hashCode,
      productName: name,
      unitPrice: CarMoney(priceMinor),
      loadedCartons: loaded,
      returnedCartons: returned,
      discountPercent: discountPercent,
    );
  }

  CarTrip trip({
    List<CarLoadItem> items = const [],
    double globalDiscountPercent = 0,
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
    );
  }

  group('sold = loaded - returned', () {
    test('loaded 100 returned 20 => sold 80', () {
      final line = calculator.itemLine(
        item(name: 'P', priceMinor: 10000, loaded: 100, returned: 20),
      );
      expect(line.soldCartons, 80);
      expect(line.grossValue, const CarMoney(800000));
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
      expect(
        issues.any((i) => i.message.contains('loaded cartons cannot be negative')),
        isTrue,
      );
      expect(
        issues.any((i) => i.message.contains('returned cartons cannot be negative')),
        isTrue,
      );
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

  group('product discount', () {
    test('gross = unit x sold, discount independent per product', () {
      final t = trip(items: [
        item(name: 'A', priceMinor: 10000, loaded: 10, discountPercent: 5),
        item(name: 'B', priceMinor: 15000, loaded: 20, discountPercent: 10),
      ]);
      final summary = calculator.summary(t);
      // A: 10 x 100.00 = 1000.00, 5% -> 50.00; B: 20 x 150.00 = 3000.00, 10% -> 300.00
      expect(summary.grossSubtotal, const CarMoney(400000));
      expect(summary.productDiscountTotal, const CarMoney(35000));
      expect(summary.subtotalAfterProducts, const CarMoney(365000));
      expect(summary.items[0].netValue, const CarMoney(95000));
      expect(summary.items[1].netValue, const CarMoney(270000));
    });

    test('rounds once using integer minor units', () {
      final t = trip(items: [
        item(name: 'A', priceMinor: 333, loaded: 3, discountPercent: 50),
      ]);
      final summary = calculator.summary(t);
      expect(summary.productDiscountTotal, const CarMoney(500));
      expect(summary.subtotalAfterProducts, const CarMoney(499));
    });
  });

  group('global discount', () {
    test('applied after product discounts, once', () {
      final t = trip(
        items: [item(name: 'A', priceMinor: 100000, loaded: 10)],
        globalDiscountPercent: 10,
      );
      final summary = calculator.summary(t);
      expect(summary.subtotalAfterProducts, const CarMoney(1000000));
      expect(summary.globalDiscountAmount, const CarMoney(100000));
      expect(summary.finalTotalSoldValue, const CarMoney(900000));
    });

    test('product + global combined do not double-discount', () {
      final t = trip(
        items: [item(name: 'A', priceMinor: 100000, loaded: 10, discountPercent: 10)],
        globalDiscountPercent: 10,
      );
      final summary = calculator.summary(t);
      expect(summary.productDiscountTotal, const CarMoney(100000));
      expect(summary.subtotalAfterProducts, const CarMoney(900000));
      expect(summary.globalDiscountAmount, const CarMoney(90000));
      expect(summary.finalTotalSoldValue, const CarMoney(810000));
    });
  });

  group('carton totals', () {
    test('loaded / returned / sold totals aggregate correctly', () {
      final t = trip(items: [
        item(name: 'A', priceMinor: 100, loaded: 100, returned: 20),
        item(name: 'B', priceMinor: 200, loaded: 50, returned: 10),
      ]);
      final summary = calculator.summary(t);
      expect(summary.totalLoadedCartons, 150);
      expect(summary.totalReturnedCartons, 30);
      expect(summary.totalSoldCartons, 120);
    });
  });
}