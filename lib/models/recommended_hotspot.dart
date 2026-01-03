import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a processed, UI-ready model for a recommended hotspot.
class RecommendedHotspot {
  /// The unique ID of the hotspot from the `calculated_hotspots` collection,
  /// or a descriptive name for a local/textual hint.
  final String id;

  /// The name of the hotspot or the textual hint itself.
  final String name;

  /// The GPS latitude. Can be a dummy value for textual hints.
  final double latitude;

  /// The GPS longitude. Can be a dummy value for textual hints.
  final double longitude;

  /// The hotness score, if available.
  final int? hotnessScore;

  /// The distance in meters from the user's current location.
  /// Can be 0 for textual hints.
  final double distanceInMeters;

  /// Whether this is a fallback recommendation from the local knowledge base.
  final bool isFallback;

  /// NEW: Whether this is a non-navigable, text-only suggestion.
  final bool isTextualHint;

  const RecommendedHotspot({
    required this.id,
    required this.name,
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.hotnessScore,
    this.distanceInMeters = 0.0,
    this.isFallback = false,
    this.isTextualHint = false, // Default to false
  });

  /// Creates a RecommendedHotspot from a Firestore document.
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

  /// Creates a RecommendedHotspot from the local universal hotspot list.
  factory RecommendedHotspot.fromUniversal(Map<String, dynamic> data) {
    return RecommendedHotspot(
      id: data['name'], // Use name as ID for local hotspots
      name: data['name'],
      latitude: (data['latitude'] as num).toDouble(),
      longitude: (data['longitude'] as num).toDouble(),
      isFallback: true, // Mark this as a fallback recommendation
      isTextualHint: false, // Universal hotspots are always navigable
    );
  }
}
