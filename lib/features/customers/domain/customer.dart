enum CustomerPaymentType {
  cash,
  bankTransfer,
}

class Customer {
  final int id;
  final String name;
  final String phone;
  final String address;
  final CustomerPaymentType paymentType;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    required this.address,
    this.paymentType = CustomerPaymentType.cash,
  });

  String get paymentTypeName {
    switch (paymentType) {
      case CustomerPaymentType.cash:
        return 'Cash';
      case CustomerPaymentType.bankTransfer:
        return 'Bank Transfer';
    }
  }

  Customer copyWith({
    int? id,
    String? name,
    String? phone,
    String? address,
    CustomerPaymentType? paymentType,
  }) {
    return Customer(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      paymentType: paymentType ?? this.paymentType,
    );
  }

  factory Customer.fromMap(Map<String, Object?> map) {
    final paymentTypeValue =
        map['payment_type'] as String? ?? 'cash';

    return Customer(
      id: map['id'] as int,
      name: map['name'] as String,
      phone: map['phone'] as String,
      address: map['address'] as String,
      paymentType:
          paymentTypeValue == 'bank_transfer'
              ? CustomerPaymentType.bankTransfer
              : CustomerPaymentType.cash,
    );
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'payment_type':
          paymentType == CustomerPaymentType.cash
              ? 'cash'
              : 'bank_transfer',
    };
  }
}

