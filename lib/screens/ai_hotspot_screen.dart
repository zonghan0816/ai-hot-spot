import 'dart:async'; // Import the async library for Timer
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:taxibook/models/recommended_hotspot.dart';
import 'package:taxibook/services/prediction_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class AiHotspotScreen extends StatefulWidget {
  const AiHotspotScreen({super.key});

  @override
  State<AiHotspotScreen> createState() => _AiHotspotScreenState();
}

class _AiHotspotScreenState extends State<AiHotspotScreen> {
  final PredictionService _predictionService = PredictionService();
  Future<List<RecommendedHotspot>>? _hotspotsFuture;
  bool _isListView = false;
  Timer? _idleTimer; // The idle timer

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  // When the screen is removed from the widget tree, cancel the timer to prevent memory leaks
  @override
  void dispose() {
    _cancelIdleTimer();
    super.dispose();
  }

  /// Starts a 15-second idle timer. If it completes, it pops the screen.
  void _startIdleTimer() {
    _cancelIdleTimer(); // Cancel any existing timer before starting a new one
    _idleTimer = Timer(const Duration(seconds: 15), () {
      if (mounted) {
        // Show a quick message that the screen timed out
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('閒置時間過長，畫面已自動關閉'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    });
  }

  /// Cancels the idle timer if it's active.
  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  Future<void> _initializeScreen() async {
    await _loadViewPreference();
    _fetchHotspots();
  }

  Future<void> _loadViewPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final useListView = prefs.getBool('ai_list_mode') ?? false;
    if (mounted) {
      setState(() {
        _isListView = useListView;
      });
    }
  }

  Future<void> _fetchHotspots() async {
    _cancelIdleTimer(); // Cancel timer when a refresh starts
    final future = _predictionService.getRecommendedHotspots();
    setState(() {
      _hotspotsFuture = future;
    });
    try {
      await future;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('刷新失敗: ${e.toString().replaceAll("Exception: ", "")}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _launchMap(double latitude, double longitude) async {
    _cancelIdleTimer(); // User interaction, cancel the timer
    final connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法開啟導航，請檢查您的網路連線。')));
      }
      return;
    }
    final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$latitude,$longitude');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('無法開啟地圖應用程式')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI 熱點推薦'),
        actions: [
          IconButton(
            icon: Icon(_isListView ? Icons.view_carousel_outlined : Icons.view_list_outlined),
            onPressed: () {
              _cancelIdleTimer(); // User interaction, cancel the timer
              setState(() => _isListView = !_isListView);
            },
            tooltip: '切換列表/單一視圖',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHotspots, // This already cancels the timer
            tooltip: '重新整理',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchHotspots,
        child: FutureBuilder<List<RecommendedHotspot>>(
          future: _hotspotsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && snapshot.data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError && snapshot.data == null) {
              return _buildScrollableInfoView(child: Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text('無法完成推薦：\n${snapshot.error.toString().replaceAll("Exception: ", "")}', textAlign: TextAlign.center))));
            }

            final hotspots = snapshot.data;
            if (hotspots == null || hotspots.isEmpty) {
               _cancelIdleTimer(); // No data, no timer needed
              return _buildScrollableInfoView(child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.map_outlined, size: 60, color: Colors.grey), SizedBox(height: 16), Text('附近區域暫無推薦熱點或建議', style: TextStyle(color: Colors.grey, fontSize: 16))])));
            }

            // NEW: Check if the first (and possibly only) result is a textual hint.
            if (hotspots.first.isTextualHint) {
               _cancelIdleTimer(); // Text hints don't need a timeout
              return _buildScrollableInfoView(child: _buildTextualHintCard(hotspots.first));
            }
            
            // Timer logic: Start only for single view, cancel for list view
            if (_isListView) {
              _cancelIdleTimer();
            } else {
              _startIdleTimer();
            }

            if (_isListView) {
              return _buildListView(hotspots);
            }
            
            return _buildScrollableInfoView(child: _buildSingleView(hotspots.first));
          },
        ),
      ),
    );
  }

  Widget _buildScrollableInfoView({required Widget child}) {
    return LayoutBuilder(builder: (context, constraints) => SingleChildScrollView(physics: const AlwaysScrollableScrollPhysics(), child: ConstrainedBox(constraints: BoxConstraints(minHeight: constraints.maxHeight), child: child)));
  }

  Widget _buildTextualHintCard(RecommendedHotspot hotspot) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Card(
          color: Colors.blue.shade50,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  children: [
                    Icon(Icons.lightbulb_outline, color: Colors.blue, size: 24),
                    SizedBox(width: 12),
                    Text('通用熱點建議', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 18)),
                  ],
                ),
                const Divider(height: 24),
                Text(hotspot.name, style: const TextStyle(height: 1.6, fontSize: 15)), // The hint text is in the name field
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSingleView(RecommendedHotspot bestHotspot) {
    final iconColor = bestHotspot.isFallback ? Colors.blueAccent : Colors.purple;
    final icon = bestHotspot.isFallback ? Icons.public : Icons.local_fire_department;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(bestHotspot.isFallback ? "AI 引擎無可用資料，為您啟用通用備案" : "AI 引擎推薦最佳熱點", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => _launchMap(bestHotspot.latitude, bestHotspot.longitude),
              child: Card(
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      CircleAvatar(radius: 30, backgroundColor: iconColor.withOpacity(0.1), child: Icon(icon, color: iconColor, size: 30)),
                      const SizedBox(height: 16),
                      Text(bestHotspot.name, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                      const SizedBox(height: 8),
                      Text('約 ${bestHotspot.distanceInMeters.round()} 公尺・熱度指數: ${bestHotspot.hotnessScore ?? 'N/A'}', style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.navigation_outlined), 
                        label: const Text('開始導航'), 
                        onPressed: () => _launchMap(bestHotspot.latitude, bestHotspot.longitude), 
                        style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 16), textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)))
                      )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildListView(List<RecommendedHotspot> hotspots) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ListView.separated(
      padding: const EdgeInsets.all(16.0),
      itemCount: hotspots.length,
      itemBuilder: (context, index) {
        final hotspot = hotspots[index];
        final iconColor = hotspot.isFallback ? Colors.blueAccent : Colors.purple;
        final icon = hotspot.isFallback ? Icons.public : Icons.local_fire_department;
        return ListTile(
          leading: CircleAvatar(backgroundColor: iconColor.withOpacity(0.1), child: Icon(icon, color: iconColor)),
          title: Text(hotspot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('約 ${hotspot.distanceInMeters.round()} 公尺・熱度: ${hotspot.hotnessScore ?? 'N/A'}/10'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _launchMap(hotspot.latitude, hotspot.longitude),
          tileColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        );
      },
      separatorBuilder: (context, index) => const SizedBox(height: 12),
    );
  }
}
