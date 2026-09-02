import 'money.dart';

/// The share of a [CarPaymentTransaction] allocated to one car trip.
///
/// Keeps the relationship between the original payment and the affected
/// trips: one transaction has many allocations, never unrelated single
/// payments.
class CarPaymentAllocation {
  final int id;
  final int transactionId;
  final int tripId;
  final CarMoney cashAmount;
  final CarMoney transferAmount;

  const CarPaymentAllocation({
    this.id = 0,
    required this.transactionId,
    required this.tripId,
    this.cashAmount = CarMoney.zero,
    this.transferAmount = CarMoney.zero,
  });

  CarMoney get totalAmount => cashAmount + transferAmount;
}