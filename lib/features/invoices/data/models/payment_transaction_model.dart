import '../../domain/entities/money.dart';
import '../../domain/entities/payment_transaction.dart';

class PaymentTransactionModel {
  final int id;
  final int customerId;
  final int cashAmount;
  final int transferAmount;
  final DateTime createdAt;

  const PaymentTransactionModel({
    required this.id,
    required this.customerId,
    required this.cashAmount,
    required this.transferAmount,
    required this.createdAt,
  });

  factory PaymentTransactionModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return PaymentTransactionModel(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      cashAmount: map['cash_amount'] as int,
      transferAmount: map['transfer_amount'] as int,
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != 0) 'id': id,
      'customer_id': customerId,
      'cash_amount': cashAmount,
      'transfer_amount': transferAmount,
      'created_at': createdAt.toIso8601String(),
    };
  }

  PaymentTransaction toEntity() {
    return PaymentTransaction(
      id: id,
      customerId: customerId,
      cashAmount: Money(cashAmount),
      transferAmount: Money(transferAmount),
      createdAt: createdAt,
    );
  }

  factory PaymentTransactionModel.fromEntity(
    PaymentTransaction entity,
  ) {
    return PaymentTransactionModel(
      id: entity.id,
      customerId: entity.customerId,
      cashAmount: entity.cashAmount.minorUnits,
      transferAmount:
          entity.transferAmount.minorUnits,
      createdAt: entity.createdAt,
    );
  }
}

