import '../entities/money.dart';

class CollectionAllocation {
  final int invoiceId;
  final Money cashAmount;
  final Money transferAmount;

  const CollectionAllocation({
    required this.invoiceId,
    required this.cashAmount,
    required this.transferAmount,
  });

  Money get totalAmount {
    return cashAmount + transferAmount;
  }
}