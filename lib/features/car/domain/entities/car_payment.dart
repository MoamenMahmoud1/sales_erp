import 'money.dart';

/// Payments recorded against a car trip, split by method.
///
/// Cash payments are considered immediately paid; transfer payments are paid
/// once confirmed. [totalPaid] is what is applied against a trip's final
/// value when computing the remaining balance. The history of transactions
/// and their per-invoice allocations is tracked separately so it is never
/// destroyed when a new payment is recorded.
class CarPayment {
  final CarMoney cashAmount;
  final CarMoney transferAmount;

  const CarPayment({
    this.cashAmount = CarMoney.zero,
    this.transferAmount = CarMoney.zero,
  });

  CarMoney get totalPaid => cashAmount + transferAmount;

  CarPayment copyWith({
    CarMoney? cashAmount,
    CarMoney? transferAmount,
  }) {
    return CarPayment(
      cashAmount: cashAmount ?? this.cashAmount,
      transferAmount: transferAmount ?? this.transferAmount,
    );
  }
}