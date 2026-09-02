/// Payment status of a car invoice derived from its balance and due date.
///
/// Status is always communicated with a label + icon in the UI; it is never
/// color-only.
enum CarPaymentStatus {
  /// Final value fully covered by payments.
  paid,

  /// Some amount paid, remainder still outstanding.
  partiallyPaid,

  /// Nothing paid yet.
  unpaid,

  /// Outstanding amount past its due date.
  overdue;

  String get value {
    switch (this) {
      case CarPaymentStatus.paid:
        return 'paid';
      case CarPaymentStatus.partiallyPaid:
        return 'partially_paid';
      case CarPaymentStatus.unpaid:
        return 'unpaid';
      case CarPaymentStatus.overdue:
        return 'overdue';
    }
  }

  String get label {
    switch (this) {
      case CarPaymentStatus.paid:
        return 'Paid';
      case CarPaymentStatus.partiallyPaid:
        return 'Partially Paid';
      case CarPaymentStatus.unpaid:
        return 'Unpaid';
      case CarPaymentStatus.overdue:
        return 'Overdue';
    }
  }

  static CarPaymentStatus fromValue(String? value) {
    switch (value) {
      case 'paid':
        return CarPaymentStatus.paid;
      case 'partially_paid':
        return CarPaymentStatus.partiallyPaid;
      case 'overdue':
        return CarPaymentStatus.overdue;
      case 'unpaid':
      default:
        return CarPaymentStatus.unpaid;
    }
  }
}