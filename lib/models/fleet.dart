enum FleetType {
  regular, // 小黃
  diverse,   // 多元
}

class Fleet {
  final String id;
  final String name;
  final FleetType type;
  final double defaultCommission; // e.g., 0.25 for 25%
  final List<String> fareTypes; // 車資類別
  final bool isDefault; // 是否為預設車隊

  Fleet({
    required this.id,
    required this.name,
    required this.type,
    required this.defaultCommission,
    this.fareTypes = const [],
    this.isDefault = false, // Default to false
  });

  // Convert a Fleet object into a Map object for the database.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.index,
      'defaultCommission': defaultCommission,
      'fareTypes': fareTypes.join(','),
      'isDefault': isDefault ? 1 : 0, // Store bool as integer
    };
  }

  // Create a Fleet object from a Map object.
  factory Fleet.fromMap(Map<String, dynamic> map) {
    return Fleet(
      id: map['id'],
      name: map['name'],
      type: FleetType.values[map['type']],
      defaultCommission: map['defaultCommission'],
      fareTypes: (map['fareTypes'] as String? ?? '').split(',').where((s) => s.isNotEmpty).toList(),
      isDefault: (map['isDefault'] as int? ?? 0) == 1, // Convert integer back to bool
    );
  }

  String get typeDisplay {
    switch (type) {
      case FleetType.regular:
        return '小黃';
      case FleetType.diverse:
        return '多元';
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Fleet && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
