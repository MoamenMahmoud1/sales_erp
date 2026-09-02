import '../../domain/entities/car_trip.dart';
import '../../domain/repositories/car_trip_repository.dart';

class CreateAndConfirmCarTrip {
  final CarTripRepository repository;

  const CreateAndConfirmCarTrip(this.repository);

  Future<CarTrip> call(CarTrip trip, {String? triggeredBy}) =>
      repository.createAndConfirmTrip(
        trip,
        triggeredBy: triggeredBy,
      );
}
