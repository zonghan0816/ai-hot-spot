import 'package:cloud_firestore/cloud_firestore.dart';

/// 代表一個共享熱點的資料模型。
class Hotspot {
  /// Firestore 文件 ID。
  final String id;

  /// 使用者自訂的熱點名稱。
  final String name;

  /// GPS 緯度。
  final double latitude;

  /// GPS 經度。
  final double longitude;

  /// 分享此熱點的使用者 ID。
  final String creatorId;

  /// 熱點建立時間。
  final Timestamp createdAt;

  const Hotspot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.creatorId,
    required this.createdAt,
  });

  /// 從 Firestore 文件快照 (DocumentSnapshot) 建立一個 Hotspot 物件。
  factory Hotspot.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      throw StateError('Missing data for Hotspot doc: ${doc.id}');
    }

    return Hotspot(
      id: doc.id,
      name: data['name'] as String? ?? '',
      latitude: (data['latitude'] as num? ?? 0.0).toDouble(),
      longitude: (data['longitude'] as num? ?? 0.0).toDouble(),
      creatorId: data['creatorId'] as String? ?? '',
      createdAt: data['createdAt'] as Timestamp? ?? Timestamp.now(),
    );
  }

  /// 將 Hotspot 物件轉換為可寫入 Firestore 的 Map 格式。
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'creatorId': creatorId,
      'createdAt': createdAt,
    };
  }
}
