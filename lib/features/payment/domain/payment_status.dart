enum PaymentStatus {
  pending,
  paid;

  String get value {
    switch (this) {
      case PaymentStatus.pending:
        return 'pending';
      case PaymentStatus.paid:
        return 'paid';
    }
  }

  static PaymentStatus fromValue(String? value) {
    switch (value) {
      case 'paid':
        return PaymentStatus.paid;
      case 'pending':
      default:
        return PaymentStatus.pending;
    }
  }
}