import 'money.dart';

/// A single product entry inside a car trip.
///
/// This is a snapshot: product name and unit prices are captured when the
/// product is added so later product edits never change an existing trip or
/// its revisions. Quantities are expressed in whole cartons.
class CarLoadItem {
  final int productId;
  final String productName;

  /// Legacy unit price, retained as the selling price for existing Car code.
  final CarMoney unitPrice;

  /// Snapshot purchase cost per carton.
  final CarMoney purchasePrice;

  /// Explicit selling price per carton.
  CarMoney get sellingPrice => unitPrice;

  final int loadedCartons;
  final int returnedCartons;

  /// Product-level discount percentage in the 0..100 range.
  final double discountPercent;

  const CarLoadItem({
    required this.productId,
    required this.productName,
    required this.unitPrice,
    this.purchasePrice = CarMoney.zero,
    required this.loadedCartons,
    this.returnedCartons = 0,
    this.discountPercent = 0,
  });

  CarLoadItem copyWith({
    int? productId,
    String? productName,
    CarMoney? unitPrice,
    CarMoney? purchasePrice,
    CarMoney? sellingPrice,
    int? loadedCartons,
    int? returnedCartons,
    double? discountPercent,
  }) {
    final nextSellingPrice = sellingPrice ?? unitPrice ?? this.sellingPrice;
    return CarLoadItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      unitPrice: nextSellingPrice,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      loadedCartons: loadedCartons ?? this.loadedCartons,
      returnedCartons: returnedCartons ?? this.returnedCartons,
      discountPercent: discountPercent ?? this.discountPercent,
    );
  }
}
