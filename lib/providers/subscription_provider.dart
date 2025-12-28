import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

class SubscriptionProvider extends ChangeNotifier {
  static const int dailyFreeCredits = 3;
  static const String _creditsKey = 'daily_prediction_credits';
  static const String _dateKey = 'last_prediction_usage_date';

  int _credits = dailyFreeCredits;
  bool _isSubscribed = false; // Placeholder for real IAP logic

  int get credits => _credits;
  bool get isSubscribed => _isSubscribed;

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
      // It's a new day, reset credits
      _credits = dailyFreeCredits;
      await prefs.setInt(_creditsKey, _credits);
      await prefs.setString(_dateKey, todayString);
    }

    // Placeholder: In a real app, you would check with the in_app_purchase plugin
    // e.g., _isSubscribed = await IAPService.isSubscribed();
    
    notifyListeners();
  }
  
  bool canUseAiPrediction() {
    // A subscribed user can always use the feature.
    if (_isSubscribed) {
      return true;
    }
    // A non-subscribed user can use it if they have credits.
    return _credits > 0;
  }

  Future<void> useAiPrediction() async {
    if (_isSubscribed) {
      // No need to decrement credits for subscribed users
      return;
    }

    if (_credits > 0) {
      final prefs = await SharedPreferences.getInstance();
      final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      _credits--;
      await prefs.setInt(_creditsKey, _credits);
      await prefs.setString(_dateKey, todayString); // Ensure date is always updated on use
      notifyListeners();
    }
  }

  Future<void> grantCreditsFromAd(int amount) async {
    final prefs = await SharedPreferences.getInstance();
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
    _credits += amount;
    await prefs.setInt(_creditsKey, _credits);
    await prefs.setString(_dateKey, todayString);
    notifyListeners();
  }

  // Placeholder for IAP logic
  Future<void> purchaseSubscription() async {
    // 1. Call in_app_purchase plugin to start purchase flow
    // 2. On success, set _isSubscribed = true
    // 3. Persist subscription status
    _isSubscribed = true; // Temporary for demonstration
    notifyListeners();
  }
}
