import 'package:cloud_firestore/cloud_firestore.dart';

class UserProfile {
  final String uid;
  final String username;
  final String displayName;
  final int totalXp;
  final String unvan;
  final int streak;
  final String? photoUrl;
  final String? fcmToken;
  final DateTime createdAt;
  final List<String> friends;

  UserProfile({
    required this.uid,
    required this.username,
    required this.displayName,
    required this.totalXp,
    required this.unvan,
    required this.streak,
    this.photoUrl,
    this.fcmToken,
    required this.createdAt,
    this.friends = const [],
  });

  /// Firestore belgesinden model oluşturur
  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      username: data['username'] ?? 'misafir',
      displayName: data['displayName'] ?? data['username'] ?? 'Misafir',
      totalXp: (data['totalXp'] ?? 0) as int,
      unvan: data['unvan'] ?? 'Talip',
      streak: (data['streak'] ?? 0) as int,
      photoUrl: data['photoUrl'],
      fcmToken: data['fcmToken'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      friends: List<String>.from(data['friends'] ?? []),
    );
  }

  /// Firestore'a yazılacak Map'e dönüştürür
  Map<String, dynamic> toFirestore() {
    return {
      'username': username,
      'displayName': displayName,
      'totalXp': totalXp,
      'unvan': unvan,
      'streak': streak,
      'photoUrl': photoUrl,
      'fcmToken': fcmToken,
      'createdAt': Timestamp.fromDate(createdAt),
      'friends': friends,
    };
  }
}
