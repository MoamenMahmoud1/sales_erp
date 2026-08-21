enum PaymentMethod {
  cash,
  transfer,
}

enum PaymentStatus {
  paid,
  pending,
}

class Payment {
  final int id;
  final int customerId;
  final int invoiceId;
  final double amount;
  final PaymentMethod method;
  final PaymentStatus status;
  final String? reference;
  final DateTime createdAt;
  final DateTime? confirmedAt;

  const Payment({
    required this.id,
    required this.customerId,
    required this.invoiceId,
    required this.amount,
    required this.method,
    required this.status,
    this.reference,
    required this.createdAt,
    this.confirmedAt,
  });

  bool get isCash {
    return method == PaymentMethod.cash;
  }

  bool get isTransfer {
    return method == PaymentMethod.transfer;
  }

  bool get isPaid {
    return status == PaymentStatus.paid;
  }

  bool get isPending {
    return status == PaymentStatus.pending;
  }

  factory Payment.fromMap(
    Map<String, Object?> map,
  ) {
    return Payment(
      id: map['id'] as int,
      customerId: map['customer_id'] as int,
      invoiceId: map['invoice_id'] as int,
      amount: (map['amount'] as num).toDouble(),
      method: map['method'] == 'transfer'
          ? PaymentMethod.transfer
          : PaymentMethod.cash,
      status: map['status'] == 'pending'
          ? PaymentStatus.pending
          : PaymentStatus.paid,
      reference: map['reference'] as String?,
      createdAt: DateTime.parse(
        map['created_at'] as String,
      ),
      confirmedAt:
          map['confirmed_at'] == null
              ? null
              : DateTime.parse(
                  map['confirmed_at'] as String,
                ),
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'customer_id': customerId,
      'invoice_id': invoiceId,
      'amount': amount,
      'method':
          method == PaymentMethod.cash
              ? 'cash'
              : 'transfer',
      'status':
          status == PaymentStatus.pending
              ? 'pending'
              : 'paid',
      'reference': reference,
      'created_at':
          createdAt.toUtc().toIso8601String(),
      'confirmed_at':
          confirmedAt?.toUtc().toIso8601String(),
    };
  }
}