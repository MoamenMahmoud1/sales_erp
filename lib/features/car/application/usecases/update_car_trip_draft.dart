import '../../domain/entities/car_trip.dart';
import '../../domain/repositories/car_trip_repository.dart';

class UpdateCarTripDraft {
  final CarTripRepository repository;

  const UpdateCarTripDraft(this.repository);

  Future<CarTrip> call(CarTrip trip) => repository.updateDraft(trip);
}
