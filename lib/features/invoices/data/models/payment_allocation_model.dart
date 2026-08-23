
import '../../domain/entities/money.dart';
import '../../domain/entities/payment_allocation.dart';

class PaymentAllocationModel {
  final int? id;
  final int paymentTransactionId;
  final int invoiceId;
  final int cashAmount;
  final int transferAmount;

  const PaymentAllocationModel({
    this.id,
    required this.paymentTransactionId,
    required this.invoiceId,
    required this.cashAmount,
    required this.transferAmount,
  });

  factory PaymentAllocationModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return PaymentAllocationModel(
      id: map['id'] as int,
      paymentTransactionId:
          map['payment_transaction_id'] as int,
      invoiceId: map['invoice_id'] as int,
      cashAmount: map['cash_amount'] as int,
      transferAmount:
          map['transfer_amount'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'payment_transaction_id':
          paymentTransactionId,
      'invoice_id': invoiceId,
      'cash_amount': cashAmount,
      'transfer_amount': transferAmount,
    };
  }

  PaymentAllocation toEntity() {
    return PaymentAllocation(
      id: id ?? 0,
      paymentTransactionId:
          paymentTransactionId,
      invoiceId: invoiceId,
      cashAmount: Money(cashAmount),
      transferAmount:
          Money(transferAmount),
    );
  }

  factory PaymentAllocationModel.fromEntity(
    PaymentAllocation entity,
  ) {
    return PaymentAllocationModel(
      id: entity.id == 0
          ? null
          : entity.id,
      paymentTransactionId:
          entity.paymentTransactionId,
      invoiceId: entity.invoiceId,
      cashAmount:
          entity.cashAmount.minorUnits,
      transferAmount:
          entity.transferAmount.minorUnits,
    );
  }
}

