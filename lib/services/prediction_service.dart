import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:taxibook/models/recommended_hotspot.dart';

class PredictionService {
  // Cache for the loaded hotspots to avoid repeated file reads.
  List<Map<String, dynamic>>? _cachedUniversalHotspots;

  /// Fetches recommended hotspots.
  /// This version loads hotspots from a JSON asset file to prevent release build crashes.
  Future<List<RecommendedHotspot>> getRecommendedHotspots({double? latitude, double? longitude}) async {
    // In a real-world scenario, you would pass latitude and longitude to a cloud function.
    // For this implementation, we fall back to a local, universal list.
    return _getUniversalHotspots();
  }

  /// Loads universal hotspots from the asset file, caches them, and filters them.
  Future<List<RecommendedHotspot>> _getUniversalHotspots() async {
    if (_cachedUniversalHotspots == null) {
      if (kDebugMode) {
        print("Loading hotspots from assets for the first time...");
      }
      final jsonString = await rootBundle.loadString('assets/hotspots.json');
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedUniversalHotspots = jsonList.cast<Map<String, dynamic>>();
    }

    final now = DateTime.now();
    final activeHotspots = _cachedUniversalHotspots!
        .where((hotspotData) => _isHotspotActive(hotspotData, now))
        .map((hotspotData) => RecommendedHotspot.fromUniversal(hotspotData))
        .toList();
    return activeHotspots;
  }

  /// Checks if a universal hotspot is active at the given time.
  /// Correctly handles "weekday", "weekend", and "any".
  bool _isHotspotActive(Map<String, dynamic> hotspotData, DateTime now) {
    final List<dynamic> activeSlots = hotspotData['active_slots'];
    final String currentDayType = (now.weekday >= 1 && now.weekday <= 5) ? "weekday" : "weekend";
    final int currentHour = now.hour;

    return activeSlots.any((slot) {
      final String slotDayType = slot['day_type'];
      final int startHour = slot['start_hour'];
      final int endHour = slot['end_hour'];

      // If day_type is "any", it's always valid for the day check.
      if (slotDayType != "any" && slotDayType != currentDayType) {
        return false;
      }

      // Handle overnight slots (e.g., 20:00 - 07:00)
      if (startHour > endHour) {
        return currentHour >= startHour || currentHour < endHour;
      }
      
      // Handle regular daytime slots
      return currentHour >= startHour && currentHour < endHour;
    });
  }
}
