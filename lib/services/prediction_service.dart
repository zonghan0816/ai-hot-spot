import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:taxibook/models/recommended_hotspot.dart';

class PredictionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>>? _cachedUniversalHotspots;

  /// Fetches AI-driven hotspots from the cloud (Firestore).
  Future<List<RecommendedHotspot>> getCloudHotspots() async {
    try {
      final snapshot = await _firestore.collection('recommended_hotspots').get();
      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.map((doc) => RecommendedHotspot.fromFirestore(doc)).toList();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Firestore fetch for cloud hotspots failed: $e');
      }
    }
    return []; // Return empty list on failure or if no documents exist
  }

  /// Fetches universal hotspots from the local JSON asset.
  Future<List<RecommendedHotspot>> getUniversalHotspots() async {
    if (_cachedUniversalHotspots == null) {
      try {
        final jsonString = await rootBundle.loadString('assets/hotspots.json');
        final List<dynamic> jsonList = json.decode(jsonString);
        _cachedUniversalHotspots = jsonList.cast<Map<String, dynamic>>();
      } catch (e) {
        if (kDebugMode) {
          print('Failed to load or parse hotspots.json: $e');
        }
        return []; // Return empty if asset loading fails
      }
    }

    final now = DateTime.now();
    final activeHotspots = _cachedUniversalHotspots!
        .where((hotspotData) => _isHotspotActive(hotspotData, now))
        .map((hotspotData) => RecommendedHotspot.fromUniversal(hotspotData))
        .toList();
    return activeHotspots;
  }

  bool _isHotspotActive(Map<String, dynamic> hotspotData, DateTime now) {
    final List<dynamic> activeSlots = hotspotData['active_slots'] ?? [];
    final String currentDayType = (now.weekday >= 1 && now.weekday <= 5) ? "weekday" : "weekend";
    final int currentHour = now.hour;

    return activeSlots.any((slot) {
      final String slotDayType = slot['day_type'];
      final int startHour = slot['start_hour'];
      final int endHour = slot['end_hour'];

      if (slotDayType != "any" && slotDayType != currentDayType) {
        return false;
      }

      if (startHour > endHour) { // Overnight slot
        return currentHour >= startHour || currentHour < endHour;
      }
      
      return currentHour >= startHour && currentHour < endHour;
    });
  }
}
