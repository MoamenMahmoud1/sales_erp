/// A single validation problem found on a car trip, with a user-facing
/// message. Validation failures are aggregated so the UI can show every
/// problem at once.
class CarValidationIssue {
  final String message;
  final int? productIndex;

  const CarValidationIssue({
    required this.message,
    this.productIndex,
  });
}