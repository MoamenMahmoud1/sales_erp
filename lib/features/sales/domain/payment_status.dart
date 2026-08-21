enum PaymentStatus {
  paid,
  pending,
}

extension PaymentStatusExtension on PaymentStatus {
  String get value {
    switch (this) {
      case PaymentStatus.paid:
        return 'paid';
      case PaymentStatus.pending:
        return 'pending';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.pending:
        return 'Pending';
    }
  }

  static PaymentStatus fromValue(String value) {
    switch (value) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
      default:
        return PaymentStatus.paid;
    }
  }
}