import '../../domain/entities/car_trip.dart';
import '../../domain/repositories/car_trip_repository.dart';

class ConfirmCarTrip {
  final CarTripRepository repository;

  const ConfirmCarTrip(this.repository);

  Future<CarTrip> call(CarTrip trip, {String? triggeredBy}) =>
      repository.confirmTrip(
        trip,
        triggeredBy: triggeredBy,
      );
}
