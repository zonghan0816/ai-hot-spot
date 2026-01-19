import 'package:cloud_firestore/cloud_firestore.dart';

class RecommendedHotspot {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final int? hotnessScore;
  final double distanceInMeters;
  final bool isFallback;
  final bool isTextualHint;

  const RecommendedHotspot({
    required this.id,
    required this.name,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.hotnessScore,
    this.distanceInMeters = 0.0,
    this.isFallback = false,
    this.isTextualHint = false,
  });

  RecommendedHotspot copyWith({
    String? id,
    String? name,
    double? latitude,
    double? longitude,
    int? hotnessScore,
    double? distanceInMeters,
    bool? isFallback,
    bool? isTextualHint,
  }) {
    return RecommendedHotspot(
      id: id ?? this.id,
      name: name ?? this.name,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      hotnessScore: hotnessScore ?? this.hotnessScore,
      distanceInMeters: distanceInMeters ?? this.distanceInMeters,
      isFallback: isFallback ?? this.isFallback,
      isTextualHint: isTextualHint ?? this.isTextualHint,
    );
  }

  factory RecommendedHotspot.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RecommendedHotspot(
      id: doc.id,
      name: data['name'] ?? '未命名熱點',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0.0,
      hotnessScore: (data['hotness_score'] as num?)?.toInt(),
      isFallback: data['is_fallback'] ?? false,
      isTextualHint: data['is_textual_hint'] ?? false,
    );
  }

  factory RecommendedHotspot.fromUniversal(Map<String, dynamic> data) {
    return RecommendedHotspot(
      id: data['name'], 
      name: data['name'],
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      isFallback: true, 
      isTextualHint: false,
    );
  }
}
