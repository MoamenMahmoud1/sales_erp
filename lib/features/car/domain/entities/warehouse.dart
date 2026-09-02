/// A physical location from which cars are loaded and to which unsold
/// cartons are returned at the end of the day.
class Warehouse {
  final int id;
  final String name;
  final String? location;
  final bool isActive;
  final DateTime createdAt;

  const Warehouse({
    this.id = 0,
    required this.name,
    this.location,
    this.isActive = true,
    required this.createdAt,
  });

  Warehouse copyWith({
    int? id,
    String? name,
    String? location,
    bool? isActive,
    DateTime? createdAt,
  }) {
    return Warehouse(
      id: id ?? this.id,
      name: name ?? this.name,
      location: location ?? this.location,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}