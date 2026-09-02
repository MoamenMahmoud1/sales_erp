import 'car_load_item.dart';
import 'car_payment.dart';
import 'car_trip_status.dart';

/// Immutable snapshot of a car trip at a point in time.
///
/// Every field required to reconstruct the historical transaction is frozen
/// here. Future edits to the current car, warehouse, products, prices or
/// discounts must never change an existing revision.
class CarRevision {
  final int id;
  final int tripId;
  final String displayNumber;
  final int revisionNumber;
  final DateTime createdAt;
  final String? triggeredBy;

  final int salesCarId;
  final String salesCarName;
  final int warehouseId;
  final String warehouseName;

  final CarTripStatus status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final DateTime? dueDate;
  final List<CarLoadItem> items;
  final double globalDiscountPercent;
  final CarPayment payment;

  const CarRevision({
    this.id = 0,
    required this.tripId,
    required this.displayNumber,
    required this.revisionNumber,
    required this.createdAt,
    this.triggeredBy,
    required this.salesCarId,
    required this.salesCarName,
    required this.warehouseId,
    required this.warehouseName,
    required this.status,
    required this.openedAt,
    this.closedAt,
    this.dueDate,
    this.items = const [],
    this.globalDiscountPercent = 0,
    this.payment = const CarPayment(),
  });
}
