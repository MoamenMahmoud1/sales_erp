import '../entities/car_payment_allocation.dart';
import '../entities/car_payment_transaction.dart';
import '../entities/car_revision.dart';
import '../entities/car_totals.dart';
import '../entities/car_trip.dart';
import '../entities/car_trip_filter.dart';
import '../entities/car_trip_summary_view.dart';
import '../entities/sales_car.dart';
import '../entities/warehouse.dart';

/// Persistence boundary for the Car feature.
///
/// The domain depends only on this interface — implementations map to SQLite
/// (offline) now and may be replaced/backed by an `ApiCarDataSource` later
/// without touching calculators, use cases or the UI.
abstract interface class CarRepository {
  // ---------------------------------------------------------------
  // Cars & warehouses
  // ---------------------------------------------------------------

  /// Inserts a new [SalesCar] and returns it with its assigned DB id.
  Future<SalesCar> saveCar(SalesCar car);

  Future<List<SalesCar>> getCars();

  /// Inserts a new [Warehouse] and returns it with its assigned DB id.
  Future<Warehouse> saveWarehouse(Warehouse warehouse);

  Future<List<Warehouse>> getWarehouses();

  // ---------------------------------------------------------------
  // Trips / trips lifecycle
  // ---------------------------------------------------------------

  /// Creates an open trip and its items in one transaction. Returns it with
  /// its assigned DB id.
  Future<CarTrip> createTrip(CarTrip trip);

  /// Updates an existing trip (row + items) in one transaction. The callers
  /// are responsible for persisting an immutable revision separately when a
  /// meaningful change occurs.
  Future<CarTrip> updateTrip(CarTrip trip);

  /// Closes a trip (sets status/closedAt) and writes the given revision
  /// snapshot atomically in one transaction.
  Future<CarTrip> confirmTrip(
    CarTrip trip, {
    required int revisionNumber,
    String? triggeredBy,
  });

  /// Writes an immutable revision snapshot (always appended, never replaced).
  Future<void> saveRevision(
    CarTrip trip, {
    required int revisionNumber,
    String? triggeredBy,
  });

  Future<CarTrip?> getTripById(int tripId);

  Future<CarTrip?> getTripByDisplayNumber(String displayNumber);

  Future<List<CarTrip>> getTrips({CarTripFilter? filter});

  /// Lightweight, queryable projection for lists/reports.
  Future<List<CarTripSummaryView>> getTripSummaries({CarTripFilter? filter});

  Future<List<CarRevision>> getRevisionsForTrip(int tripId);

  Future<CarRevision?> getRevision(int revisionId);

  // ---------------------------------------------------------------
  // Payments
  // ---------------------------------------------------------------

  /// Persists one payment transaction, its per-trip allocations and the
  /// updated trip payment balances atomically (all-or-nothing).
  Future<void> persistPaymentAllocation({
    required CarPaymentTransaction transaction,
    required List<CarPaymentAllocation> allocations,
    required List<CarTrip> updatedTrips,
  });

  Future<List<CarPaymentTransaction>> getPaymentTransactions();

  Future<List<CarPaymentAllocation>> getAllocationsForTransaction(
    int transactionId,
  );

  Future<List<CarPaymentAllocation>> getAllocationsForTrip(int tripId);

  // ---------------------------------------------------------------
  // Reporting
  // ---------------------------------------------------------------

  Future<CarTotals> computeTotals();
}