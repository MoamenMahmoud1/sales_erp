import '../entities/car_revision.dart';
import '../entities/car_trip.dart';
import '../entities/car_trip_filter.dart';
import '../entities/car_trip_summary_view.dart';

abstract interface class CarTripRepository {
  Future<CarTrip> createTrip(CarTrip trip);
  Future<CarTrip> updateTrip(CarTrip trip);
  Future<CarTrip> confirmTrip(CarTrip trip, {String? triggeredBy});
  Future<CarTrip?> getTripById(int tripId);
  Future<CarTrip?> getTripByDisplayNumber(String displayNumber);
  Future<List<CarTrip>> getTrips({CarTripFilter? filter});
  Future<List<CarTripSummaryView>> getTripSummaries({CarTripFilter? filter});
  Future<List<CarRevision>> getRevisionsForTrip(int tripId);
  Future<CarRevision?> getRevision(int revisionId);
}
