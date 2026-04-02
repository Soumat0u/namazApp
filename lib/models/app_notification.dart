import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  final String id;
  final String type; // Örn: 'friend_request'
  final String fromUid;
  final String fromUsername;
  final String fromDisplayName; // İsteği atanın görünen adı
  final String status; // 'pending', 'accepted', 'rejected'
  final DateTime timestamp;

  AppNotification({
    required this.id,
    required this.type,
    required this.fromUid,
    required this.fromUsername,
    required this.fromDisplayName,
    required this.status,
    required this.timestamp,
  });

  factory AppNotification.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AppNotification(
      id: doc.id,
      type: data['type'] ?? 'unknown',
      fromUid: data['fromUid'] ?? '',
      fromUsername: data['fromUsername'] ?? '',
      fromDisplayName: data['fromDisplayName'] ?? '',
      status: data['status'] ?? 'pending',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'fromUid': fromUid,
      'fromUsername': fromUsername,
      'fromDisplayName': fromDisplayName,
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };
  }
}
