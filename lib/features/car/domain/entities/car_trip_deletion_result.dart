import 'car_trip.dart';

/// Outcome of deleting a Car trip and every payment transaction attached to it.
///
/// [recalculatedTrips] contains other trips whose paid amounts changed because
/// a shared payment transaction was removed with the deleted trip.
class CarTripDeletionResult {
  final int deletedTripId;
  final List<int> deletedPaymentTransactionIds;
  final List<CarTrip> recalculatedTrips;

  const CarTripDeletionResult({
    required this.deletedTripId,
    required this.deletedPaymentTransactionIds,
    required this.recalculatedTrips,
  });
}
