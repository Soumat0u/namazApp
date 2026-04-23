import 'package:cloud_firestore/cloud_firestore.dart';

class UserStory {
  final String uid;
  final String username;
  final String displayName;
  final String? photoUrl;
  final String imageUrl; // Base64 string
  final DateTime createdAt;

  UserStory({
    required this.uid,
    required this.username,
    required this.displayName,
    this.photoUrl,
    required this.imageUrl,
    required this.createdAt,
  });

  factory UserStory.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserStory(
      uid: data['uid'] ?? '',
      username: data['username'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'],
      imageUrl: data['imageUrl'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'username': username,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
