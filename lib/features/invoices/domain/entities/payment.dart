import 'money.dart';

class Payment {
  final Money cashAmount;
  final Money transferAmount;

  const Payment({
    required this.cashAmount,
    required this.transferAmount,
  });

  Money get totalPaid => cashAmount + transferAmount;

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