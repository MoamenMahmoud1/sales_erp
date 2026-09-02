import 'dart:async';

import '../../features/car/domain/entities/car_trip.dart';

/// In-memory notifications for already-loaded Car screens.
///
/// Persistence remains the source of truth. This bus only prevents redundant
/// database reads when a Car trip has just changed inside the same app process.
class CarTripEventBus {
  final StreamController<CarTrip> _controller =
      StreamController<CarTrip>.broadcast();

  Stream<CarTrip> get stream => _controller.stream;

  void publish(CarTrip trip) {
    if (!_controller.isClosed) _controller.add(trip);
  }

  Future<void> dispose() => _controller.close();
}
