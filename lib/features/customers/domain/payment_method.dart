enum PaymentMethod {
  cash,
  transfer,
}

extension PaymentMethodExtension on PaymentMethod {
  String get value {
    switch (this) {
      case PaymentMethod.cash:
        return 'cash';
      case PaymentMethod.transfer:
        return 'transfer';
    }
  }

  String get displayName {
    switch (this) {
      case PaymentMethod.cash:
        return 'Cash';
      case PaymentMethod.transfer:
        return 'Transfer';
    }
  }

  static PaymentMethod fromValue(String value) {
    switch (value) {
      case 'transfer':
        return PaymentMethod.transfer;
      case 'cash':
      default:
        return PaymentMethod.cash;
    }
  }
}