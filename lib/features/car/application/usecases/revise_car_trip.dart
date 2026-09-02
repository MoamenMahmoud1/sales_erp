import '../../domain/entities/car_trip.dart';
import '../../domain/repositories/car_trip_repository.dart';

class ReviseCarTrip {
  final CarTripRepository repository;

  const ReviseCarTrip(this.repository);

  Future<CarTrip> call(CarTrip trip, {String? triggeredBy}) =>
      repository.reviseClosedTrip(
        trip,
        triggeredBy: triggeredBy,
      );
}
