import 'car_load_item.dart';
import 'car_payment.dart';
import 'car_trip_status.dart';

/// An immutable snapshot of a car trip at a point in time.
///
/// Editing a trip or closing it does **not** overwrite history: a new
/// [CarRevision] is created for every meaningful change. Because every field
/// (items, quantities, prices, discounts, payments, status, display number)
/// is stored, an old revision can be reproduced exactly — later product price
/// or name edits can never mutate it.
class CarRevision {
  final int id;
  final int tripId;
  final String displayNumber;

  /// Sequential revision number; 1 is the original, each edit increments it.
  final int revisionNumber;

  final DateTime createdAt;

  /// Free-text cause/actor label when the source system supports it.
  final String? triggeredBy;

  final CarTripStatus status;
  final DateTime openedAt;
  final DateTime? closedAt;
  final DateTime? dueDate;
  final List<CarLoadItem> items;
  final double globalDiscountPercent;
  final CarPayment payment;

  const CarRevision({
    this.id = 0,
    required this.tripId,
    required this.displayNumber,
    required this.revisionNumber,
    required this.createdAt,
    this.triggeredBy,
    required this.status,
    required this.openedAt,
    this.closedAt,
    this.dueDate,
    this.items = const [],
    this.globalDiscountPercent = 0,
    this.payment = const CarPayment(),
  });
}