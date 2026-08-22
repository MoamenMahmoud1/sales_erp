import 'money.dart';

sealed class Discount {
  const Discount();
}

class FixedDiscount extends Discount {
  final Money amount;

  const FixedDiscount(this.amount);
}

class PercentageDiscount extends Discount {
  final int percentage;

  const PercentageDiscount(this.percentage);
}