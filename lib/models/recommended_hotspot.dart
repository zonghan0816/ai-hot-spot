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
    // Allow dummy values for textual hints by not making them required.
    this.latitude = 0.0,
    this.longitude = 0.0,
    this.hotnessScore,
    this.distanceInMeters = 0.0,
    this.isFallback = false,
    this.isTextualHint = false, // Default to false
  });
}
