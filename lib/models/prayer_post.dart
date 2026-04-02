import 'package:cloud_firestore/cloud_firestore.dart';

class PrayerPost {
  final String id;
  final String text;
  final String senderUid;
  final String senderName;
  final int aminCount;
  final List<String> aminBy;
  final DateTime timestamp;
  final bool isApproved;

  PrayerPost({
    required this.id,
    required this.text,
    required this.senderUid,
    required this.senderName,
    required this.aminCount,
    required this.aminBy,
    required this.timestamp,
    this.isApproved = true,
  });

  /// Firestore belgesinden model oluşturur
  factory PrayerPost.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return PrayerPost(
      id: doc.id,
      text: data['text'] ?? '',
      senderUid: data['senderUid'] ?? '',
      senderName: data['senderName'] ?? 'Anonim',
      aminCount: (data['aminCount'] ?? 0) as int,
      aminBy: List<String>.from(data['aminBy'] ?? []),
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isApproved: data['isApproved'] ?? true,
    );
  }

  /// Firestore'a yazılacak Map'e dönüştürür
  Map<String, dynamic> toFirestore() {
    return {
      'text': text,
      'senderUid': senderUid,
      'senderName': senderName,
      'aminCount': aminCount,
      'aminBy': aminBy,
      'timestamp': Timestamp.fromDate(timestamp),
      'isApproved': isApproved,
    };
  }
}
