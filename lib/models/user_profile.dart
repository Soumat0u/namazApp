import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

/// Haftanın pazartesi gününün "yyyy-MM-dd" anahtarı (haftalık sıralama/hedef için)
String haftaAnahtari(DateTime gun) =>
    DateFormat('yyyy-MM-dd').format(DateTime(gun.year, gun.month, gun.day - (gun.weekday - 1)));

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
  // Arkadaşlar arası sıralama ve ortak hedef için (her cihaz kendi verisini yazar)
  final String haftaKey;
  final int haftalikXp;
  final int haftalikNamaz;
  final String bugunTarih;
  final List<String> bugunKilinan;
  final List<String> gonderilenIstekler;
  final String? cinsiyet; // 'kadin' | 'erkek'
  final List<String> engellenenler;

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
    this.haftaKey = '',
    this.haftalikXp = 0,
    this.haftalikNamaz = 0,
    this.bugunTarih = '',
    this.bugunKilinan = const [],
    this.gonderilenIstekler = const [],
    this.cinsiyet,
    this.engellenenler = const [],
  });

  /// Veri başka bir haftaya aitse bu hafta 0 sayılır
  int buHaftaXp(String guncelHafta) => haftaKey == guncelHafta ? haftalikXp : 0;
  int buHaftaNamaz(String guncelHafta) => haftaKey == guncelHafta ? haftalikNamaz : 0;
  List<String> bugunKilinanlar(String bugun) => bugunTarih == bugun ? bugunKilinan : const [];

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
      haftaKey: data['haftaKey'] ?? '',
      haftalikXp: (data['haftalikXp'] ?? 0) as int,
      haftalikNamaz: (data['haftalikNamaz'] ?? 0) as int,
      bugunTarih: data['bugunTarih'] ?? '',
      bugunKilinan: List<String>.from(data['bugunKilinan'] ?? []),
      gonderilenIstekler: List<String>.from(data['gonderilenIstekler'] ?? []),
      cinsiyet: data['cinsiyet'],
      engellenenler: List<String>.from(data['engellenenler'] ?? []),
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
