import 'package:external_app_launcher/external_app_launcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

@pragma("vm:entry-point")
void overlayMain() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: OverlayWidget(),
  ));
}

enum OverlayMode { collapsed, menu }

class OverlayWidget extends StatefulWidget {
  const OverlayWidget({super.key});

  @override
  State<OverlayWidget> createState() => _OverlayWidgetState();
}

class _OverlayWidgetState extends State<OverlayWidget> {
  OverlayMode _mode = OverlayMode.collapsed;
  String _statusMessage = "";
  bool _hasRecorded = false;

  Future<void> _updateOverlaySize(OverlayMode mode) async {
    // Keep it small and simple
    int width = 130;
    int height = 130;

    switch (mode) {
      case OverlayMode.collapsed:
        width = 130;
        height = 130;
        break;
      case OverlayMode.menu:
        width = 160; 
        height = 320; // Just enough for vertical buttons
        break;
    }

    await FlutterOverlayWindow.resizeOverlay(width, height, mode == OverlayMode.collapsed);
    
    if(mounted) {
      setState(() {
        _mode = mode;
      });
    }
  }

  Future<void> _recordPickupLocation() async {
    setState(() => _statusMessage = "定位中...");
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5)
      );
      final coords = '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}';
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('temp_pickup_location', coords);
      
      setState(() {
        _hasRecorded = true;
        _statusMessage = "✅ 已記錄";
      });
      
      await Future.delayed(const Duration(seconds: 1));
      _updateOverlaySize(OverlayMode.collapsed);
      if(mounted) setState(() => _statusMessage = ""); 
      
    } catch (e) {
      setState(() => _statusMessage = "❌ 失敗");
    }
  }

  Future<void> _openMainApp() async {
    // 1. Mark flag so main app knows to open add screen
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('open_add_trip_requested', true);

    // 2. Launch the app using the original method
    try {
      await ExternalAppLauncher.launchApp(androidPackageName: "com.Han.taxibook");
      
      // Close menu
      _updateOverlaySize(OverlayMode.collapsed);
      // Optional: Reset recording status if you want a fresh start
      setState(() {
         _hasRecorded = false; 
         _statusMessage = "";
      });
      
    } catch (e) {
      setState(() => _statusMessage = "開啟失敗");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Center(
        child: _mode == OverlayMode.collapsed ? _buildCollapsed() : _buildMenu(),
      ),
    );
  }

  Widget _buildCollapsed() {
    return GestureDetector(
      onTap: () => _updateOverlaySize(OverlayMode.menu),
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: _hasRecorded ? Colors.green[700] : Colors.amber[700],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(color: Colors.black.withAlpha(102), blurRadius: 8, offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.white, width: 2),
        ),
        child: Icon(
          _hasRecorded ? Icons.check : Icons.local_taxi, 
          color: _hasRecorded ? Colors.white : Colors.black87, 
          size: 32
        ),
      ),
    );
  }

  Widget _buildMenu() {
    return Container(
      width: 140, 
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E).withAlpha(242),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _hasRecorded ? Colors.green : Colors.amber, width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(128), blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_statusMessage.isNotEmpty)
             Padding(
               padding: const EdgeInsets.only(bottom: 8.0),
               child: Text(_statusMessage, style: const TextStyle(color: Colors.greenAccent, fontSize: 12), textAlign: TextAlign.center),
             ),
             
          _buildMenuBtn(
            icon: Icons.place, 
            label: "上記錄", 
            color: _hasRecorded ? Colors.grey : Colors.blueAccent, 
            onTap: _recordPickupLocation
          ),
          const SizedBox(height: 12),
          _buildMenuBtn(
            icon: Icons.open_in_new, 
            label: "結帳", 
            color: Colors.greenAccent, 
            onTap: _openMainApp
          ),
          const SizedBox(height: 12),
          IconButton(
            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.grey, size: 30), 
            onPressed: () => _updateOverlaySize(OverlayMode.collapsed),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withAlpha(38),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(153), width: 1.5),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
