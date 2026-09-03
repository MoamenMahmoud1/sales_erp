import 'dart:async';

import '../../features/car/domain/entities/car_trip.dart';

/// Describes a Car trip change that already happened in the local database.
///
/// The event is only an in-memory synchronization signal. SQLite remains the
/// source of truth and consumers must update only their in-memory state.
class CarTripChange {
  final CarTrip? trip;
  final int? deletedTripId;
  final List<CarTrip> recalculatedTrips;
  final List<int> deletedPaymentTransactionIds;

  const CarTripChange.upsert(this.trip)
      : deletedTripId = null,
        recalculatedTrips = const [],
        deletedPaymentTransactionIds = const [];

  const CarTripChange.deleted({
    required this.deletedTripId,
    this.recalculatedTrips = const [],
    this.deletedPaymentTransactionIds = const [],
  }) : trip = null;

  bool get isDeleted => deletedTripId != null;
}

/// In-memory notifications for already-loaded Car screens.
///
/// Persistence remains the source of truth. This bus only prevents redundant
/// database reads when a Car trip has just changed inside the same app process.
class CarTripEventBus {
  final StreamController<CarTripChange> _controller =
      StreamController<CarTripChange>.broadcast();

  Stream<CarTripChange> get stream => _controller.stream;

  void publish(CarTrip trip) {
    if (!_controller.isClosed) {
      _controller.add(CarTripChange.upsert(trip));
    }
  }

  void publishDeleted({
    required int tripId,
    List<CarTrip> recalculatedTrips = const [],
    List<int> deletedPaymentTransactionIds = const [],
  }) {
    if (_controller.isClosed) return;
    _controller.add(
      CarTripChange.deleted(
        deletedTripId: tripId,
        recalculatedTrips: recalculatedTrips,
        deletedPaymentTransactionIds: deletedPaymentTransactionIds,
      ),
    );
  }

  Future<void> dispose() => _controller.close();
}
