class FeeItem {
  final String id;
  final String name;
  final double defaultAmount;
  final double? latitude;
  final double? longitude;

  FeeItem({
    required this.id,
    required this.name,
    required this.defaultAmount,
    this.latitude,
    this.longitude,
  });

  // Convert a FeeItem object into a Map object for the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'defaultAmount': defaultAmount,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Create a FeeItem object from a Map object.
  factory FeeItem.fromMap(Map<String, dynamic> map) {
    return FeeItem(
      id: map['id'],
      name: map['name'],
      defaultAmount: map['defaultAmount'],
      latitude: map['latitude'],
      longitude: map['longitude'],
    );
  }
}
