import 'car_load_item.dart';
import 'car_payment.dart';
import 'car_trip_status.dart';

/// The main Car aggregate: one daily load/sale/return cycle for a car.
///
/// While `open` the loaded quantities can be edited and returns recorded. On
/// confirmation the trip is `closed`, its display number is finalized and a
/// new [CarRevision] is captured (revision history lives in `car_revision.dart`).
///
/// The car and warehouse names are snapshotted here for stable, historical
/// display even if the referenced records are renamed later.
///
/// Financial values are never stored beyond what is needed to reproduce a
/// deterministic summary; the authoritative calculations live in the domain
/// services, so the trips stay precise and API-ready.
class CarTrip {
  final int id;

  /// Human-readable display number, e.g. `2026-000123`. Never `#123`.
  final String displayNumber;

  final int salesCarId;
  final String salesCarName;
  final int warehouseId;
  final String warehouseName;

  final DateTime openedAt;
  final DateTime? closedAt;
  final DateTime? dueDate;

  final CarTripStatus status;
  final List<CarLoadItem> items;

  /// Global discount percentage applied to the whole car transaction.
  final double globalDiscountPercent;

  final CarPayment payment;

  const CarTrip({
    this.id = 0,
    required this.displayNumber,
    required this.salesCarId,
    required this.salesCarName,
    required this.warehouseId,
    required this.warehouseName,
    required this.openedAt,
    this.closedAt,
    this.dueDate,
    this.status = CarTripStatus.open,
    this.items = const [],
    this.globalDiscountPercent = 0,
    this.payment = const CarPayment(),
  });

  bool get isClosed => status == CarTripStatus.closed;

  CarTrip copyWith({
    int? id,
    String? displayNumber,
    int? salesCarId,
    String? salesCarName,
    int? warehouseId,
    String? warehouseName,
    DateTime? openedAt,
    DateTime? closedAt,
    DateTime? dueDate,
    CarTripStatus? status,
    List<CarLoadItem>? items,
    double? globalDiscountPercent,
    CarPayment? payment,
  }) {
    return CarTrip(
      id: id ?? this.id,
      displayNumber: displayNumber ?? this.displayNumber,
      salesCarId: salesCarId ?? this.salesCarId,
      salesCarName: salesCarName ?? this.salesCarName,
      warehouseId: warehouseId ?? this.warehouseId,
      warehouseName: warehouseName ?? this.warehouseName,
      openedAt: openedAt ?? this.openedAt,
      closedAt: closedAt ?? this.closedAt,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      items: items ?? this.items,
      globalDiscountPercent: globalDiscountPercent ?? this.globalDiscountPercent,
      payment: payment ?? this.payment,
    );
  }
}