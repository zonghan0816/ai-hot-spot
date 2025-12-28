import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:taxibook/models/hotspot.dart';
import 'package:url_launcher/url_launcher.dart';

/// 熱點共享頁面
///
/// 使用 StreamBuilder 即時顯示來自 Firestore 的熱點列表。
/// 使用者可以點擊列表項目，以呼叫原生導航至該熱點。
class HotspotScreen extends StatefulWidget {
  const HotspotScreen({super.key});

  @override
  State<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends State<HotspotScreen> {
  /// 啟動原生導航至指定熱點。
  ///
  /// 會根據不同平台，嘗試開啟對應的地圖 App URL。
  Future<void> _launchMaps(Hotspot hotspot) async {
    final lat = hotspot.latitude;
    final lng = hotspot.longitude;
    final String googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final String appleMapsUrl = 'https://maps.apple.com/?q=$lat,$lng';

    Uri? uri;
    if (Platform.isIOS) {
      uri = Uri.parse(appleMapsUrl);
    } else {
      uri = Uri.parse(googleMapsUrl);
    }

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('無法開啟地圖應用程式。')),
        );
      }
    }
  }

  /// 格式化 Timestamp 為易讀的相對時間字串。
  String _formatTimestamp(Timestamp timestamp) {
    final DateTime date = timestamp.toDate();
    final Duration diff = DateTime.now().difference(date);

    if (diff.inDays > 1) {
      return DateFormat('yyyy/MM/dd HH:mm').format(date);
    } else if (diff.inDays == 1 || (diff.inHours > date.hour)) {
       return '昨天 ${DateFormat('HH:mm').format(date)}';
    } else if (diff.inHours >= 1) {
      return '${diff.inHours} 小時前';
    } else if (diff.inMinutes >= 1) {
      return '${diff.inMinutes} 分鐘前';
    } else {
      return '剛剛';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('共享熱點'),
        centerTitle: true,
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // 訂閱 hotspots 集合，並按時間倒序排列
        stream: FirebaseFirestore.instance
            .collection('hotspots')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          // 狀態 1: 正在載入資料
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // 狀態 2: 發生錯誤
          if (snapshot.hasError) {
            // ignore: avoid_print
            print('Hotspot Screen Error: ${snapshot.error}');
            return const Center(child: Text('載入熱點時發生錯誤。'));
          }

          // 狀態 3: 沒有資料
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.map_outlined, size: 80, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  const Text(
                    '目前還沒有共享熱點',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                   const SizedBox(height: 8),
                  Text(
                    '快去「首頁」分享您的第一個熱點吧！',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            );
          }

          // 狀態 4: 成功載入資料
          final hotspots = snapshot.data!.docs
              .map((doc) => Hotspot.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: hotspots.length,
            itemBuilder: (context, index) {
              final hotspot = hotspots[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  leading: Icon(Icons.pin_drop_outlined, color: Theme.of(context).colorScheme.primary),
                  title: Text(hotspot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('分享於: ${_formatTimestamp(hotspot.createdAt)}'),
                  trailing: const Icon(Icons.navigation_outlined, color: Colors.blueAccent),
                  onTap: () => _launchMaps(hotspot),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
