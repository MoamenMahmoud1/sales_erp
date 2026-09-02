import 'car_load_item.dart';
import 'money.dart';

/// Fully computed line for one product inside a car trip summary.
///
/// A widget only ever reads these pre-computed values; none of the sold /
/// discount math is performed in presentation code.
class CarItemLine {
  final CarLoadItem item;
  final int soldCartons;

  /// Gross sold value = unitPrice × soldCartons (no product discount yet).
  final CarMoney grossValue;

  /// Product-level discount amount for this line.
  final CarMoney discountAmount;

  /// Net value = grossValue − discountAmount.
  final CarMoney netValue;

  const CarItemLine({
    required this.item,
    required this.soldCartons,
    required this.grossValue,
    required this.discountAmount,
    required this.netValue,
  });
}