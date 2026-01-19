import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxibook/models/fleet.dart';
import 'package:taxibook/models/recommended_hotspot.dart';
import 'package:taxibook/providers/subscription_provider.dart';
import 'package:taxibook/services/ad_service.dart';
import 'package:taxibook/services/database_service.dart';
import 'package:taxibook/services/prediction_service.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  HomeScreenState createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  final DatabaseService _databaseService = DatabaseService();
  final PredictionService _predictionService = PredictionService();
  final AdService _adService = AdService();
  bool _isPredicting = false;
  RecommendedHotspot? _recommendedHotspot;
  String? _predictionError;

  Fleet? _selectedFleet;
  bool _isWorking = false;
  Duration _accumulatedWorkDuration = Duration.zero;
  DateTime? _lastStartTime;
  Timer? _workTimer;
  double _todayRevenue = 0.0;
  double _hourlyRate = 0.0;
  Timer? _idleTimer;
  Timer? _secondReminderTimer;
  DateTime? _lastActivityTime;
  double _targetHourlyRate = 300;
  int _idleAlertLevel = 0;
  double _dailyGoal = 0.0;
  double _goalProgress = 0.0;

  Timer? _adRewardTimer;

  @override
  void initState() {
    super.initState();
    loadInitialData();
    _adService.loadRewardedAd();
  }

  @override
  void dispose() {
    _workTimer?.cancel();
    _adRewardTimer?.cancel();
    stopAllIdleTimers();
    super.dispose();
  }

  void _manageAdRewardTimer(SubscriptionProvider subProvider) {
    if (subProvider.isAdRewardActive) {
      if (_adRewardTimer == null || !_adRewardTimer!.isActive) {
        _adRewardTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted && subProvider.isAdRewardActive) {
            setState(() {}); // Just rebuild to update the timer text
          } else {
            _adRewardTimer?.cancel();
            if(mounted) setState(() {}); // Final rebuild to clear the timer text
          }
        });
      }
    } else {
      _adRewardTimer?.cancel();
    }
  }

  Future<void> loadInitialData() async {
    final fleets = await _databaseService.getFleets();
    String? dailyGoalStr = await _databaseService.getSetting('dailyGoal');
    _dailyGoal = double.tryParse(dailyGoalStr ?? '0') ?? 0.0;
    String? targetRateStr = await _databaseService.getSetting('targetHourlyRate');
    _targetHourlyRate = double.tryParse(targetRateStr ?? '300') ?? 300.0;

    await _loadShiftState();
    await _updateTodayRevenue();

    if (mounted) {
      setState(() {
        try {
          _selectedFleet = fleets.firstWhere((f) => f.isDefault);
        } catch (e) {
          _selectedFleet = fleets.isNotEmpty ? fleets.first : null;
        }
      });
    }
    if (_isWorking) {
      resetIdleTimerAfterTrip();
    }
  }

  Future<void> _updateTodayRevenue() async {
    final todayTrips = await _databaseService.getTripsForToday();
    double totalRevenue = 0;
    for (var trip in todayTrips) {
      totalRevenue += trip.actualRevenue;
    }
    _calculateCurrentHourlyRate();
    if (mounted) {
      setState(() {
        _todayRevenue = totalRevenue;
        if (_dailyGoal > 0) {
          _goalProgress = _todayRevenue / _dailyGoal;
        }
      });
    }
  }

  Future<void> _loadShiftState() async {
    final prefs = await SharedPreferences.getInstance();
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final storedDateString = prefs.getString('shift_date');

    if (storedDateString != todayString) {
      await _resetShiftData(prefs);
    } else {
      _isWorking = prefs.getBool('is_working') ?? false;
      final accumulatedSeconds = prefs.getInt('accumulated_duration_seconds') ?? 0;
      _accumulatedWorkDuration = Duration(seconds: accumulatedSeconds);
      final lastStartMillis = prefs.getInt('last_start_time_millis');
      if (lastStartMillis != null) {
        _lastStartTime = DateTime.fromMillisecondsSinceEpoch(lastStartMillis);
      }
      if (_isWorking && _lastStartTime != null) {
        _workTimer?.cancel();
        _workTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateWorkDuration());
      }
    }
    _updateWorkDuration();
  }

  Future<void> _resetShiftData(SharedPreferences prefs) async {
    _workTimer?.cancel();
    await prefs.remove('shift_date');
    await prefs.remove('is_working');
    await prefs.remove('accumulated_duration_seconds');
    await prefs.remove('last_start_time_millis');
    setState(() {
      _isWorking = false;
      _accumulatedWorkDuration = Duration.zero;
      _lastStartTime = null;
      _hourlyRate = 0.0;
    });
  }

  void _toggleWorkStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final todayString = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (prefs.getString('shift_date') == null) {
      await prefs.setString('shift_date', todayString);
    }
    setState(() {
      _isWorking = !_isWorking;
      if (_isWorking) {
        _lastStartTime = DateTime.now();
        prefs.setInt('last_start_time_millis', _lastStartTime!.millisecondsSinceEpoch);
        _workTimer?.cancel();
        _workTimer = Timer.periodic(const Duration(seconds: 1), (timer) => _updateWorkDuration());
        resetIdleTimerAfterTrip();
      } else {
        _workTimer?.cancel();
        if (_lastStartTime != null) {
          final sessionDuration = DateTime.now().difference(_lastStartTime!);
          _accumulatedWorkDuration += sessionDuration;
          prefs.setInt('accumulated_duration_seconds', _accumulatedWorkDuration.inSeconds);
        }
        stopAllIdleTimers();
      }
      prefs.setBool('is_working', _isWorking);
    });
    _updateWorkDuration();
  }

  void _updateWorkDuration() {
    if (!mounted) return;
    Duration currentTotalDuration = _accumulatedWorkDuration;
    if (_isWorking && _lastStartTime != null) {
      currentTotalDuration += DateTime.now().difference(_lastStartTime!);
    }
    _calculateCurrentHourlyRate(duration: currentTotalDuration);
    setState(() {});
  }

  void _calculateCurrentHourlyRate({Duration? duration}) {
    final totalDuration = duration ?? _accumulatedWorkDuration;
    if (totalDuration.inSeconds > 300) {
      final hours = totalDuration.inSeconds / 3600;
      _hourlyRate = (hours > 0) ? _todayRevenue / hours : 0.0;
    } else {
      _hourlyRate = 0.0;
    }
  }

  Future<void> _triggerHotspotPrediction({bool isAutoTrigger = false}) async {
    final subProvider = context.read<SubscriptionProvider>();
    final isPremiumUser = subProvider.isSubscribed || subProvider.isAdRewardActive;

    if (!isAutoTrigger && !isPremiumUser && subProvider.credits <= 0) {
      _showUpsellDialog();
      return;
    }

    setState(() => _isPredicting = true);
    _recommendedHotspot = null;
    _predictionError = null;

    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      const double searchRadiusMeters = 1000; // 1km

      if (!isAutoTrigger && !isPremiumUser) {
        await subProvider.useAiPrediction();
      }

      List<RecommendedHotspot> allAvailableHotspots = [];

      // 1. Fetch personal and universal hotspots for ALL users
      final personalHotspotsFuture = _databaseService.getFeeItems();
      final universalHotspotsFuture = _predictionService.getUniversalHotspots();

      // 2. Fetch cloud hotspots ONLY for premium users
      final Future<List<RecommendedHotspot>> cloudHotspotsFuture = 
          isPremiumUser ? _predictionService.getCloudHotspots() : Future.value([]);

      final results = await Future.wait([
        personalHotspotsFuture,
        universalHotspotsFuture,
        cloudHotspotsFuture,
      ]);

      final personalHotspots = results[0] as List<dynamic>;
      final universalHotspots = results[1] as List<RecommendedHotspot>;
      final cloudHotspots = results[2] as List<RecommendedHotspot>;

      // 3. Combine all hotspots
      for (var item in personalHotspots) {
        if (item.latitude != null && item.longitude != null) {
          allAvailableHotspots.add(RecommendedHotspot(
            id: item.id,
            name: item.name,
            latitude: item.latitude!,
            longitude: item.longitude!,
            distanceInMeters: 0, // Will be calculated below
            isFallback: true, // Treat personal hotspots as a type of fallback
          ));
        }
      }
      allAvailableHotspots.addAll(universalHotspots);
      allAvailableHotspots.addAll(cloudHotspots);

      // 4. Geo-filter and calculate distances
      final List<RecommendedHotspot> nearbyHotspots = [];
      for (var hotspot in allAvailableHotspots) {
        final distance = Geolocator.distanceBetween(position.latitude, position.longitude, hotspot.latitude, hotspot.longitude);
        if (distance <= searchRadiusMeters) {
          final updatedHotspot = hotspot.copyWith(distanceInMeters: distance);
          nearbyHotspots.add(updatedHotspot);
        }
      }

      // 5. Recommend the best option
      if (nearbyHotspots.isEmpty) {
        if (isAutoTrigger) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('您附近 1 公里內無可用熱點建議。')));
        } else {
          setState(() => _predictionError = '您附近 1 公里內無可用熱點建議。');
        }
      } else {
        nearbyHotspots.sort((a, b) => a.distanceInMeters.compareTo(b.distanceInMeters));
        final nearestHotspot = nearbyHotspots.first;

        if (isAutoTrigger) {
          _showHotspotSuggestionDialog(nearestHotspot);
        } else {
          setState(() => _recommendedHotspot = nearestHotspot);
        }
      }
    } catch (e) {
      final errorMessage = e.toString().replaceAll('Exception: ', '');
      if (isAutoTrigger) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('無法建議熱點: $errorMessage'), backgroundColor: Colors.red));
      } else {
        if (errorMessage.contains('權限')) {
          _showPermissionDialog(errorMessage);
        } else {
          setState(() => _predictionError = errorMessage);
        }
      }
    } finally {
      if (mounted) setState(() => _isPredicting = false);
    }
  }



  void _showUpsellDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('免費次數已用盡'),
        content: const Text('今日的 AI 熱點預測已用完。\n\n您可以選擇訂閱以無限使用，或觀看廣告獲取一小時的無限次使用時間。'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _watchAdForReward();
            },
            child: const Text('觀看廣告'),
          ),
          FilledButton(
            onPressed: () {
              final subProvider = context.read<SubscriptionProvider>();
              Navigator.of(context).pop();
              subProvider.purchaseSubscription();
            },
            child: const Text('訂閱 Pro'),
          ),
        ],
      ),
    );
  }

  void _watchAdForReward() {
    _adService.showRewardedAd(
      onReward: () {
        final subProvider = context.read<SubscriptionProvider>();
        subProvider.grantOneHourOfPredictions();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('恭喜！您已獲得一小時無限預測。有效時間以卡片顯示為準。'), backgroundColor: Colors.green),
        );
      },
      onAdFailed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('廣告載入失敗，請稍後再試。'), backgroundColor: Colors.red),
        );
      },
    );
  }

  void _showPermissionDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('需要定位權限'),
        content: Text(message),
        actions: [
          TextButton(child: const Text('取消'), onPressed: () => Navigator.of(context).pop()),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openAppSettings();
            },
            child: const Text('前往設定'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchMaps(RecommendedHotspot hotspot) async {
    final lat = hotspot.latitude;
    final lng = hotspot.longitude;
    final url = Platform.isIOS ? 'https://maps.apple.com/?q=$lat,$lng' : 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法開啟地圖應用程式。')));
    }
  }

  void stopAllIdleTimers() {
    _idleTimer?.cancel();
    _secondReminderTimer?.cancel();
  }

  void resetIdleTimerAfterTrip() {
    stopAllIdleTimers();
    if (!_isWorking) return;
    setState(() => _lastActivityTime = DateTime.now());
    _idleAlertLevel = 0;
    _idleTimer = Timer.periodic(const Duration(minutes: 1), (timer) => _checkIdleStatus());
  }

  void _checkIdleStatus() {
    if (_lastActivityTime == null || !_isWorking || _idleAlertLevel > 0) return;
    final idleDuration = DateTime.now().difference(_lastActivityTime!);
    final rateDifference = _targetHourlyRate - _hourlyRate;
    Duration triggerDuration;
    if (rateDifference > (_targetHourlyRate * 0.75)) {
      triggerDuration = const Duration(minutes: 10);
    } else if (rateDifference > (_targetHourlyRate * 0.5)) {
      triggerDuration = const Duration(minutes: 15);
    } else {
      return;
    }
    if (idleDuration >= triggerDuration) {
      setState(() => _idleAlertLevel = 1);
      _showIdleAlertDialog(triggerDuration);
      stopAllIdleTimers();
    }
  }

  void _startSecondReminderTimer() {
    _secondReminderTimer?.cancel();
    _secondReminderTimer = Timer(const Duration(minutes: 5), () {
      if (_idleAlertLevel == 1) {
        setState(() => _idleAlertLevel = 2);
        _showIdleAlertDialog(const Duration(minutes: 5), isSecondReminder: true);
      }
    });
  }

  void _showIdleAlertDialog(Duration idleDuration, {bool isSecondReminder = false}) {
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: Text(isSecondReminder ? '最後提醒' : 'AI 智能提醒'),
              content: Text(isSecondReminder ? '您已持續空車一段時間，最後一次建議您查看熱點，或許能帶來好運！' : '您似乎已空車超過 ${idleDuration.inMinutes} 分鐘，需要為您推薦附近的熱點嗎？'),
              actions: [
                TextButton(onPressed: () {
                  Navigator.of(context).pop();
                  if (!isSecondReminder) _startSecondReminderTimer();
                }, child: const Text('忽略')),
                FilledButton(onPressed: () {
                  Navigator.of(context).pop();
                  _triggerHotspotPrediction();
                  resetIdleTimerAfterTrip();
                }, child: const Text('前往查看')),
              ],
            ));
  }

  Future<void> suggestNearestHotspotAfterTrip() async {
    if (!mounted) return;
    final subProvider = context.read<SubscriptionProvider>();

    // Allow auto-suggestion for subscribed users OR users with an active ad reward
    if (subProvider.isSubscribed || subProvider.isAdRewardActive) {
       await _triggerHotspotPrediction(isAutoTrigger: true);
    }
  }


  void _showHotspotSuggestionDialog(RecommendedHotspot hotspot) {
    final distanceInKm = (hotspot.distanceInMeters / 1000).toStringAsFixed(1);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('載客建議'),
        content: Text('最近的熱點 \'${hotspot.name}\' 距離您約 $distanceInKm 公里，是否要前往？'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('忽略')),
          FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                _launchMaps(hotspot);
              },
              child: const Text('前往導航')),
        ],
      ),
    );
  }

  Future<void> fetchAndStoreLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('last_known_lat', position.latitude);
      await prefs.setDouble('last_known_lng', position.longitude);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('GPS座標已儲存'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('無法取得位置: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subProvider = context.watch<SubscriptionProvider>();
    _manageAdRewardTimer(subProvider);

    return Container(
      color: Theme.of(context).brightness == Brightness.dark ? Theme.of(context).scaffoldBackgroundColor : Colors.grey[200],
      child: RefreshIndicator(
        onRefresh: loadInitialData,
        child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16.0),
            child: Column(children: [_buildBusinessStatusCard(), const SizedBox(height: 16), _buildPredictionCard(subProvider)])),
      ),
    );
  }

  Widget _buildPredictionCard(SubscriptionProvider subProvider) {
    if (_isPredicting) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
        decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [CircularProgressIndicator(), SizedBox(width: 24), Text('AI 運算中...')]),
      );
    }
    if (_predictionError != null) {
      return Card(
          color: Colors.red.shade100,
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(children: [
                Text(_predictionError!, style: TextStyle(color: Colors.red.shade900)),
                const SizedBox(height: 16),
                ElevatedButton(onPressed: () => _triggerHotspotPrediction(), child: const Text('重試'))
              ])));
    }
    if (_recommendedHotspot != null) {
      if (_recommendedHotspot!.isTextualHint) {
        return _buildTextualHintCard(_recommendedHotspot!);
      }
      final distanceInKm = (_recommendedHotspot!.distanceInMeters / 1000).toStringAsFixed(1);
      final title = _recommendedHotspot!.isFallback ? _recommendedHotspot!.name : '發現 AI 推薦熱點！';
      return Card(
          color: Colors.green.shade100,
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(children: [
                Text(title, style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade900)),
                Text('距離您約 $distanceInKm 公里'),
                const SizedBox(height: 16),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  TextButton(onPressed: () => setState(() => _recommendedHotspot = null), child: const Text('取消')),
                  FilledButton(
                      onPressed: () {
                        _launchMaps(_recommendedHotspot!);
                        setState(() => _recommendedHotspot = null);
                      },
                      child: const Text('前往導航'))
                ])
              ])));
    }
    return _buildInitialAiCard(subProvider);
  }

  Widget _buildTextualHintCard(RecommendedHotspot hotspot) {
    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.secondaryContainer;
    final textColor = theme.colorScheme.onSecondaryContainer;

    return Card(
      color: cardColor,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '通用熱點建議',
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              hotspot.name,
              style: TextStyle(height: 1.5, color: textColor.withOpacity(0.8)),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _recommendedHotspot = null),
                child: Text('關閉', style: TextStyle(color: textColor)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInitialAiCard(SubscriptionProvider subProvider) {
    String statusText;
    if (subProvider.isAdRewardActive) {
      final remaining = subProvider.adRewardTimeRemaining;
      final minutes = remaining.inMinutes;
      final seconds = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      statusText = '廣告獎勵有效: $minutes:$seconds';
    } else {
      statusText = '今日剩餘: ${subProvider.credits} 次';
    }

    return GestureDetector(
      onTap: () => _triggerHotspotPrediction(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [const Color(0xFF8E44AD), const Color(0xFF6C3483).withOpacity(0.9)], begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: const Color(0xFF8E44AD).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.auto_awesome, color: Colors.white, size: 20), SizedBox(width: 8), Text('預測熱點', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]),
                  const SizedBox(height: 8),
                  Text('分析雲端數據，為您推薦當前最佳熱點。', style: TextStyle(color: Colors.white70, fontSize: 14)),
                  const SizedBox(height: 4),
                  Text(statusText, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w300)),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.95), borderRadius: BorderRadius.circular(30)),
              child: Row(children: const [Text('開始預測', style: TextStyle(color: Color(0xFF583790), fontWeight: FontWeight.bold, fontSize: 14)), SizedBox(width: 4), Icon(Icons.arrow_forward_ios, size: 12, color: Color(0xFF583790))]),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessStatusCard() {
    Duration displayDuration = _accumulatedWorkDuration;
    if (_isWorking && _lastStartTime != null) {
      displayDuration += DateTime.now().difference(_lastStartTime!);
    }
    final hours = displayDuration.inHours.toString().padLeft(2, '0');
    final minutes = (displayDuration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (displayDuration.inSeconds % 60).toString().padLeft(2, '0');
    final isWarmupPeriod = displayDuration.inSeconds <= 300;
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withAlpha(26),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      color: Colors.amber[300],
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('目前車隊', style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(_selectedFleet?.name ?? '未選擇', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)),
                  child: Text('$hours:$minutes:$seconds', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white, fontFamily: 'monospace')),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('今日實收', '\$${_todayRevenue.toStringAsFixed(0)}'),
                Container(width: 1, height: 40, color: Colors.black12),
                _buildStatColumn('預估時薪', isWarmupPeriod ? '計算中...' : '\$${_hourlyRate.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 24),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('今日目標', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    Text('${(_goalProgress * 100).toStringAsFixed(0)}%', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: _goalProgress.clamp(0.0, 1.0),
                    backgroundColor: Colors.white.withAlpha(128),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                    minHeight: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: _toggleWorkStatus,
                icon: Icon(_isWorking ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 28),
                label: Text(_isWorking ? '結束營業' : '開始營業', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isWorking ? Colors.red[400] : Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String title, String value) {
    return Column(
      children: [
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 13)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87)),
      ],
    );
  }
}
