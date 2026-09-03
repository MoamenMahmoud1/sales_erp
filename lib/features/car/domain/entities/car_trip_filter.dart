import 'car_payment_status.dart';
import 'car_trip_status.dart';

/// Query/filter criteria for listing car trips.
///
/// [paymentStatus] is derived (overdue depends on the current time), so the
/// repository evaluates it using the domain evaluator rather than a stored,
/// time-dependent flag.
class CarTripFilter {
  final CarTripStatus? status;
  final CarPaymentStatus? paymentStatus;
  final int? carId;
  final int? warehouseId;

  /// Inclusive range on the trip opening date/time.
  final DateTime? from;
  final DateTime? to;

  /// Matches display number or car name (case-insensitive substring).
  final String? query;

  const CarTripFilter({
    this.status,
    this.paymentStatus,
    this.carId,
    this.warehouseId,
    this.from,
    this.to,
    this.query,
  });

  bool get isEmpty =>
      status == null &&
      paymentStatus == null &&
      carId == null &&
      warehouseId == null &&
      from == null &&
      to == null &&
      (query == null || query!.trim().isEmpty);
}
