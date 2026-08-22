import '../../customers/domain/payment_method.dart';

class PaymentRecord {
  final int id;
  final int invoiceId;
  final int customerId;
  final double amount;
  final PaymentMethod paymentMethod;
  final DateTime createdAt;

  const PaymentRecord({
    required this.id,
    required this.invoiceId,
    required this.customerId,
    required this.amount,
    required this.paymentMethod,
    required this.createdAt,
  });

  factory PaymentRecord.fromMap(
    Map<String, Object?> map,
  ) {
    return PaymentRecord(
      id: map['id'] as int,
      invoiceId: map['invoice_id'] as int,
      customerId: map['customer_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      paymentMethod: paymentMethodFromValue(
        map['method'] as String?,
      ),
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'invoice_id': invoiceId,
      'customer_id': customerId,
      'amount': amount,
      'method': paymentMethod.value,
      'created_at':
          createdAt.toUtc().toIso8601String(),
    };
  }

  bool get isCash {
    return paymentMethod == PaymentMethod.cash;
  }

  bool get isTransfer {
    return paymentMethod == PaymentMethod.transfer;
  }
}