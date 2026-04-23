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
  final bool isOnline;
  final DateTime? lastActive;
  final DateTime? lastStoryAt;

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
    this.isOnline = false,
    this.lastActive,
    this.lastStoryAt,
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
      isOnline: data['isOnline'] ?? false,
      lastActive: (data['lastActive'] as Timestamp?)?.toDate(),
      lastStoryAt: (data['lastStoryAt'] as Timestamp?)?.toDate(),
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
      'isOnline': isOnline,
      'lastActive': lastActive != null ? Timestamp.fromDate(lastActive!) : FieldValue.serverTimestamp(),
      'lastStoryAt': lastStoryAt != null ? Timestamp.fromDate(lastStoryAt!) : null,
    };
  }
}
