import 'money.dart';

class PaymentAllocation {
  final int id;
  final int paymentTransactionId;
  final int invoiceId;
  final Money cashAmount;
  final Money transferAmount;

  const PaymentAllocation({
    required this.id,
    required this.paymentTransactionId,
    required this.invoiceId,
    required this.cashAmount,
    required this.transferAmount,
  });

  Money get totalAmount {
    return cashAmount + transferAmount;
  }

  PaymentAllocation copyWith({
    int? id,
    int? paymentTransactionId,
    int? invoiceId,
    Money? cashAmount,
    Money? transferAmount,
  }) {
    return PaymentAllocation(
      id: id ?? this.id,
      paymentTransactionId:
          paymentTransactionId ??
              this.paymentTransactionId,
      invoiceId:
          invoiceId ?? this.invoiceId,
      cashAmount:
          cashAmount ?? this.cashAmount,
      transferAmount:
          transferAmount ?? this.transferAmount,
    );
  }
}

