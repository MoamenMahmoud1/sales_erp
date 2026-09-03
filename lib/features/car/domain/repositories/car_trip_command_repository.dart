import '../entities/car_trip_deletion_result.dart';
import 'car_trip_repository.dart';

/// Write-side Car trip operations that need explicit lifecycle commands.
abstract interface class CarTripCommandRepository implements CarTripRepository {
  Future<CarTripDeletionResult> deleteTrip(int tripId);
}
