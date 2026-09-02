import 'money.dart';

/// A single product entry inside a car trip, with carton quantities and a
/// product-specific discount.
///
/// This is a **snapshot**: product name and unit price are captured when the
/// product is added so later product edits never change an existing trip or
/// its revisions. Quantities are expressed in whole cartons.
class CarLoadItem {
  final int productId;
  final String productName;

  /// Snapshot unit price (per carton) at load time, in precise minor units.
  final CarMoney unitPrice;

  final int loadedCartons;
  final int returnedCartons;

  /// Product-level discount percentage in the `0..100` range.
  final double discountPercent;

  const CarLoadItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    required this.loadedCartons,
    this.returnedCartons = 0,
    this.discountPercent = 0,
  });

  int get soldCartons => loadedCartons - returnedCartons;

  CarLoadItem copyWith({
    int? productId,
    String? productName,
    CarMoney? unitPrice,
    int? loadedCartons,
    int? returnedCartons,
    double? discountPercent,
  }) {
    return CarLoadItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: unitPrice ?? this.unitPrice,
      loadedCartons: loadedCartons ?? this.loadedCartons,
      returnedCartons: returnedCartons ?? this.returnedCartons,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}