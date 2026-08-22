import 'money.dart';

class Payment {
  final Money cashAmount;
  final Money transferAmount;

  const Payment({
    required this.cashAmount,
    required this.transferAmount,
  });

  Money get totalPaid => cashAmount + transferAmount;

  bool isValidFor(Money invoiceTotal) {
    if (cashAmount < Money.zero) {
      return false;
    }

    if (transferAmount < Money.zero) {
      return false;
    }

    return totalPaid <= invoiceTotal;
  }

  Payment copyWith({
  Money? cashAmount,
  Money? transferAmount,
  }) {
  return Payment(
    cashAmount: cashAmount ?? this.cashAmount,
    transferAmount: transferAmount ?? this.transferAmount,
  );
}
}