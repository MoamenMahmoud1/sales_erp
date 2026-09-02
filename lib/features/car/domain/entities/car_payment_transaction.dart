import 'money.dart';

/// A single, auditable payment event captured against one or more car trips.
///
/// The aggregate [totalAmount] may be split across several trips; the per-trip
/// portions are stored as [CarPaymentAllocation] rows linking back to this
/// transaction, so the original payment stays fully reconstructable.
class CarPaymentTransaction {
  final int id;
  final CarMoney cashAmount;
  final CarMoney transferAmount;
  final String? reference;
  final DateTime createdAt;

  const CarPaymentTransaction({
    this.id = 0,
    this.cashAmount = CarMoney.zero,
    this.transferAmount = CarMoney.zero,
    this.reference,
    required this.createdAt,
  });

  CarMoney get totalAmount => cashAmount + transferAmount;
}