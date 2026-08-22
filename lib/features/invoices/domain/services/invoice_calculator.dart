import '../entities/discount.dart';
import '../entities/invoice.dart';
import '../entities/money.dart';

class InvoiceCalculator {
  const InvoiceCalculator();

  Money calculateSubtotal(Invoice invoice) {
    var subtotal = Money.zero;

    for (final item in invoice.items) {
      subtotal += item.total;
    }

    return subtotal;
  }

  int calculateTotalQuantity(Invoice invoice) {
    var totalQuantity = 0;

    for (final item in invoice.items) {
      totalQuantity += item.quantity;
    }

    return totalQuantity;
  }

  Money calculateDiscount(Invoice invoice) {
    final coupon = invoice.coupon;

    if (coupon == null) {
      return Money.zero;
    }

    final subtotal = calculateSubtotal(invoice);

    if (!coupon.isValidFor(subtotal, DateTime.now())) {
      return Money.zero;
    }

    switch (coupon.discount) {
      case FixedDiscount(:final amount):
        return amount;

      case PercentageDiscount(:final percentage):
        return Money(
          (subtotal.minorUnits * percentage / 100).round(),
        );
    }
  }

  Money calculateTotal(Invoice invoice) {
    final subtotal = calculateSubtotal(invoice);
    final discount = calculateDiscount(invoice);

    return subtotal - discount;
  }

  Money calculateTotalPaid(Invoice invoice) {
    return invoice.payment.totalPaid;
  }

  Money calculateRemaining(Invoice invoice) {
    final total = calculateTotal(invoice);
    final paid = calculateTotalPaid(invoice);

    return total - paid;
  }
}