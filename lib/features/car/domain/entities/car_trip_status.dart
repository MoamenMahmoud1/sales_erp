/// Lifecycle state of a car trip/load.
///
/// A trip starts `open` when the car is being loaded and becomes `closed`
/// when the trip is confirmed/finalized (returned cartons recorded, financial
/// totals locked, history written).
enum CarTripStatus {
  open,
  closed;

  String get value {
    switch (this) {
      case CarTripStatus.open:
        return 'open';
      case CarTripStatus.closed:
        return 'closed';
    }
  }

  static CarTripStatus fromValue(String? value) {
    switch (value) {
      case 'closed':
        return CarTripStatus.closed;
      case 'open':
      default:
        return CarTripStatus.open;
    }
  }
}