/// A vehicle that carries products from the warehouse for daily distribution.
///
/// The Car entity itself is lightweight; all per-trip information lives on
/// [CarTrip]. Historical trips snapshot the [name] so later rename/plate
/// changes never alter old records.
class SalesCar {
  final int id;
  final String name;
  final String plate;
  final bool isActive;
  final DateTime createdAt;

  const SalesCar({
    this.id = 0,
    required this.name,
    this.plate = '',
    this.isActive = true,
    required this.createdAt,
  });

  SalesCar copyWith({
    int? id,
    String? name,
    String? plate,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return SalesCar(
      id: id ?? this.id,
      name: name ?? this.name,
      plate: plate ?? this.plate,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}