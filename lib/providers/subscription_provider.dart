import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SubscriptionProvider extends ChangeNotifier {
  static const int dailyFreeCredits = 3;
  static const String _creditsKey = 'daily_prediction_credits';
  static const String _dateKey = 'last_prediction_usage_date';
  static const String _adRewardExpiryKey = 'ad_reward_expiry_millis';

  int _credits = dailyFreeCredits;
  bool _isSubscribed = false; // Placeholder for real IAP logic
  DateTime? _adRewardExpiryTime;

  int get credits => _credits;
  bool get isSubscribed => _isSubscribed;
  DateTime? get adRewardExpiryTime => _adRewardExpiryTime;
  
  bool get isAdRewardActive => _adRewardExpiryTime != null && _adRewardExpiryTime!.isAfter(DateTime.now());

  Duration get adRewardTimeRemaining {
    if (isAdRewardActive) {
      return _adRewardExpiryTime!.difference(DateTime.now());
    }
    return Duration.zero;
  }

  SubscriptionProvider() {
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final lastUsageDate = prefs.getString(_dateKey);

    if (lastUsageDate == todayString) {
      _credits = prefs.getInt(_creditsKey) ?? dailyFreeCredits;
    } else {
      _credits = dailyFreeCredits;
      await prefs.setInt(_creditsKey, _credits);
      await prefs.setString(_dateKey, todayString);
    }

    final expiryMillis = prefs.getInt(_adRewardExpiryKey);
    if (expiryMillis != null) {
      _adRewardExpiryTime = DateTime.fromMillisecondsSinceEpoch(expiryMillis);
      if (!isAdRewardActive) {
        // Clean up expired timestamp
        await prefs.remove(_adRewardExpiryKey);
        _adRewardExpiryTime = null;
      }
    }
    
    notifyListeners();
  }
  
  bool canUseAiPrediction() {
    if (_isSubscribed || isAdRewardActive) {
      return true;
    }
    return _credits > 0;
  }

  Future<void> useAiPrediction() async {
    if (isSubscribed || isAdRewardActive) {
      return;
    }

    if (_credits > 0) {
      final prefs = await SharedPreferences.getInstance();
      final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      _credits--;
      await prefs.setInt(_creditsKey, _credits);
      await prefs.setString(_dateKey, todayString);
      notifyListeners();
    }
  }

  Future<void> grantOneHourOfPredictions() async {
    final prefs = await SharedPreferences.getInstance();
    _adRewardExpiryTime = DateTime.now().add(const Duration(hours: 1));
    await prefs.setInt(_adRewardExpiryKey, _adRewardExpiryTime!.millisecondsSinceEpoch);
    notifyListeners();
  }

  Future<void> purchaseSubscription() async {
    _isSubscribed = true;
    notifyListeners();
  }
}
