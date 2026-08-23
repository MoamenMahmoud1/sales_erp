import '../../domain/entities/money.dart';
import '../../domain/entities/payment.dart';

class PaymentModel {
  final int id;
  final int invoiceId;
  final int cashAmount;
  final int transferAmount;

  const PaymentModel({
    required this.id,
    required this.invoiceId,
    required this.cashAmount,
    required this.transferAmount,
  });

  factory PaymentModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return PaymentModel(
      id: map['id'] as int,
      invoiceId: map['invoice_id'] as int,
      cashAmount: map['cash_amount'] as int,
      transferAmount:
          map['transfer_amount'] as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'cash_amount': cashAmount,
      'transfer_amount': transferAmount,
    };
  }

  Payment toEntity() {
    return Payment(
      cashAmount: Money(cashAmount),
      transferAmount: Money(transferAmount),
    );
  }

  factory PaymentModel.fromEntity({
    required int id,
    required int invoiceId,
    required Payment entity,
  }) {
    return PaymentModel(
      id: id,
      invoiceId: invoiceId,
      cashAmount:
          entity.cashAmount.minorUnits,
      transferAmount:
          entity.transferAmount.minorUnits,
    );
  }
}

