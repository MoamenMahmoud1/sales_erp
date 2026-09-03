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

  /// Inclusive range on the trip confirmation/closing date/time.
  /// Useful for operational views such as "confirmed today" where openedAt
  /// must not decide which day a finalized trip belongs to.
  final DateTime? confirmedFrom;
  final DateTime? confirmedTo;

  /// Matches display number or car name (case-insensitive substring).
  final String? query;

  const CarTripFilter({
    this.status,
    this.paymentStatus,
    this.carId,
    this.warehouseId,
    this.from,
    this.to,
    this.confirmedFrom,
    this.confirmedTo,
    this.query,
  });

  bool get isEmpty =>
      status == null &&
      paymentStatus == null &&
      carId == null &&
      warehouseId == null &&
      from == null &&
      to == null &&
      confirmedFrom == null &&
      confirmedTo == null &&
      (query == null || query!.trim().isEmpty);
}
