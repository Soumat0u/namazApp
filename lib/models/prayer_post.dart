import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/utils/extensions.dart';

class PrayerPost {
  final String id;
  final String text;
  final String senderUid;
  final String senderName;
  final String senderUsername;
  final int aminCount;
  final List<String> aminBy;
  final DateTime timestamp;
  final bool isApproved;

  PrayerPost({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.senderName,
    required this.senderUsername,
    required this.aminCount,
    required this.aminBy,
    required this.timestamp,
    this.isApproved = true,
  });

  /// Zaman farkını okunabilir formata çevirir (12dk, 3sa, 5g)
  String get zamanFarki => timestamp.zamanFarki;

  /// Firestore belgesinden model oluşturur
  factory PrayerPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    
    // Timestamp'i güvenli bir şekilde alalım
    DateTime ts;
    final dynamic rawTimestamp = data['timestamp'];
    if (rawTimestamp is Timestamp) {
      ts = rawTimestamp.toDate();
    } else if (rawTimestamp is String) {
      ts = DateTime.tryParse(rawTimestamp) ?? DateTime.now();
    } else if (rawTimestamp is int) {
      ts = DateTime.fromMillisecondsSinceEpoch(rawTimestamp);
    } else {
      ts = DateTime.now();
    }

    return PrayerPost(
      id: doc.id,
      text: data['text'] ?? '',
      senderUid: data['senderUid'] ?? '',
      senderName: data['senderName'] ?? 'Anonim',
      senderUsername: data['senderUsername'] ?? '',
      aminCount: (data['aminCount'] ?? 0) as int,
      aminBy: List<String>.from(data['aminBy'] ?? []),
      timestamp: ts,
      isApproved: data['isApproved'] ?? true,
    );
  }

  /// Firestore'a yazılacak Map'e dönüştürür
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'senderUid': senderUid,
      'senderName': senderName,
      'senderUsername': senderUsername,
      'aminCount': aminCount,
      'aminBy': aminBy,
      'timestamp': Timestamp.fromDate(timestamp),
      'isApproved': isApproved,
    };
  }
}
