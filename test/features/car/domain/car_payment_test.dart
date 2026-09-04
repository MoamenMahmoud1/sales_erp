import 'package:flutter_test/flutter_test.dart';

import 'package:sales_erp/features/car/domain/entities/car_payment_status.dart';
import 'package:sales_erp/features/car/domain/entities/car_trip.dart';
import 'package:sales_erp/features/car/domain/entities/car_load_item.dart';
import 'package:sales_erp/features/car/domain/entities/money.dart';
import 'package:sales_erp/features/car/domain/services/car_calculator.dart';
import 'package:sales_erp/features/car/domain/services/car_payment_evaluator.dart';
import 'package:sales_erp/features/car/domain/services/display_number.dart';

void main() {
  const calculator = CarCalculator();
  const evaluator = CarPaymentEvaluator();

  CarTrip buildTrip({
    CarPayment payment = const CarPayment(),
    DateTime? dueDate,
    int sellingMinor = 100000,
    int purchaseMinor = 100000,
  }) {
    return CarTrip(
      id: 1,
      displayNumber: '2026-000001',
      salesCarId: 1,
      salesCarName: 'Truck A',
      warehouseId: 1,
      warehouseName: 'Main',
      openedAt: DateTime(2026, 1, 1),
      dueDate: dueDate,
      items: [
        CarLoadItem(
          productId: 1,
          productName: 'A',
          unitPrice: CarMoney(sellingMinor),
          purchasePrice: CarMoney(purchaseMinor),
          loadedCartons: 1,
        ),
      ],
      payment: payment,
    );
  }

  group('remaining balance', () {
    test('partial payment leaves correct remaining buying balance', () {
      final t = buildTrip(
        payment: const CarPayment(cashAmount: CarMoney(40000)),
        sellingMinor: 100000,
        purchaseMinor: 70000,
      );
      final summary = calculator.summary(t);
      expect(summary.finalTotalSoldValue, const CarMoney(100000));
      expect(summary.totalPurchaseCost, const CarMoney(70000));
      expect(evaluator.remaining(t, summary), const CarMoney(30000));
    });

    test('selling revenue does not keep the invoice outstanding once buying cost is paid', () {
      final t = buildTrip(
        payment: const CarPayment(cashAmount: CarMoney(70000)),
        sellingMinor: 100000,
        purchaseMinor: 70000,
      );
      final summary = calculator.summary(t);
      expect(evaluator.remaining(t, summary), CarMoney.zero);
      expect(evaluator.statusOf(t, summary, DateTime(2026, 2, 1)), CarPaymentStatus.paid);
    });

    test('full payment leaves zero remaining', () {
      final t = buildTrip(payment: const CarPayment(cashAmount: CarMoney(100000)));
      final summary = calculator.summary(t);
      expect(evaluator.remaining(t, summary), CarMoney.zero);
    });

    test('overpayment clamps remaining to zero', () {
      final t = buildTrip(payment: const CarPayment(cashAmount: CarMoney(120000)));
      final summary = calculator.summary(t);
      expect(evaluator.remaining(t, summary), CarMoney.zero);
    });
  });

  group('payment status', () {
    test('paid / partially paid / unpaid', () {
      final now = DateTime(2026, 2, 1);

      final paid = buildTrip(payment: const CarPayment(cashAmount: CarMoney(100000)));
      expect(evaluator.statusOf(paid, calculator.summary(paid), now), CarPaymentStatus.paid);

      final partial = buildTrip(payment: const CarPayment(cashAmount: CarMoney(40000)));
      expect(
        evaluator.statusOf(partial, calculator.summary(partial), now),
        CarPaymentStatus.partiallyPaid,
      );

      final unpaid = buildTrip();
      expect(evaluator.statusOf(unpaid, calculator.summary(unpaid), now), CarPaymentStatus.unpaid);
    });

    test('overdue when buying balance is outstanding past due date', () {
      final now = DateTime(2026, 2, 1);
      final t = buildTrip(
        payment: const CarPayment(cashAmount: CarMoney(40000)),
        sellingMinor: 100000,
        purchaseMinor: 70000,
        dueDate: DateTime(2026, 1, 15),
      );
      final summary = calculator.summary(t);
      expect(evaluator.statusOf(t, summary, now), CarPaymentStatus.overdue);
      expect(evaluator.daysOverdue(t, now, summary: summary), 17);
    });

    test('not overdue when fully paid even past due date', () {
      final now = DateTime(2026, 2, 1);
      final t = buildTrip(
        payment: const CarPayment(cashAmount: CarMoney(70000)),
        sellingMinor: 100000,
        purchaseMinor: 70000,
        dueDate: DateTime(2026, 1, 15),
      );
      final summary = calculator.summary(t);
      expect(evaluator.statusOf(t, summary, now), CarPaymentStatus.paid);
      expect(evaluator.daysOverdue(t, now, summary: summary), 0);
    });

    test('days overdue is zero when not past due', () {
      final now = DateTime(2026, 1, 10);
      final t = buildTrip(
        payment: const CarPayment(cashAmount: CarMoney(40000)),
        sellingMinor: 100000,
        purchaseMinor: 70000,
        dueDate: DateTime(2026, 1, 20),
      );
      final summary = calculator.summary(t);
      expect(evaluator.daysOverdue(t, now, summary: summary), 0);
    });
  });

  group('display number', () {
    test('formats clean sequential number without #', () {
      const displayNumber = CarDisplayNumber();
      expect(displayNumber.create(year: 2026, sequence: 123), '2026-000123');
      expect(displayNumber.create(year: 2026, sequence: 1), '2026-000001');
      expect(displayNumber.create(year: 2026, sequence: 999999), '2026-999999');
    });
  });

  group('enum helpers', () {
    test('value and label round-trip', () {
      for (final s in CarPaymentStatus.values) {
        expect(CarPaymentStatus.fromValue(s.value), s);
        expect(s.label, isNotEmpty);
      }
    });
  });
}
