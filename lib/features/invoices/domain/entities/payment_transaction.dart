import 'money.dart';

class PaymentTransaction {
  final int id;
  final int customerId;
  final Money cashAmount;
  final Money transferAmount;
  final DateTime createdAt;

  const PaymentTransaction({
    required this.id,
    required this.customerId,
    required this.cashAmount,
    required this.transferAmount,
    required this.createdAt,
  });

  Money get totalAmount {
    return cashAmount + transferAmount;
  }

  PaymentTransaction copyWith({
    int? id,
    int? customerId,
    Money? cashAmount,
    Money? transferAmount,
    DateTime? createdAt,
  }) {
    return PaymentTransaction(
      id: id ?? this.id,
      customerId: customerId ?? this.customerId,
      cashAmount: cashAmount ?? this.cashAmount,
      transferAmount: transferAmount ?? this.transferAmount,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

