import 'dart:io';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

import '../models/user_profile.dart';
import '../models/prayer_post.dart';
import '../models/app_notification.dart';
import '../models/story.dart';
import '../services/seviye_servisi.dart';

/// Tüm Firebase operasyonlarını kapsülleyen abstraction layer.
/// NamazProvider bu sınıf aracılığıyla bulut ile iletişim kurar.
class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  // ════════════════════════════════════════
  // 🔐 AUTH İŞLEMLERİ
  // ════════════════════════════════════════

  /// Mevcut kullanıcı (null ise giriş yapılmamış)
  User? get currentUser => _auth.currentUser;

  /// Auth durumu değişikliklerini dinler
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Email/Şifre ile yeni hesap oluşturur
  Future<({User? user, String? error})> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('🔐 Email ile kayıt başarılı: ${credential.user?.uid}');
      return (user: credential.user, error: null);
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      switch (e.code) {
        case 'weak-password':
          errorMsg = 'Şifre çok zayıf. En az 6 karakter olmalı.';
          break;
        case 'email-already-in-use':
          errorMsg = 'Bu e-posta adresi zaten kullanımda.';
          break;
        case 'invalid-email':
          errorMsg = 'Geçersiz e-posta adresi.';
          break;
        default:
          errorMsg = 'Kayıt hatası: ${e.message}';
      }
      debugPrint('🔐 Email kayıt hatası: $e');
      return (user: null, error: errorMsg);
    } catch (e) {
      debugPrint('🔐 Email kayıt hatası: $e');
      return (user: null, error: 'Beklenmeyen bir hata oluştu.');
    }
  }

  /// Email/Şifre ile giriş yapar
  Future<({User? user, String? error})> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      debugPrint('🔐 Email ile giriş başarılı: ${credential.user?.uid}');
      return (user: credential.user, error: null);
    } on FirebaseAuthException catch (e) {
      String errorMsg;
      switch (e.code) {
        case 'user-not-found':
          errorMsg = 'Bu e-posta ile kayıtlı hesap bulunamadı.';
          break;
        case 'wrong-password':
        case 'invalid-credential':
          errorMsg = 'E-posta veya şifre hatalı.';
          break;
        case 'user-disabled':
          errorMsg = 'Bu hesap devre dışı bırakılmış.';
          break;
        case 'invalid-email':
          errorMsg = 'Geçersiz e-posta adresi.';
          break;
        default:
          errorMsg = 'Giriş hatası: ${e.message}';
      }
      debugPrint('🔐 Email giriş hatası: $e');
      return (user: null, error: errorMsg);
    } catch (e) {
      debugPrint('🔐 Email giriş hatası: $e');
      return (user: null, error: 'Beklenmeyen bir hata oluştu.');
    }
  }

  /// Google ile giriş yapar (alternatif giriş yöntemi)
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        debugPrint('🔐 Google giriş iptal edildi');
        return null; // Kullanıcı iptal etti
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      debugPrint('🔐 Google ile giriş yapıldı: ${userCredential.user?.uid}');
      return userCredential.user;
    } catch (e) {
      debugPrint('🔐 Google giriş hatası: $e');
      return null;
    }
  }

  /// Hesaptan çıkış yapar
  Future<void> signOut() async {
    try {
      await Future.wait([
        _auth.signOut(),
        GoogleSignIn().signOut(),
      ]);
      debugPrint('🔐 Başarıyla çıkış yapıldı.');
    } catch (e) {
      debugPrint('🔐 Çıkış yapma hatası: $e');
    }
  }

  /// Google kullanıcısının adını döner (profil adı önerisi için)
  String? getGoogleDisplayName() {
    final user = _auth.currentUser;
    return user?.displayName;
  }

  /// Google kullanıcısının profil fotoğrafı URL'sini döner
  String? getGooglePhotoUrl() {
    final user = _auth.currentUser;
    return user?.photoURL;
  }

  /// Kullanıcının profil kaydının Firestore'da olup olmadığını kontrol eder
  Future<bool> hasUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  // ════════════════════════════════════════
  // 👤 KULLANICI PROFİLİ İŞLEMLERİ
  // ════════════════════════════════════════

  /// Kullanıcı adının benzersiz olup olmadığını kontrol eder
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final doc = await _firestore.collection('usernames').doc(username).get();
      return !doc.exists;
    } catch (_) {
      return false; // Hata durumunda güvenlik için dolu farz et
    }
  }

  /// Verilen isme göre boşta olan benzersiz bir username üretir (Google için)
  Future<String> generateUniqueUsername(String baseName) async {
    // Küçük harfe çevir, İngilizce benzeri karakterler bırak 
    // Basitlik için tüm Türkçe/Özel karakterler dahil küçük alfa-nümerik harici sil
    String base = baseName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
    if (base.isEmpty) base = 'kullanici';

    if (await isUsernameAvailable(base)) return base;

    final random = Random();
    while (true) {
      String newName = '${base}_${random.nextInt(9999)}';
      if (await isUsernameAvailable(newName)) return newName;
    }
  }

  /// Yeni kullanıcı profili oluşturur (ilk girişte kullanıcı adı seçtikten sonra)
  Future<void> createUserProfile({
    required String uid,
    required String username,
    required String displayName,
    int initialXp = 0,
    int initialStreak = 0,
  }) async {
    try {
      final token = await _getMessagingToken();
      final profile = UserProfile(
        uid: uid,
        username: username,
        displayName: displayName,
        totalXp: initialXp,
        unvan: SeviyeServisi.unvanGetir(initialXp),
        streak: initialStreak,
        fcmToken: token,
        createdAt: DateTime.now(),
      );
      
      final batch = _firestore.batch();
      
      // 1. users koleksiyonuna ekle
      final profileRef = _firestore.collection('users').doc(uid);
      batch.set(profileRef, profile.toFirestore());

      // 2. usernames koleksiyonuna eklearak rezerve et
      final usernameRef = _firestore.collection('usernames').doc(username);
      batch.set(usernameRef, {
        'uid': uid, 
        'createdAt': FieldValue.serverTimestamp()
      });

      await batch.commit();

      debugPrint('👤 Profil oluşturuldu: $username (XP: $initialXp)');
    } catch (e) {
      debugPrint('👤 Profil oluşturma hatası: $e');
    }
  }

  /// Kullanıcının XP, streak ve unvan bilgilerini günceller (fire-and-forget)
  Future<void> updateUserStats({
    required String uid,
    required int totalXp,
    required int streak,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'totalXp': totalXp,
        'unvan': SeviyeServisi.unvanGetir(totalXp),
        'streak': streak,
      });
    } catch (e) {
      debugPrint('📊 Stats güncelleme hatası: $e');
    }
  }

  /// Kullanıcı adını günceller
  Future<void> updateUsername(String uid, String newUsername) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'username': newUsername,
      });
    } catch (e) {
      debugPrint('👤 Kullanıcı adı güncelleme hatası: $e');
    }
  }

  /// Kullanıcının çevrimiçi durumunu günceller
  Future<void> setUserStatus(String uid, bool isOnline) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': isOnline,
        'lastActive': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('👤 Durum güncelleme hatası: $e');
    }
  }

  /// Tek bir kullanıcı profilini dinler (stream)
  Stream<UserProfile?> getUserProfile(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? UserProfile.fromFirestore(doc) : null);
  }

  /// Tek bir kullanıcı profilini bir kez getirir (Future)
  Future<UserProfile?> getUserProfileFuture(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists ? UserProfile.fromFirestore(doc) : null;
    } catch (e) {
      debugPrint('👤 Profil getirme hatası: $e');
      return null;
    }
  }

  // ════════════════════════════════════════
  // 🤝 ARKADAŞLIK VE BİLDİRİMLER
  // ════════════════════════════════════════

  Stream<List<AppNotification>> getNotifications(String uid) {
    return _firestore
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => AppNotification.fromFirestore(doc)).toList());
  }

  Future<String?> sendFriendRequest({
    required String targetUsername,
    required String senderUid,
    required String senderUsername,
    required String senderDisplayName,
  }) async {
    try {
      final cleanUsername = targetUsername.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      if (cleanUsername == senderUsername) return 'Kendinize istek gönderemezsiniz.';
      
      final snap = await _firestore.collection('usernames').doc(cleanUsername).get();
      if (!snap.exists) return 'Bu kullanıcı adı sistemde bulunamadı.';
      
      final targetUid = snap.data()?['uid'] as String?;
      if (targetUid == null) return 'Kullanıcı hesabı hatalı.';
      
      final targetProfile = await _firestore.collection('users').doc(targetUid).get();
      final targetFriends = List<String>.from(targetProfile.data()?['friends'] ?? []);
      if (targetFriends.contains(senderUid)) return 'Bu kardeşimizle zaten arkadaşsınız.';

      final notificationRef = _firestore.collection('users').doc(targetUid).collection('notifications').doc(senderUid); 
      
      await notificationRef.set({
        'type': 'friend_request',
        'fromUid': senderUid,
        'fromUsername': senderUsername,
        'fromDisplayName': senderDisplayName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });

      return null;
    } catch (e) {
      debugPrint('Arkadaş ekleme hatası: $e');
      return 'Bir hata oluştu.';
    }
  }

  Future<void> respondToFriendRequest({
    required String currentUid,
    required String targetUid,
    required bool accept,
  }) async {
    try {
      final batch = _firestore.batch();
      final notifRef = _firestore.collection('users').doc(currentUid).collection('notifications').doc(targetUid);
      
      if (accept) {
        batch.update(notifRef, {'status': 'accepted'});
        
        final currentUserRef = _firestore.collection('users').doc(currentUid);
        batch.update(currentUserRef, {
          'friends': FieldValue.arrayUnion([targetUid])
        });
        
        final targetUserRef = _firestore.collection('users').doc(targetUid);
        batch.update(targetUserRef, {
          'friends': FieldValue.arrayUnion([currentUid])
        });
      } else {
        batch.update(notifRef, {'status': 'rejected'});
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('İstek cevaplama hatası: $e');
    }
  }

  /// Arkadaşlıktan çıkarır
  Future<void> removeFriend({
    required String currentUid,
    required String targetUid,
  }) async {
    try {
      final batch = _firestore.batch();
      
      final currentUserRef = _firestore.collection('users').doc(currentUid);
      batch.update(currentUserRef, {
        'friends': FieldValue.arrayRemove([targetUid])
      });
      
      final targetUserRef = _firestore.collection('users').doc(targetUid);
      batch.update(targetUserRef, {
        'friends': FieldValue.arrayRemove([currentUid])
      });
      
      // Arkadaşlık isteği bildirimini de temizleyelim (opsiyonel ama temiz olur)
      final notifRef1 = _firestore.collection('users').doc(currentUid).collection('notifications').doc(targetUid);
      batch.delete(notifRef1);
      final notifRef2 = _firestore.collection('users').doc(targetUid).collection('notifications').doc(currentUid);
      batch.delete(notifRef2);

      await batch.commit();
      debugPrint('🤝 Arkadaşlıktan çıkarıldı: $targetUid');
    } catch (e) {
      debugPrint('🤝 Arkadaşlıktan çıkarma hatası: $e');
    }
  }

  Future<List<UserProfile>> getFriendsProfiles(List<String> friendUids) async {
    if (friendUids.isEmpty) return [];
    try {
      List<UserProfile> friends = [];
      for (String uid in friendUids) {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) friends.add(UserProfile.fromFirestore(doc));
      }
      return friends;
    } catch (e) {
      debugPrint('Arkadaşları getirme hatası: $e');
      return [];
    }
  }

  /// Arkadaşların profil bilgilerini anlık (stream) olarak dinler
  Stream<List<UserProfile>> getFriendsProfilesStream(List<String> friendUids) {
    if (friendUids.isEmpty) return Stream.value([]);
    
    // Firestore 'whereIn' sınırı nedeniyle max 30 arkadaş (güncel Firestore limiti 30)
    final targetUids = friendUids.take(30).toList();

    return _firestore
        .collection('users')
        .where(FieldPath.documentId, whereIn: targetUids)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList());
  }

  /// Arkadaş Önerileri: Kendisi ve halihazırda arkadaşı olmayan popüler kullanıcılar
  Future<List<UserProfile>> getSuggestedFriends(String currentUid, List<String> currentFriends) async {
    try {
      final snap = await _firestore
          .collection('users')
          .orderBy('totalXp', descending: true) // En aktif kişileri öne çıkar
          .limit(20)
          .get();
          
      final users = snap.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
      
      // Filtreleme: Kendisini ve arkadaşlarını çıkar
      var suggestions = users.where((u) {
        if (u.uid == currentUid) return false;
        if (currentFriends.contains(u.uid)) return false;
        return true;
      }).toList();
      
      // Çeşitlilik veya karma isterseniz users.shuffle() burada yapılabilir
      return suggestions.take(10).toList();
    } catch (e) {
      debugPrint('Önerilen arkadaş getirme hatası: $e');
      return [];
    }
  }

  /// Liderlik tablosu: XP'ye göre azalan sırada kullanıcıları getirir
  Stream<List<UserProfile>> getLeaderboard({int limit = 50}) {
    return _firestore
        .collection('users')
        .orderBy('totalXp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => UserProfile.fromFirestore(doc))
          .toList();
    });
  }

  // ════════════════════════════════════════
  // 🤲 DUA DUVARI İŞLEMLERİ
  // ════════════════════════════════════════

  /// Yeni dua paylaşır
  Future<void> addPrayer({
    required String text,
    required String senderUid,
    required String senderName,
    required String senderUsername,
    bool isApproved = true,
  }) async {
    try {
      final prayer = PrayerPost(
        id: '', // Firestore otomatik ID oluşturacak
        text: text,
        senderUid: senderUid,
        senderName: senderName,
        senderUsername: senderUsername,
        aminCount: 0,
        aminBy: [],
        timestamp: DateTime.now(),
        isApproved: isApproved,
      );
      await _firestore.collection('prayers').add(prayer.toFirestore());
      debugPrint('🤲 Dua paylaşıldı: ${text.substring(0, text.length.clamp(0, 30))}...');
    } catch (e) {
      debugPrint('🤲 Dua paylaşma hatası: $e');
    }
  }

  /// Dua duvarını dinler (sadece onaylanan dualar, zamana göre sıralı)
  Stream<List<PrayerPost>> getPrayers({int limit = 30}) {
    return _firestore
        .collection('prayers')
        .where('isApproved', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PrayerPost.fromFirestore(doc))
          .toList();
    });
  }

  /// Sadece arkadaşların yayınladığı dualar (Gönül Kardeşliği)
  Stream<List<PrayerPost>> getFriendsPrayers(List<String> friendUids, {int limit = 30}) {
    if (friendUids.isEmpty) {
      return Stream.value([]);
    }
    
    // Firestore 'whereIn' sorgusu maksimim 10 eleman destekler
    final targetUids = friendUids.take(10).toList();

    return _firestore
        .collection('prayers')
        .where('isApproved', isEqualTo: true)
        .where('senderUid', whereIn: targetUids)
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => PrayerPost.fromFirestore(doc))
          .toList();
    });
  }

  /// Trendler / Keşfet: Son 24 saatte en çok Amîn alan dualar (Global)
  Stream<List<PrayerPost>> getDiscoverPrayers({int limit = 30}) {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return _firestore
        .collection('prayers')
        .where('isApproved', isEqualTo: true)
        .where('timestamp', isGreaterThan: yesterday)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      var list = snapshot.docs
          .map((doc) => PrayerPost.fromFirestore(doc))
          .toList();
          
      // Dart (Istemci) uzerinde amîn sayısına göre sırala ki Firestore'da 
      // timestamp + aminCount composite (bileşik) dizin yaratma çilesinden veya hatasından kaçınalım.
      list.sort((a, b) => b.aminCount.compareTo(a.aminCount));
      return list.take(limit).toList();
    });
  }

  /// Bir duaya "Amîn" der veya geri çeker (Like butonu gibi çalışır).
  Future<bool?> toggleAmin({
    required String prayerId,
    required String userUid,
  }) async {
    if (userUid.isEmpty) return null;
    try {
      final docRef = _firestore.collection('prayers').doc(prayerId);

      return await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return null;

        final data = snapshot.data() as Map<String, dynamic>;
        final aminBy = List<String>.from(data['aminBy'] ?? []);
        
        bool isAdded = false;

        // Amîn demişse kaldır, dememişse ekle
        if (aminBy.contains(userUid)) {
          aminBy.remove(userUid);
          isAdded = false;
        } else {
          aminBy.add(userUid);
          isAdded = true;
        }

        transaction.update(docRef, {
          'aminCount': aminBy.length,
          'aminBy': aminBy,
        });

        return isAdded;
      });
    } catch (e) {
      debugPrint('🤲 Amîn toggle hatası: $e');
      return null;
    }
  }

  // ════════════════════════════════════════
  // 🔔 BİLDİRİM (FCM) İŞLEMLERİ
  // ════════════════════════════════════════

  /// FCM token'ını alır
  Future<String?> _getMessagingToken() async {
    try {
      final token = await _messaging.getToken();
      return token;
    } catch (e) {
      debugPrint('🔔 FCM token hatası: $e');
      return null;
    }
  }

  /// FCM izinlerini ister ve token'ı Firestore'a kaydeder
  /// Mevcut bildirim izinlerini kontrol eder ve yetki varsa token'ı günceller (Sessiz işlem)
  Future<void> initMessaging(String uid) async {
    try {
      final settings = await _messaging.getNotificationSettings();

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _updateFcmToken(uid);
      }
      debugPrint('🔔 FCM Kontrol: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('🔔 FCM init hatası: $e');
    }
  }

  /// Kullanıcıdan bildirim izni ister ve yetki verilirse token'ı kaydeder
  Future<void> requestMessagingPermission(String uid) async {
    try {
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        await _updateFcmToken(uid);
      }
      debugPrint('🔔 FCM İzin Talebi: ${settings.authorizationStatus}');
    } catch (e) {
      debugPrint('🔔 FCM izin hatası: $e');
    }
  }

  /// Token'ı alır ve Firestore'a kaydeder
  Future<void> _updateFcmToken(String uid) async {
    final token = await _getMessagingToken();
    if (token != null) {
      await _firestore.collection('users').doc(uid).update({
        'fcmToken': token,
      });
    }

    // Token yenilenirse güncelle
    _messaging.onTokenRefresh.listen((newToken) {
      _firestore.collection('users').doc(uid).update({
        'fcmToken': newToken,
      });
    });
  }

  // ════════════════════════════════════════
  // 📸 HİKAYE (STORY) İŞLEMLERİ
  // ════════════════════════════════════════

  /// Yeni bir hikaye yükler
  Future<void> uploadStory({
    required String uid,
    required String username,
    required String displayName,
    String? photoUrl,
    required String base64Image,
  }) async {
    try {
      final now = DateTime.now();
      
      // 1. Hikaye koleksiyonuna ekle
      await _firestore.collection('stories').doc(uid).set({
        'uid': uid,
        'username': username,
        'displayName': displayName,
        'photoUrl': photoUrl,
        'imageUrl': base64Image,
        'createdAt': Timestamp.fromDate(now),
      });

      // 2. Kullanıcı profilindeki lastStoryAt alanını güncelle
      await _firestore.collection('users').doc(uid).update({
        'lastStoryAt': Timestamp.fromDate(now),
      });

      debugPrint('📸 Hikaye başarıyla yüklendi: $uid');
    } catch (e) {
      debugPrint('📸 Hikaye yükleme hatası: $e');
      rethrow;
    }
  }

  /// Arkadaşların aktif hikayelerini getirir (son 24 saat)
  Stream<List<UserStory>> getFriendStories(List<String> friendUids) {
    if (friendUids.isEmpty) return Stream.value([]);

    final yesterday = DateTime.now().subtract(const Duration(hours: 24));

    return _firestore
        .collection('stories')
        .where('uid', whereIn: friendUids.take(10).toList())
        .where('createdAt', isGreaterThan: Timestamp.fromDate(yesterday))
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) => UserStory.fromFirestore(doc)).toList();
        });
  }

  /// Belirli bir kullanıcının aktif hikayesini getirir
  Future<UserStory?> getUserStory(String uid) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final doc = await _firestore.collection('stories').doc(uid).get();
      
      if (!doc.exists) return null;
      
      final story = UserStory.fromFirestore(doc);
      if (story.createdAt.isBefore(yesterday)) return null;
      
      return story;
    } catch (e) {
      debugPrint('📸 Hikaye getirme hatası: $e');
      return null;
    }
  }
}
