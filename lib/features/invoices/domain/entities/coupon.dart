import 'discount.dart';
import 'money.dart';

class Coupon {
  final String code;
  final Discount discount;
  final bool isActive;
  final DateTime? validFrom;
  final DateTime? validUntil;
  final Money? minimumInvoiceAmount;

  const Coupon({
    required this.code,
    required this.discount,
    this.isActive = true,
    this.validFrom,
    this.validUntil,
    this.minimumInvoiceAmount,
  });

  bool isValidFor(
    Money invoiceAmount,
    DateTime now,
  ) {
    if (!isActive) {
      return false;
    }

    if (validFrom != null && now.isBefore(validFrom!)) {
      return false;
    }

    if (validUntil != null && now.isAfter(validUntil!)) {
      return false;
    }

    if (minimumInvoiceAmount != null &&
        invoiceAmount < minimumInvoiceAmount!) {
      return false;
    }

    return true;
  }
}