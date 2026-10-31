import 'dart:async';
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
      String errorMsg = _handleAuthError(e);
      debugPrint('🔐 Email kayıt hatası (${e.code}): ${e.message}');
      return (user: null, error: errorMsg);
    } catch (e) {
      debugPrint('🔐 Email kayıt hatası: $e');
      return (user: null, error: 'Beklenmeyen bir hata oluştu. İnternet bağlantınızı kontrol edin.');
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
      String errorMsg = _handleAuthError(e);
      debugPrint('🔐 Email giriş hatası (${e.code}): ${e.message}');
      return (user: null, error: errorMsg);
    } catch (e) {
      debugPrint('🔐 Email giriş hatası: $e');
      return (user: null, error: 'Beklenmeyen bir hata oluştu. İnternet bağlantınızı kontrol edin.');
    }
  }

  /// Ortak Auth hata yakalayıcı
  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
      case 'internal-error':
      case 'unknown':
        if (e.message?.contains('Chain validation failed') ?? false) {
          return 'Bağlantı kurulamadı. Lütfen internet bağlantınızı veya cihaz saatini kontrol edin.';
        }
        return 'İnternet bağlantısı kurulamadı. Lütfen bağlantınızı kontrol edin.';
      case 'user-not-found':
        return 'Bu e-posta ile kayıtlı hesap bulunamadı.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'E-posta veya şifre hatalı.';
      case 'user-disabled':
        return 'Bu hesap devre dışı bırakılmış.';
      case 'invalid-email':
        return 'Geçersiz e-posta adresi.';
      case 'weak-password':
        return 'Şifre çok zayıf. En az 6 karakter olmalı.';
      case 'email-already-in-use':
        return 'Bu e-posta adresi zaten kullanımda.';
      default:
        // Her ihtimale karşı mesaj içinde SSL hatası arayalım
        if (e.message?.contains('Chain validation failed') ?? false) {
          return 'Güvenli bağlantı kurulamadı. Lütfen internet bağlantınızı veya cihaz saatini kontrol edin.';
        }
        return 'Hata: ${e.message ?? e.code}';
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
      if (e.toString().contains('network_error') || e.toString().contains('SocketException')) {
        throw 'İnternet bağlantısı kurulamadı. Lütfen kontrol edin.';
      }
      rethrow;
    }
  }

  /// Apple ile giriş (App Store, Google girişi olan uygulamalarda bunu da ister)
  Future<User?> signInWithApple() async {
    try {
      final saglayici = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      final sonuc = await _auth.signInWithProvider(saglayici);
      final user = sonuc.user;
      // Apple adı yalnızca ilk girişte verir; hesaba yaz ki profil oluşturulurken kullanılsın
      final ad = sonuc.additionalUserInfo?.profile?['name'];
      if (user != null && (user.displayName == null || user.displayName!.isEmpty) && ad is Map) {
        final tam = '${ad['firstName'] ?? ''} ${ad['lastName'] ?? ''}'.trim();
        if (tam.isNotEmpty) await user.updateDisplayName(tam);
      }
      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'canceled' || e.code == 'web-context-canceled') return null;
      debugPrint('🔐 Apple giriş hatası: $e');
      rethrow;
    }
  }

  /// Hesabın giriş yöntemi: 'password', 'google.com' ya da 'apple.com'
  String? get girisYontemi {
    final saglayicilar = _auth.currentUser?.providerData.map((p) => p.providerId).toList() ?? [];
    for (final s in ['password', 'google.com', 'apple.com']) {
      if (saglayicilar.contains(s)) return s;
    }
    return null;
  }

  /// Hesabı ve buluttaki tüm verilerini kalıcı olarak siler (mağaza kuralı: uygulama içinden silme).
  /// Silme işlemi yakın zamanda giriş gerektirdiği için önce kimlik yeniden doğrulanır;
  /// doğrulama başarısızsa hiçbir veri silinmez. Hata varsa mesaj döner.
  Future<String?> hesabiSil({String? sifre}) async {
    final user = _auth.currentUser;
    if (user == null) return 'Oturum bulunamadı.';
    final uid = user.uid;

    // 1) Kimliği yeniden doğrula
    try {
      switch (girisYontemi) {
        case 'password':
          if (sifre == null || sifre.isEmpty) return 'Şifreni girmelisin.';
          await user.reauthenticateWithCredential(
              EmailAuthProvider.credential(email: user.email!, password: sifre));
          break;
        case 'google.com':
          final g = await GoogleSignIn().signIn();
          if (g == null) return 'Doğrulama iptal edildi.';
          final a = await g.authentication;
          await user.reauthenticateWithCredential(
              GoogleAuthProvider.credential(accessToken: a.accessToken, idToken: a.idToken));
          break;
        case 'apple.com':
          await user.reauthenticateWithProvider(AppleAuthProvider());
          break;
      }
    } on FirebaseAuthException catch (e) {
      debugPrint('🔐 Yeniden doğrulama hatası: $e');
      if (e.code == 'wrong-password' || e.code == 'invalid-credential') return 'Şifre yanlış.';
      if (e.code == 'user-mismatch') return 'Bu hesapla aynı hesabı seçmelisin.';
      if (e.code == 'network-request-failed') return 'İnternet bağlantısı yok.';
      return 'Kimlik doğrulanamadı.';
    } catch (e) {
      debugPrint('🔐 Yeniden doğrulama hatası: $e');
      return 'Kimlik doğrulanamadı.';
    }

    // 2) Buluttaki verileri sil
    try {
      final ben = await _firestore.collection('users').doc(uid).get();
      final veri = ben.data() ?? {};
      final arkadaslar = List<String>.from(veri['friends'] ?? []);
      final kullaniciAdi = veri['username'] as String?;

      // Arkadaşların listesinden çık
      for (final a in arkadaslar) {
        try {
          await _firestore.collection('users').doc(a).update({
            'friends': FieldValue.arrayRemove([uid]),
          });
        } catch (e) {
          debugPrint('🗑️ Arkadaş listesinden çıkılamadı ($a): $e');
        }
      }
      // Başkalarına gönderilmiş istek / kabul / hatırlatma bildirimleri
      for (final a in {...arkadaslar, ...List<String>.from(veri['sentRequests'] ?? [])}) {
        for (final nid in [uid, '${uid}_kabul', '${uid}_durt']) {
          try {
            await _firestore.collection('users').doc(a).collection('notifications').doc(nid).delete();
          } catch (_) {}
        }
      }
      // Paylaşılan dualar
      final dualar = await _firestore.collection('prayers').where('senderUid', isEqualTo: uid).get();
      for (final d in dualar.docs) {
        await d.reference.delete();
      }
      // Ortak hatimler: kurduklarını sil, üye olduklarından ayrıl
      final hatimler = await _firestore.collection('hatimler').where('uyeler', arrayContains: uid).get();
      for (final h in hatimler.docs) {
        try {
          if (h.data()['olusturan'] == uid) {
            await h.reference.delete();
          } else {
            final cuzler = Map<String, dynamic>.from(h.data()['cuzler'] ?? {});
            cuzler.removeWhere((_, c) => c is Map && c['uid'] == uid);
            await h.reference.update({
              'uyeler': FieldValue.arrayRemove([uid]),
              'cuzler': cuzler,
            });
          }
        } catch (e) {
          debugPrint('🗑️ Hatim temizlenemedi (${h.id}): $e');
        }
      }
      // Hikaye, kendi bildirimleri, kullanıcı adı ve profil
      try {
        await _firestore.collection('stories').doc(uid).delete();
      } catch (_) {}
      final bildirimler = await _firestore.collection('users').doc(uid).collection('notifications').get();
      for (final b in bildirimler.docs) {
        await b.reference.delete();
      }
      if (kullaniciAdi != null && kullaniciAdi.isNotEmpty) {
        try {
          await _firestore.collection('usernames').doc(kullaniciAdi).delete();
        } catch (_) {}
      }
      await _firestore.collection('users').doc(uid).delete();
    } catch (e) {
      debugPrint('🗑️ Veri silme hatası: $e');
      return 'Veriler silinemedi. İnternet bağlantını kontrol edip tekrar dene.';
    }

    // 3) Hesabın kendisi
    try {
      await _tokenYenilemeAboneligi?.cancel();
      _tokenYenilemeAboneligi = null;
      await user.delete();
      try {
        await GoogleSignIn().signOut();
      } catch (_) {}
      return null;
    } catch (e) {
      debugPrint('🗑️ Hesap silme hatası: $e');
      return 'Verilerin silindi ama hesap kapatılamadı. Lütfen tekrar dene.';
    }
  }

  /// Hesaptan çıkış yapar
  Future<void> signOut() async {
    await _tokenYenilemeAboneligi?.cancel();
    _tokenYenilemeAboneligi = null;
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

  /// Profil oluşturulamayan yeni hesabı siler ki aynı e-postayla tekrar kayıt olunabilsin
  Future<void> yeniHesabiGeriAl() async {
    try {
      await _auth.currentUser?.delete();
    } catch (e) {
      debugPrint('🔐 Yarım hesap silinemedi: $e');
      await _auth.signOut();
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

  /// Kullanıcının profil kaydının Firestore'da olup olmadığını kontrol eder.
  /// Bağlantı hatasında `null` döner: "profil yok" ile "öğrenilemedi" ayrı tutulmalı,
  /// aksi halde mevcut profilin üzerine yenisi yazılabilir.
  Future<bool?> hasUserProfile(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.exists;
    } catch (e) {
      debugPrint('👤 Profil kontrol hatası: $e');
      return null;
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
    } on FirebaseException catch (e) {
      if (e.code == 'unavailable' || e.code == 'network-request-failed' || e.code == 'deadline-exceeded') {
        throw 'İnternet bağlantısı yok veya sunucuya erişilemiyor.';
      }
      rethrow;
    } catch (e) {
      debugPrint('🔍 Username kontrol hatası: $e');
      // Bağlantı hatalarını tahmin et
      if (e.toString().contains('SocketException') || e.toString().contains('HandshakeException')) {
        throw 'İnternet bağlantınızı kontrol edin.';
      }
      return false; // Diğer beklenmedik hatalarda güvenlik için dolu farz et
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
    // isUsernameAvailable hata durumunda false döndüğü için sonsuz döngüye girmemeli
    for (int deneme = 0; deneme < 10; deneme++) {
      String newName = '${base}_${random.nextInt(9999)}';
      if (await isUsernameAvailable(newName)) return newName;
    }
    throw 'Kullanıcı adı oluşturulamadı. Lütfen tekrar deneyin.';
  }

  /// Yeni kullanıcı profili oluşturur (ilk girişte kullanıcı adı seçtikten sonra).
  /// Kullanıcı adı rezervasyonu ve profil tek bir transaction'da yazılır; ad bu arada
  /// başkası tarafından alındıysa [kullaniciAdiAlindiHatasi] fırlatır. Diğer hatalar da fırlatılır.
  Future<void> createUserProfile({
    required String uid,
    required String username,
    required String displayName,
    int initialXp = 0,
    int initialStreak = 0,
  }) async {
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

    final profileRef = _firestore.collection('users').doc(uid);
    final usernameRef = _firestore.collection('usernames').doc(username);

    await _firestore.runTransaction((transaction) async {
      final mevcut = await transaction.get(usernameRef);
      final sahibi = mevcut.data()?['uid'];
      if (mevcut.exists && sahibi != uid) {
        throw kullaniciAdiAlindiHatasi;
      }
      transaction.set(profileRef, profile.toFirestore());
      transaction.set(usernameRef, {
        'uid': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });

    debugPrint('👤 Profil oluşturuldu: $username (XP: $initialXp)');
  }

  static const String kullaniciAdiAlindiHatasi = 'Bu kullanıcı adı daha önce alınmış.';

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

  /// Arkadaş sıralaması, ortak hedef ve "bugün kıldıkları" için özet durumu yazar
  Future<void> updateSosyalDurum({
    required String uid,
    required String haftaKey,
    required int haftalikXp,
    required int haftalikNamaz,
    required String bugunTarih,
    required List<String> bugunKilinan,
  }) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'haftaKey': haftaKey,
        'haftalikXp': haftalikXp,
        'haftalikNamaz': haftalikNamaz,
        'bugunTarih': bugunTarih,
        'bugunKilinan': bugunKilinan,
      });
    } catch (e) {
      debugPrint('📊 Sosyal durum güncelleme hatası: $e');
    }
  }

  /// Profil fotoğrafı: küçültülmüş JPEG, "data:image/jpeg;base64,..." olarak saklanır. null → kaldır
  Future<bool> updateProfilFoto(String uid, String? fotoDataUri) async {
    try {
      await _firestore.collection('users').doc(uid).update({'photoUrl': fotoDataUri});
      return true;
    } catch (e) {
      debugPrint('🖼️ Profil fotoğrafı güncelleme hatası: $e');
      return false;
    }
  }

  Future<void> updateCinsiyet(String uid, String cinsiyet) async {
    try {
      await _firestore.collection('users').doc(uid).update({'cinsiyet': cinsiyet});
    } catch (e) {
      debugPrint('👤 Cinsiyet güncelleme hatası: $e');
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
        .map((snapshot) => snapshot.docs
            .map((doc) => AppNotification.fromFirestore(doc))
            .where((n) => !engellenenler.contains(n.fromUid))
            .toList());
  }

  /// Karşı taraf zaten bize istek atmışsa yeni istek yerine o istek kabul edilir.
  static const String arkadasOlduMesaji = 'arkadas_oldu';

  /// Hata mesajı, karşılıklı istekte [arkadasOlduMesaji] veya başarıda null döner.
  Future<String?> sendFriendRequest({
    required String targetUsername,
    required String senderUid,
    required String senderUsername,
    required String senderDisplayName,
  }) async {
    try {
      final cleanUsername = targetUsername.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      if (cleanUsername.isEmpty) return 'Geçerli bir kullanıcı adı girin.';
      if (cleanUsername == senderUsername) return 'Kendinize istek gönderemezsiniz.';

      final snap = await _firestore.collection('usernames').doc(cleanUsername).get();
      if (!snap.exists) return 'Bu kullanıcı adı sistemde bulunamadı.';

      final targetUid = snap.data()?['uid'] as String?;
      if (targetUid == null) return 'Kullanıcı hesabı hatalı.';
      if (targetUid == senderUid) return 'Kendinize istek gönderemezsiniz.';

      final senderProfile = await _firestore.collection('users').doc(senderUid).get();
      final myFriends = List<String>.from(senderProfile.data()?['friends'] ?? []);
      if (myFriends.contains(targetUid)) return 'Bu kardeşimizle zaten arkadaşsınız.';

      // Karşı taraf bize zaten istek göndermişse: ikinci bir istek yerine kabul et
      final gelenIstek = await _firestore
          .collection('users').doc(senderUid).collection('notifications').doc(targetUid).get();
      if (gelenIstek.exists && gelenIstek.data()?['status'] == 'pending') {
        final hata = await respondToFriendRequest(
          currentUid: senderUid,
          targetUid: targetUid,
          accept: true,
          currentUsername: senderUsername,
          currentDisplayName: senderDisplayName,
        );
        return hata ?? arkadasOlduMesaji;
      }

      final notificationRef = _firestore.collection('users').doc(targetUid).collection('notifications').doc(senderUid);
      final mevcut = await notificationRef.get();
      if (mevcut.exists && mevcut.data()?['status'] == 'pending') {
        return 'Bu kardeşimize zaten istek gönderdin, cevabı bekleniyor.';
      }

      await notificationRef.set({
        'type': 'friend_request',
        'fromUid': senderUid,
        'fromUsername': senderUsername,
        'fromDisplayName': senderDisplayName,
        'status': 'pending',
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _firestore.collection('users').doc(senderUid).update({
        'gonderilenIstekler': FieldValue.arrayUnion([targetUid]),
      });

      return null;
    } catch (e) {
      debugPrint('Arkadaş ekleme hatası: $e');
      return 'İstek gönderilemedi. İnternet bağlantınızı kontrol edin.';
    }
  }

  /// İsteği kabul eder / reddeder. Hata olursa kullanıcıya gösterilecek mesajı döner.
  Future<String?> respondToFriendRequest({
    required String currentUid,
    required String targetUid,
    required bool accept,
    String currentUsername = '',
    String currentDisplayName = '',
  }) async {
    try {
      final batch = _firestore.batch();
      final notifRef = _firestore.collection('users').doc(currentUid).collection('notifications').doc(targetUid);
      final hedefBildirimleri = _firestore.collection('users').doc(targetUid).collection('notifications');

      if (accept) {
        batch.update(notifRef, {'status': 'accepted'});
        batch.update(_firestore.collection('users').doc(currentUid), {
          'friends': FieldValue.arrayUnion([targetUid])
        });
        batch.update(_firestore.collection('users').doc(targetUid), {
          'friends': FieldValue.arrayUnion([currentUid])
        });
        // Karşılıklı gönderilmiş istek varsa o da artık geçersiz
        batch.delete(hedefBildirimleri.doc(currentUid));
        // İsteği gönderene "kabul edildi" haberi
        batch.set(hedefBildirimleri.doc('${currentUid}_kabul'), {
          'type': 'friend_accepted',
          'fromUid': currentUid,
          'fromUsername': currentUsername,
          'fromDisplayName': currentDisplayName,
          'status': 'unread',
          'timestamp': FieldValue.serverTimestamp(),
        });
      } else {
        // Reddedilen istek silinir: karşı taraf ileride tekrar istek gönderebilir
        batch.delete(notifRef);
      }

      await batch.commit();
      return null;
    } catch (e) {
      debugPrint('İstek cevaplama hatası: $e');
      return 'İşlem tamamlanamadı. İnternet bağlantınızı kontrol edin.';
    }
  }

  /// Arkadaşa "namazını kıldın mı?" hatırlatması gönderir (her arkadaşa günde bir kez).
  /// Hata ya da bilgi mesajı, başarıda null döner.
  Future<String?> durtGonder({
    required String fromUid,
    required String fromUsername,
    required String fromDisplayName,
    required String targetUid,
    required String vakit,
    required String gun,
  }) async {
    try {
      final ref = _firestore.collection('users').doc(targetUid).collection('notifications').doc('${fromUid}_durt');
      final mevcut = await ref.get();
      if (mevcut.exists && mevcut.data()?['gun'] == gun) {
        return 'Bu kardeşine bugün zaten hatırlattın.';
      }
      await ref.set({
        'type': 'nudge',
        'fromUid': fromUid,
        'fromUsername': fromUsername,
        'fromDisplayName': fromDisplayName,
        'status': 'unread',
        'vakit': vakit,
        'gun': gun,
        'timestamp': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('👋 Hatırlatma gönderme hatası: $e');
      return 'Hatırlatma gönderilemedi. İnternet bağlantınızı kontrol edin.';
    }
  }

  /// Okunmamış bilgi bildirimlerini (kabul, hatırlatma) okundu yapar
  Future<void> bildirimleriOkunduYap(String uid, List<String> bildirimIdleri) async {
    if (bildirimIdleri.isEmpty) return;
    try {
      final batch = _firestore.batch();
      final koleksiyon = _firestore.collection('users').doc(uid).collection('notifications');
      for (final id in bildirimIdleri) {
        batch.update(koleksiyon.doc(id), {'status': 'read'});
      }
      await batch.commit();
    } catch (e) {
      debugPrint('🔔 Okundu işaretleme hatası: $e');
    }
  }

  Future<void> bildirimiSil(String uid, String bildirimId) async {
    try {
      await _firestore.collection('users').doc(uid).collection('notifications').doc(bildirimId).delete();
    } catch (e) {
      debugPrint('🔔 Bildirim silme hatası: $e');
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

  /// Arkadaşların profil bilgilerini anlık (stream) olarak dinler.
  /// Firestore 'whereIn' en fazla 30 değer aldığı için liste parçalara bölünüp birleştirilir.
  Stream<List<UserProfile>> getFriendsProfilesStream(List<String> friendUids) {
    if (friendUids.isEmpty) return Stream.value([]);

    final parcalar = [
      for (int i = 0; i < friendUids.length; i += 30)
        friendUids.sublist(i, min(i + 30, friendUids.length)),
    ];
    final sonuclar = List<List<UserProfile>?>.filled(parcalar.length, null);
    final abonelikler = <StreamSubscription>[];
    late final StreamController<List<UserProfile>> controller;
    controller = StreamController<List<UserProfile>>(
      onListen: () {
        for (int i = 0; i < parcalar.length; i++) {
          abonelikler.add(_firestore
              .collection('users')
              .where(FieldPath.documentId, whereIn: parcalar[i])
              .snapshots()
              .listen((snapshot) {
            sonuclar[i] = snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
            // Tüm parçalar en az bir kez geldiğinde yayınla
            if (sonuclar.every((p) => p != null)) {
              controller.add([for (final p in sonuclar) ...p!]);
            }
          }, onError: controller.addError));
        }
      },
      onCancel: () async {
        for (final a in abonelikler) {
          await a.cancel();
        }
      },
    );
    return controller.stream;
  }

  /// Arkadaş önerileri: önce ortak arkadaşı en çok olanlar, sonra en aktif kullanıcılar.
  /// Kendisi, arkadaşları ve zaten istek gönderdikleri hariç tutulur.
  Future<List<UserProfile>> getSuggestedFriends(
    String currentUid,
    List<String> currentFriends, {
    List<String> haric = const [],
  }) async {
    final disarida = {currentUid, ...currentFriends, ...haric};
    try {
      // Ortak arkadaş sayıları
      final ortak = <String, int>{};
      for (final arkadas in await getFriendsProfilesStream(currentFriends).first) {
        for (final uid in arkadas.friends) {
          if (!disarida.contains(uid)) ortak[uid] = (ortak[uid] ?? 0) + 1;
        }
      }
      final ortakSirali = ortak.keys.toList()..sort((a, b) => ortak[b]!.compareTo(ortak[a]!));
      final oneriler = ortakSirali.isEmpty
          ? <UserProfile>[]
          : await getFriendsProfilesStream(ortakSirali.take(10).toList()).first;
      oneriler.sort((a, b) => ortak[b.uid]!.compareTo(ortak[a.uid]!));

      if (oneriler.length < 10) {
        final snap = await _firestore
            .collection('users')
            .orderBy('totalXp', descending: true)
            .limit(30)
            .get();
        for (final doc in snap.docs) {
          if (oneriler.length >= 10) break;
          if (disarida.contains(doc.id) || oneriler.any((o) => o.uid == doc.id)) continue;
          oneriler.add(UserProfile.fromFirestore(doc));
        }
      }
      return oneriler;
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

  // ════════════════════════════════════════
  // 🛡️ MODERASYON: şikâyet ve engelleme
  // ════════════════════════════════════════

  /// Bu kadar farklı kişi şikâyet eden dua herkesten gizlenir (sunucu da isApproved=false yapar)
  static const int sikayetEsigi = 3;

  /// Oturumdaki kullanıcı ve engelledikleri: akışlardan gizlenir (provider günceller)
  static String? oturumUid;
  static Set<String> engellenenler = {};

  static bool duaGorunurMu(PrayerPost p) =>
      p.sikayetEdenler.length < sikayetEsigi &&
      !(oturumUid != null && p.sikayetEdenler.contains(oturumUid)) &&
      !engellenenler.contains(p.senderUid);

  Future<String?> duayiSikayetEt(String prayerId, String uid) async {
    try {
      await _firestore.collection('prayers').doc(prayerId).update({
        'sikayetEdenler': FieldValue.arrayUnion([uid]),
      });
      return null;
    } catch (e) {
      debugPrint('🛡️ Şikâyet hatası: $e');
      return 'Şikâyet gönderilemedi. İnternet bağlantınızı kontrol edin.';
    }
  }

  Future<String?> duayiSil(String prayerId) async {
    try {
      await _firestore.collection('prayers').doc(prayerId).delete();
      return null;
    } catch (e) {
      debugPrint('🤲 Dua silme hatası: $e');
      return 'Dua silinemedi.';
    }
  }

  /// Kullanıcıyı engeller: arkadaşlıktan çıkarır, duaları ve bildirimleri gizlenir
  Future<String?> kullaniciyiEngelle(String uid, String hedefUid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'engellenenler': FieldValue.arrayUnion([hedefUid]),
      });
      await removeFriend(currentUid: uid, targetUid: hedefUid);
      engellenenler = {...engellenenler, hedefUid};
      return null;
    } catch (e) {
      debugPrint('🛡️ Engelleme hatası: $e');
      return 'Kullanıcı engellenemedi.';
    }
  }

  Future<void> engeliKaldir(String uid, String hedefUid) async {
    try {
      await _firestore.collection('users').doc(uid).update({
        'engellenenler': FieldValue.arrayRemove([hedefUid]),
      });
      engellenenler = {...engellenenler}..remove(hedefUid);
    } catch (e) {
      debugPrint('🛡️ Engel kaldırma hatası: $e');
    }
  }

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
  /// Dualar haftalık gösterilir: her pazartesi 00:00'da akış sıfırlanır (veriler silinmez)
  static DateTime haftaBaslangici() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day - (n.weekday - 1));
  }

  Stream<List<PrayerPost>> getPrayers({int limit = 30, String? excludeUid}) {
    return _firestore
        .collection('prayers')
        .where('isApproved', isEqualTo: true)
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(haftaBaslangici()))
        .orderBy('timestamp', descending: true)
        .limit(limit + (excludeUid != null ? 1 : 0)) // Kendi duası çıkarsa yerine başkası gelsin diye +1
        .snapshots()
        .map((snapshot) {
      var list = snapshot.docs
          .map((doc) => PrayerPost.fromFirestore(doc))
          .where(duaGorunurMu)
          .where((prayer) => excludeUid == null || prayer.senderUid != excludeUid)
          .toList();
      return list.take(limit).toList();
    }).asBroadcastStream();
  }

  /// Belirli bir kullanıcının yayınladığı dualar
  Stream<List<PrayerPost>> getMyPrayers(String uid, {int limit = 30}) {
    return _firestore
        .collection('prayers')
        .where('senderUid', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      var list = snapshot.docs
          .map((doc) => PrayerPost.fromFirestore(doc))
          .where(duaGorunurMu)
          .toList();
      // Firestore composite index hatası almamak için Dart tarafında sıralıyoruz
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(limit).toList();
    });
  }

  /// Sadece arkadaşların yayınladığı dualar (Gönül Kardeşliği)
  Stream<List<PrayerPost>> getFriendsPrayers(List<String> friendUids, {int limit = 30}) {
    if (friendUids.isEmpty) {
      return Stream.value(<PrayerPost>[]);
    }
    
    // Firestore 'whereIn' sorgusu maksimim 10 eleman destekler
    final targetUids = friendUids.take(10).toList();

    return _firestore
        .collection('prayers')
        .where('senderUid', whereIn: targetUids)
        .snapshots()
        .map((snapshot) {
      var list = snapshot.docs
          .map((doc) => PrayerPost.fromFirestore(doc))
          .where(duaGorunurMu)
          .where((prayer) => prayer.isApproved && !prayer.timestamp.isBefore(haftaBaslangici()))
          .toList();
      // Firestore composite index hatası almamak için orderBy ve limit'i Dart'ta yapıyoruz
      list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return list.take(limit).toList();
    });
  }

  /// Trendler / Global: Son 24 saatte en çok Amîn alan dualar
  Stream<List<PrayerPost>> getDiscoverPrayers({int limit = 30, String? excludeUid}) {
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
          .where(duaGorunurMu)
          .where((prayer) => excludeUid == null || prayer.senderUid != excludeUid)
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

    // Token yenilenirse güncelle (her girişte yeni dinleyici eklenmesin)
    await _tokenYenilemeAboneligi?.cancel();
    _tokenYenilemeAboneligi = _messaging.onTokenRefresh.listen((newToken) {
      _firestore.collection('users').doc(uid).update({
        'fcmToken': newToken,
      });
    });
  }

  // Uygulamada birden çok FirebaseService örneği oluşturulduğu için static
  static StreamSubscription<String>? _tokenYenilemeAboneligi;

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
        'viewers': [],
        'viewerProfiles': [],
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
        .where('uid', whereIn: friendUids.take(30).toSet().toList())
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => UserStory.fromFirestore(doc))
              .where((s) => s.createdAt.isAfter(yesterday))
              .toList();
        });
  }

  /// Arkadaşların aktif hikayelerini getirir (son 24 saat) - Tek seferlik çekim
  Future<List<UserStory>> getActiveStoriesFuture(List<String> friendUids, String currentUid) async {
    final yesterday = DateTime.now().subtract(const Duration(hours: 24));
    
    // Hem benim hem arkadaşlarımın UID'lerini birleştir (Tekilleştirerek)
    final allUids = {currentUid, ...friendUids}.toList();

    // Sadece UID bazlı çekelim, tarihi hafızada filtreleyelim (İndeks hatasını önlemek için)
    final query = await _firestore
        .collection('stories')
        .where('uid', whereIn: allUids.take(30).toList())
        .get();

    final stories = query.docs
        .map((doc) => UserStory.fromFirestore(doc))
        .where((s) => s.createdAt.isAfter(yesterday))
        .toList();
    
    // Tıklama sırasına göre veya tarihe göre sıralayabiliriz. 
    // Şimdilik tarihe göre (eskiden yeniye) sıralayalım.
    stories.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    
    return stories;
  }

  /// Belirli bir kullanıcının aktif hikayesini getirir
  Future<UserStory?> getUserStory(String uid) async {
    try {
      final yesterday = DateTime.now().subtract(const Duration(hours: 24));
      final doc = await _firestore.collection('stories').doc(uid).get();
      
      if (!doc.exists) return null;
      
      final story = UserStory.fromFirestore(doc);
      
      // Eğer hikaye 24 saatten eskiyse fiziksel olarak sil (Lazy Delete)
      if (story.createdAt.isBefore(yesterday)) {
        await doc.reference.delete();
        debugPrint('📸 Süresi dolan hikaye silindi: $uid');
        return null;
      }
      
      return story;
    } catch (e) {
      debugPrint('📸 Hikaye getirme hatası: $e');
      return null;
    }
  }

  /// Hikaye izlenme kaydı yapar
  Future<void> recordStoryView({
    required String storyUid,
    required String viewerUid,
    required String viewerDisplayName,
    String? viewerPhotoUrl,
  }) async {
    try {
      final docRef = _firestore.collection('stories').doc(storyUid);
      
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) return;

        final data = snapshot.data() as Map<String, dynamic>;
        final List<String> viewers = List<String>.from(data['viewers'] ?? []);
        
        // Eğer zaten izlemişse veya hikaye kendisininkiyse kaydetme
        if (viewers.contains(viewerUid) || storyUid == viewerUid) return;

        viewers.add(viewerUid);
        
        final List<Map<String, dynamic>> viewerProfiles = List<Map<String, dynamic>>.from(data['viewerProfiles'] ?? []);
        
        // Yeni izleyen profilini en başa ekle
        viewerProfiles.insert(0, {
          'uid': viewerUid,
          'displayName': viewerDisplayName,
          'photoUrl': viewerPhotoUrl,
          'viewedAt': Timestamp.now(),
        });

        // Sadece son 20 profili tutalım
        if (viewerProfiles.length > 20) {
          viewerProfiles.removeRange(20, viewerProfiles.length);
        }

        transaction.update(docRef, {
          'viewers': viewers,
          'viewerProfiles': viewerProfiles,
        });
      });
    } catch (e) {
      debugPrint('📸 Hikaye izlenme kaydı hatası: $e');
    }
  }

  /// Hikayeyi fiziksel olarak siler
  Future<void> deleteStory(String uid) async {
    try {
      await _firestore.collection('stories').doc(uid).delete();
      await _firestore.collection('users').doc(uid).update({
        'lastStoryAt': null,
      });
      debugPrint('📸 Hikaye kullanıcı tarafından silindi: $uid');
    } catch (e) {
      debugPrint('📸 Hikaye silme hatası: $e');
    }
  }
}
