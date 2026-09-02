import 'car_load_item.dart';
import 'car_payment.dart';
import 'car_trip_status.dart';

export 'car_payment.dart' show CarPayment;
export 'car_trip_status.dart' show CarTripStatus;

/// One daily load → sell → return cycle for a sales car.
class CarTrip {
  final int id;

  /// Empty while composing a new trip; the repository assigns the stable
  /// human-readable number when the first save occurs.
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
  final double globalDiscountPercent;
  final CarPayment payment;

  const CarTrip({
    this.id = 0,
    this.displayNumber = '',
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
