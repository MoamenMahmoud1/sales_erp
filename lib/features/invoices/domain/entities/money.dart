class Money {
  final int minorUnits;

  const Money(this.minorUnits);

  static const zero = Money(0);

  Money operator +(Money other) {
    return Money(minorUnits + other.minorUnits);
  }

  Money operator -(Money other) {
    return Money(minorUnits - other.minorUnits);
  }

  Money operator *(int quantity) {
    return Money(minorUnits * quantity);
  }

  bool operator <(Money other) {
    return minorUnits < other.minorUnits;
  }

  bool operator <=(Money other) {
    return minorUnits <= other.minorUnits;
  }

  bool operator >(Money other) {
    return minorUnits > other.minorUnits;
  }

  bool operator >=(Money other) {
    return minorUnits >= other.minorUnits;
  }

  @override
  bool operator ==(Object other) {
    return other is Money && other.minorUnits == minorUnits;
  }

  @override
  int get hashCode => minorUnits.hashCode;
}