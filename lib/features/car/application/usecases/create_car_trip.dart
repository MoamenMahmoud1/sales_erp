import '../../domain/entities/car_trip.dart';
import '../../domain/repositories/car_trip_repository.dart';

class CreateCarTrip {
  final CarTripRepository repository;

  const CreateCarTrip(this.repository);

  Future<CarTrip> call(CarTrip trip) => repository.createTrip(trip);
}
