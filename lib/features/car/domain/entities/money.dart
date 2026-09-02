/// Precise, immutable monetary value stored as integer minor units.
///
/// The Car domain never performs floating-point math on financial totals; all
/// money is held as integer minor units (e.g. EGP cents) and rounding only
/// happens once, at the repository/database boundary or when a percentage is
/// applied. This keeps the Car feature self-contained and easy to extract into
/// a standalone application.
class CarMoney {
  final int minorUnits;

  const CarMoney(this.minorUnits);

  static const zero = CarMoney(0);

  /// Converts a decimal quantity (e.g. `320.5`) into minor units, rounding to
  /// the nearest minor unit. This is the only point where a floating-point
  /// price is allowed to enter the domain and is the only rounding point.
  factory CarMoney.fromUnits(double amount, {int scale = 100}) =>
      CarMoney((amount * scale).round());

  CarMoney operator +(CarMoney other) =>
      CarMoney(minorUnits + other.minorUnits);

  CarMoney operator -(CarMoney other) =>
      CarMoney(minorUnits - other.minorUnits);

  CarMoney operator *(int quantity) => CarMoney(minorUnits * quantity);

  /// Applies a percentage in the `0..100` range and rounds once.
  CarMoney percentOf(double percent) =>
      CarMoney((minorUnits * percent / 100).round());

  bool operator <(CarMoney other) => minorUnits < other.minorUnits;

  bool operator <=(CarMoney other) => minorUnits <= other.minorUnits;

  bool operator >(CarMoney other) => minorUnits > other.minorUnits;

  bool operator >=(CarMoney other) => minorUnits >= other.minorUnits;

  bool get isNegative => minorUnits < 0;

  /// Minor units converted to major units for display only.
  double get units => minorUnits / 100;

  @override
  bool operator ==(Object other) =>
      other is CarMoney && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => 'CarMoney($minorUnits)';
}