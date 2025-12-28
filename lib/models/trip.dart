class AppliedFee {
  final String name;
  final double amount;

  AppliedFee({required this.name, required this.amount});

  Map<String, dynamic> toMap(String tripId) => {
        'tripId': tripId,
        'name': name,
        'amount': amount,
      };

  factory AppliedFee.fromMap(Map<String, dynamic> map) => AppliedFee(
        name: map['name'],
        amount: map['amount'],
      );
}

class Trip {
  final String id;
  final double fare;
  final double tip;
  final bool isCash;
  final DateTime timestamp;
  final double commission; // Stored as a decimal, e.g., 0.15 for 15%
  final String? fleetName;
  final String? pickupLocation;
  final double? pickupLatitude;
  final double? pickupLongitude;
  final String? notes; // <<< NEW FIELD
  final List<AppliedFee> fees;

  Trip({
    required this.id,
    required this.fare,
    required this.tip,
    required this.isCash,
    required this.timestamp,
    required this.commission,
    this.fleetName,
    this.pickupLocation,
    this.pickupLatitude,
    this.pickupLongitude,
    this.notes, // <<< NEW IN CONSTRUCTOR
    this.fees = const [],
  });

  double get totalRevenue => fare + tip + fees.fold(0, (sum, fee) => sum + fee.amount);
  double get actualRevenue => (fare * (1 - commission)) + tip + fees.fold(0, (sum, fee) => sum + fee.amount);

  // ADDED: copyWith method for easier object updates
  Trip copyWith({
    String? id,
    double? fare,
    double? tip,
    bool? isCash,
    DateTime? timestamp,
    double? commission,
    String? fleetName,
    String? pickupLocation,
    double? pickupLatitude,
    double? pickupLongitude,
    String? notes,
    List<AppliedFee>? fees,
  }) {
    return Trip(
      id: id ?? this.id,
      fare: fare ?? this.fare,
      tip: tip ?? this.tip,
      isCash: isCash ?? this.isCash,
      timestamp: timestamp ?? this.timestamp,
      commission: commission ?? this.commission,
      fleetName: fleetName ?? this.fleetName,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      pickupLatitude: pickupLatitude ?? this.pickupLatitude,
      pickupLongitude: pickupLongitude ?? this.pickupLongitude,
      notes: notes ?? this.notes, // <<< NEW IN COPYWITH
      fees: fees ?? this.fees,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'fare': fare,
      'tip': tip,
      'isCash': isCash ? 1 : 0,
      'timestamp': timestamp.toIso8601String(),
      'commission': commission,
      'fleetName': fleetName,
      'pickupLocation': pickupLocation,
      'pickupLatitude': pickupLatitude,
      'pickupLongitude': pickupLongitude,
      'notes': notes, // <<< NEW IN TOMAP
    };
  }

  factory Trip.fromMap(Map<String, dynamic> map, {List<AppliedFee> fees = const []}) {
    return Trip(
      id: map['id'],
      fare: map['fare'],
      tip: map['tip'],
      isCash: map['isCash'] == 1,
      timestamp: DateTime.parse(map['timestamp']),
      commission: map['commission'],
      fleetName: map['fleetName'],
      pickupLocation: map['pickupLocation'],
      pickupLatitude: map['pickupLatitude'] as double?,
      pickupLongitude: map['pickupLongitude'] as double?,
      notes: map['notes'] as String?, // <<< NEW IN FROMMAP
      fees: fees,
    );
  }
}
