import 'money.dart';

/// Payments recorded against a Car trip, split by method.
///
/// Both cash and transfer amounts are considered paid once the payment
/// transaction is successfully persisted. The current domain model does not
/// expose a separate pending-transfer state; transaction persistence is the
/// confirmation boundary. The history of transactions and their per-invoice
/// allocations is tracked separately so it is never destroyed when a new
/// payment is recorded.
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
