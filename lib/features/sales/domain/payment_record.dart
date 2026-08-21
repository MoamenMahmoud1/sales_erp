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
      paymentMethod: PaymentMethodExtension.fromValue(
        map['payment_method'] as String? ?? 'transfer',
      ),
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
    );
  }
}