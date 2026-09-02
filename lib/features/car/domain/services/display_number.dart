/// Builds clean, human-readable display numbers such as `2026-000123`.
///
/// The technical integer database id is never shown to users; this number is
/// the stable, sequential identifier used across lists, details and reports.
class CarDisplayNumber {
  const CarDisplayNumber();

  /// Formats a sequential counter for a given calendar year.
  /// Example: `(2026, 123)` → `2026-000123`.
  String create({required int year, required int sequence}) =>
      '$year-${sequence.toString().padLeft(6, '0')}';
}