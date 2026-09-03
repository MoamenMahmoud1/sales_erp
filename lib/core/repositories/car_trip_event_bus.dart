import 'dart:async';

import '../../features/car/domain/entities/car_trip.dart';

/// In-memory notifications for already-loaded Car screens.
///
/// Persistence remains the source of truth. This bus only prevents redundant
/// database reads when a Car trip has just changed inside the same app process.
class CarTripEventBus {
  final StreamController<CarTrip> _controller =
      StreamController<CarTrip>.broadcast();
  final StreamController<int> _deletionController =
      StreamController<int>.broadcast();

  Stream<CarTrip> get stream => _controller.stream;
  Stream<int> get deletionStream => _deletionController.stream;

  void publish(CarTrip trip) {
    if (!_controller.isClosed) _controller.add(trip);
  }

  void publishDeleted({
    required int tripId,
    List<CarTrip> recalculatedTrips = const [],
    List<int> deletedPaymentTransactionIds = const [],
  }) {
    if (_controller.isClosed || _deletionController.isClosed) return;

    // First update any surviving trips whose payment totals were rolled back
    // because a shared payment transaction was deleted with the trip.
    for (final trip in recalculatedTrips) {
      _controller.add(trip);
    }
    _deletionController.add(tripId);
  }

  Future<void> dispose() async {
    await _controller.close();
    await _deletionController.close();
  }
}
