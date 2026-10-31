import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/namaz_servis.dart';
import '../services/seviye_servisi.dart';
import '../services/rozet_servisi.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';
import 'package:quran/quran.dart' as quran;
import 'dart:math';
import '../models/religious_day.dart';
import '../models/prayer_post.dart';
import '../models/story.dart';
import '../models/user_profile.dart' show haftaAnahtari;
import '../services/local_db_service.dart';
import '../core/constants/iller.dart';
import '../core/utils/extensions.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:image_picker/image_picker.dart';
import 'package:home_widget/home_widget.dart';

class NamazProvider extends ChangeNotifier {
  final NamazServisi _namazServisi;
  final NotificationService _notificationService;
  final FirebaseService _firebaseService;
  final LocalDbService _localDbService = LocalDbService();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // --- FIREBASE / AUTH DURUMLARI ---
  bool _needsProfile = false;
  bool get needsProfile => _needsProfile;
  bool _isAuthReady = false;
  bool get isAuthReady => _isAuthReady;
  String? _currentUid;
  String? get currentUid => _currentUid;
  String _currentUsername = '';
  String get currentUsername => _currentUsername;
  String _currentHandle = '';
  String get currentHandle => _currentHandle;

  // --- PROFİL: cinsiyet ve fotoğraf ---
  String? _cinsiyet; // 'kadin' | 'erkek'
  String? get cinsiyet => _cinsiyet;
  bool get kadinMi => _cinsiyet == 'kadin';
  bool _cinsiyetBulutKontrolEdildi = false;
  /// Bulut da kontrol edildiği halde cinsiyet bilinmiyorsa bir kez sorulur (Google / eski hesaplar)
  bool get cinsiyetSorulmali =>
      _currentUid != null && !_needsProfile && _cinsiyet == null && _cinsiyetBulutKontrolEdildi;
  String? _profilFoto;
  String? get profilFoto => _profilFoto;

  /// Cinsiyet yalnızca bir kez belirlenir; sonradan değiştirilemez
  Future<void> cinsiyetAyarla(String cinsiyet) async {
    if (_cinsiyet != null) return;
    _cinsiyet = cinsiyet;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cinsiyet', cinsiyet);
    if (_currentUid != null) unawaited(_firebaseService.updateCinsiyet(_currentUid!, cinsiyet));
    notifyListeners();
  }

  /// Galeriden fotoğraf seçer, küçültüp profile kaydeder. Hata mesajı ya da null döner.
  Future<String?> profilFotoSec() async {
    if (_currentUid == null) return 'Giriş yapmanız gerekiyor.';
    try {
      final secilen = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 256,
        maxHeight: 256,
        imageQuality: 70,
      );
      if (secilen == null) return null; // Vazgeçildi
      final foto = 'data:image/jpeg;base64,${base64Encode(await secilen.readAsBytes())}';
      if (!await _firebaseService.updateProfilFoto(_currentUid!, foto)) {
        return 'Fotoğraf kaydedilemedi. İnternet bağlantınızı kontrol edin.';
      }
      _profilFoto = foto;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('🖼️ Fotoğraf seçme hatası: $e');
      return 'Fotoğraf seçilemedi.';
    }
  }

  Future<String?> profilFotoKaldir() async {
    if (_currentUid == null) return null;
    if (!await _firebaseService.updateProfilFoto(_currentUid!, null)) {
      return 'Fotoğraf kaldırılamadı. İnternet bağlantınızı kontrol edin.';
    }
    _profilFoto = null;
    notifyListeners();
    return null;
  }

  /// Cinsiyet ve fotoğrafı buluttaki profilden alır
  Future<void> _profilBilgileriniAl(String uid) async {
    try {
      final profil = await _firebaseService.getUserProfileFuture(uid);
      if (profil == null) return;
      _profilFoto = profil.photoUrl;
      FirebaseService.oturumUid = uid;
      FirebaseService.engellenenler = profil.engellenenler.toSet();
      arkadasSayisi = profil.friends.length;
      unawaited(_rozetKontrol());
      if (profil.cinsiyet != null && profil.cinsiyet != _cinsiyet) {
        _cinsiyet = profil.cinsiyet;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cinsiyet', _cinsiyet!);
      } else if (profil.cinsiyet == null && _cinsiyet != null) {
        // Bu cihazda seçilmiş ama buluta yazılamamış
        unawaited(_firebaseService.updateCinsiyet(uid, _cinsiyet!));
      }
      _cinsiyetBulutKontrolEdildi = true;
    } catch (_) {
    } finally {
      // Arka planda biterse provider kapatılmış olabilir
      if (!_kapatildi) notifyListeners();
    }
  }

  // --- STATE DEĞİŞKENLERİ ---
  bool isLoading = true;
  String hataMesaji = "";
  Map<String, String>? vakitler;
  String aktifVakit = "Sabah";
  ValueNotifier<String> kalanSureNotifier = ValueNotifier("--:--:--");
  ValueNotifier<String> guncelSaatNotifier = ValueNotifier("");
  String ekranTarihi = "";
  String konumBilgisi = "Yükleniyor...";
  String vaktinTemasi = "night";
  String seciliSehir = "";
  bool bildirimlerAcik = true;
  String bildirimSesi = "varsayilan"; // "varsayilan", "ezan_mekke", "ezan_medine", "beep", "ozel"
  String? ozelSesYolu;

  int streakCount = 0;
  int toplamTamamlanan = 0;
  String gununAyetiMeali = "";
  String gununAyetiReferans = "";
  int gununAyetiSureNo = 1;
  int gununAyetiNo = 1;

  // 🔥 SEVİYE SİSTEMİ DEĞİŞKENLERİ
  int _toplamXp = 0;
  int get toplamXp => _toplamXp;
  String get mevcutUnvan => SeviyeServisi.unvanGetir(_toplamXp);
  double get seviyeIlerleme => SeviyeServisi.ilerlemeHesapla(_toplamXp);

  // 🔥 GÜNLÜK XP TAKİBİ
  Map<String, int> _xpGecmisi = {};
  Map<String, int> get xpGecmisi => _xpGecmisi;
  int get bugunKazanilanXp => _xpGecmisi[getSanalGun()] ?? 0;

  /// Merkezi XP güncelleme metodu
  Future<void> _xpGuncelle(int miktar) async {
    final prefs = await SharedPreferences.getInstance();
    final sanalBugun = getSanalGun();
    
    _toplamXp += miktar;
    if (_toplamXp < 0) _toplamXp = 0;
    
    // Günlük geçmişe işle
    _xpGecmisi[sanalBugun] = (_xpGecmisi[sanalBugun] ?? 0) + miktar;
    if ((_xpGecmisi[sanalBugun] ?? 0) < 0) _xpGecmisi[sanalBugun] = 0;
    
    await prefs.setInt('toplam_xp', _toplamXp);
    await prefs.setString('xpGecmisi', json.encode(_xpGecmisi));
    
    _firebaseCloudSync();
    notifyListeners();
  }
  
  /// Dışarıdan XP eklemek için kullanılır (Örn: Dua beğenme, dua ekleme)
  Future<void> xpEkle(int miktar) async {
    await _xpGuncelle(miktar);
  }

  String sonSifirlamaTarihi = "";
  String _sonKontrolEdilenGun = ""; // 00:00 kontrolü için

  static final DateFormat _gunFormati = DateFormat('yyyy-MM-dd');

  // 🔥 ÖNÜMÜZDEKİ GÜNLERİN VAKİTLERİ (bildirimler ve çevrimdışı kullanım için)
  // Anahtar: "yyyy-MM-dd"
  Map<String, Map<String, String>> _vakitTakvimi = {};
  static const int _bildirimGunSayisi = 7;

  // 🔥 KAZA HATIRLATICISI
  bool kazaHatirlatmaAcik = false;
  int kazaHatirlatmaSaat = 20;
  int kazaHatirlatmaDakika = 0;

  // 🔥 BULUT SENKRONU: Yerel XP buluta ancak bu cihazdaki veri hesaba bağlandıktan sonra yazılır
  bool _bulutBirlestirildi = false;
  Future<void>? _birlestirmeIslemi;

  // 🔥 ZİKİRMATİK DEĞİŞKENLERİ
  int _zikirSayaci = 0;
  int _zikirHedefi = 33;
  int _zikirXpKazanilan = 0;
  Map<String, int> _zikirGecmisi = {};

  int get zikirSayaci => _zikirSayaci;
  int get zikirHedefi => _zikirHedefi;
  int get zikirXpKazanilan => _zikirXpKazanilan;
  Map<String, int> get zikirGecmisi => _zikirGecmisi;

  // 🔥 İSTATİSTİK VE TAKVİM İÇİN YENİ EKLENENLER
  DateTime? ilkAcilisTarihi;
  Map<String, int> aylikGecmis = {};
  Map<String, int> kazaGecmisi = {}; // Hangi gün kaç kaza kılındı detayını tutar
  Map<String, dynamic> gunlukDetaylar = {}; // Hangi gün hangi vakit kılındı detayını tutar
  
  // 🔥 DİNİ GÜNLER API STATE
  Map<String, ReligiousDay> tumDiniGunler = {}; // Format: "yyyy-MM-dd"
  final Set<String> _aylikDiniGunlerCache = {};
  bool isDiniGunlerLoading = false;

  // 🔥 SOSYAL ÖNBELLEK
  List<PrayerPost> _cachedPrayers = [];
  List<PrayerPost> get cachedPrayers => _cachedPrayers;

  Map<String, bool> kildiMi = {
    "Sabah": false,
    "Öğle": false,
    "İkindi": false,
    "Akşam": false,
    "Yatsı": false,
  };
  final List<String> vakitIsimleri = [
    "Sabah",
    "Öğle",
    "İkindi",
    "Akşam",
    "Yatsı",
  ];
  Map<String, int> kazaNamazlari = {
    "Sabah": 0,
    "Öğle": 0,
    "İkindi": 0,
    "Akşam": 0,
    "Yatsı": 0,
  };

  List<FlSpot> grafikNoktalari = [];
  List<String> gunIsimleri = [];
  Timer? _timer;

  bool _kapatildi = false;

  @override
  void dispose() {
    _kapatildi = true;
    _timer?.cancel();
    kalanSureNotifier.dispose();
    guncelSaatNotifier.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  NamazProvider(this._namazServisi, this._notificationService, this._firebaseService) {
    _uygulamayiBaslat();
  }

  Future<void> _uygulamayiBaslat() async {
    await loadData();
    await _gununAyetiniYukle();

    // 🔥 FIREBASE AUTH KONTROLÜ
    await _firebaseAuthKontrol();

    if (vakitler != null) {
      // Önbellekteki vakitlerle hemen başla; gün değiştiyse internet/GPS beklemeden sıfırla
      _takvimdenBugunuYukle();
      await _sabahVaktiSifirlamaKontrolu();
      isLoading = false;
      _ilkVakitHesapla();
      _sayaciBaslat();
      _bildirimleriGuncelle();
      notifyListeners();
    }

    await konumVeApiIstegi(kullaniciTetikledi: false);

    // Açılışta bu ay ve sonraki 2 ayın dini günlerini getir (banner + geri sayım)
    final simdi = DateTime.now();
    for (int i = 0; i < 3; i++) {
      final ay = DateTime(simdi.year, simdi.month + i);
      await seciliAyDiniGunleriGetir(ay.year, ay.month);
    }
  }

  /// Firebase auth kontrolü — giriş yapmış mı kontrol et
  Future<void> _firebaseAuthKontrol() async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        _currentUid = user.uid;
        final prefs = await SharedPreferences.getInstance();
        final hasProfile = await _firebaseService.hasUserProfile(user.uid);
        // Bağlantı yoksa (null): bu cihazda daha önce profil kurulduysa çevrimdışı devam et
        final profilVar = hasProfile ?? (prefs.getString('firebase_handle')?.isNotEmpty ?? false);
        if (profilVar) {
          _needsProfile = false;
          _currentUsername = prefs.getString('firebase_username') ?? user.displayName ?? '';
          _currentHandle = prefs.getString('firebase_handle') ?? '';

          // Eğer handle yoksa Firestore'dan çek (Geriye dönük uyumluluk)
          if (_currentHandle.isEmpty) {
            try {
              final doc = await _firebaseService
                  .getUserProfile(user.uid)
                  .first
                  .timeout(const Duration(seconds: 5));
              if (doc != null) {
                _currentHandle = doc.username;
                await prefs.setString('firebase_handle', _currentHandle);
              }
            } catch (_) {}
          }

          unawaited(_bulutlaBirlestir(user.uid));
          _firebaseService.initMessaging(user.uid);
          unawaited(_profilBilgileriniAl(user.uid));
        } else {
          _needsProfile = true;
        }
      } else {
        // Giriş yapılmamış — Auth ekranı gösterilecek
        _needsProfile = true;
      }
    } catch (e) {
      debugPrint('🔐 Firebase auth kontrol hatası: $e');
      _needsProfile = true;
    } finally {
      _isAuthReady = true;
      notifyListeners();
    }
  }

  static const String _baglantiHatasi =
      'Sunucuya ulaşılamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';

  /// Yeni oluşturulan hesap: bu cihazdaki veri başka bir hesaba aitse devralınmaz.
  Future<void> _yeniHesabaBagla(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final sahip = prefs.getString('xp_sahibi_uid');
    if (sahip != null && sahip != uid) {
      _toplamXp = 0;
      _xpGecmisi = {};
      streakCount = 0;
      await prefs.setInt('toplam_xp', 0);
      await prefs.setString('xpGecmisi', '{}');
      await prefs.setInt('streakCount', 0);
    }
    await prefs.setString('xp_sahibi_uid', uid);
    _bulutBirlestirildi = true;
  }

  /// Mevcut hesap: bu cihaz hesabın verisini ilk kez tutacaksa (yeni telefon, yeniden kurulum,
  /// başka hesaptan geçiş) buluttaki XP/seri esas alınır. Bulut okunamazsa buluta hiçbir şey
  /// yazılmaz, sonraki senkronda tekrar denenir. Bu sayede yeni cihazdaki 0 XP buluttakini ezmez.
  Future<void> _bulutlaBirlestir(String uid) {
    return _birlestirmeIslemi ??= () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final sahip = prefs.getString('xp_sahibi_uid');
        if (sahip != uid) {
          final bulut = await _firebaseService.getUserProfileFuture(uid);
          if (bulut == null) return;
          if (sahip != null) {
            // Yerel veri başka bir hesaba ait: devralma
            _toplamXp = bulut.totalXp;
            streakCount = bulut.streak;
            _xpGecmisi = {};
          } else {
            // Eski sürümden kalan, sahibi belli olmayan yerel veri
            _toplamXp = max(_toplamXp, bulut.totalXp);
            streakCount = max(streakCount, bulut.streak);
          }
          await prefs.setInt('toplam_xp', _toplamXp);
          await prefs.setInt('streakCount', streakCount);
          await prefs.setString('xpGecmisi', json.encode(_xpGecmisi));
          await prefs.setString('xp_sahibi_uid', uid);
          notifyListeners();
        }
        _bulutBirlestirildi = true;
        await _firebaseService.updateUserStats(
          uid: uid,
          totalXp: _toplamXp,
          streak: streakCount,
        );
        _sosyalDurumuGonder();
      } catch (e) {
        debugPrint('☁️ Bulut birleştirme hatası: $e');
      } finally {
        _birlestirmeIslemi = null;
      }
    }();
  }

  /// Email/Şifre ile kayıt ol
  Future<String?> emailIleKayitOl({
    required String email,
    required String password,
    required String displayName,
    required String username,
    String? cinsiyet,
  }) async {
    // 1. Kullanıcı adının müsaitliğini kontrol et
    try {
      final isAvailable = await _firebaseService.isUsernameAvailable(username);
      if (!isAvailable) return 'Bu kullanıcı adı daha önce alınmış.';
    } catch (e) {
      return e.toString();
    }

    final result = await _firebaseService.registerWithEmail(
      email: email,
      password: password,
    );

    if (result.error != null) return result.error;
    if (result.user == null) return 'Hesap oluşturulamadı.';

    final uid = result.user!.uid;
    final prefs = await SharedPreferences.getInstance();
    await _yeniHesabaBagla(uid);

    try {
      await _firebaseService.createUserProfile(
        uid: uid,
        username: username,
        displayName: displayName,
        initialXp: _toplamXp,
        initialStreak: streakCount,
      );
    } catch (e) {
      // Profil yazılamadıysa yarım kalan hesabı geri al, kullanıcı aynı e-postayla tekrar deneyebilsin
      await _firebaseService.yeniHesabiGeriAl();
      return e == FirebaseService.kullaniciAdiAlindiHatasi
          ? FirebaseService.kullaniciAdiAlindiHatasi
          : 'Profil oluşturulamadı. İnternet bağlantınızı kontrol edip tekrar deneyin.';
    }

    _currentUid = uid;
    _currentUsername = displayName;
    _currentHandle = username;
    _needsProfile = false;
    await prefs.setString('firebase_username', displayName);
    await prefs.setString('firebase_handle', username);
    _cinsiyetBulutKontrolEdildi = true;
    if (cinsiyet != null) await cinsiyetAyarla(cinsiyet);
    _firebaseService.initMessaging(_currentUid!);
    notifyListeners();
    return null; // Hata yok
  }

  /// Email/Şifre ile giriş yap (mevcut hesap)
  Future<String?> emailIleGirisYap({
    required String email,
    required String password,
  }) async {
    final result = await _firebaseService.signInWithEmail(
      email: email,
      password: password,
    );

    if (result.error != null) return result.error;
    if (result.user == null) return 'Giriş yapılamadı.';

    _currentUid = result.user!.uid;
    final prefs = await SharedPreferences.getInstance();

    final hasProfile = await _firebaseService.hasUserProfile(_currentUid!);
    // Profil durumu öğrenilemediyse yeni profil oluşturma: mevcut profilin üzerine yazılabilir
    if (hasProfile == null) return _baglantiHatasi;

    if (hasProfile) {
      _needsProfile = false;
      _currentUsername = prefs.getString('firebase_username') ?? result.user!.displayName ?? '';
      _currentHandle = prefs.getString('firebase_handle') ?? '';

      if (_currentHandle.isEmpty) {
        final doc = await _firebaseService.getUserProfileFuture(_currentUid!);
        if (doc != null) {
          _currentHandle = doc.username;
          if (_currentUsername.isEmpty) _currentUsername = doc.displayName;
          await prefs.setString('firebase_handle', _currentHandle);
        }
      }
      await _bulutlaBirlestir(_currentUid!);
    } else {
      // Email ile giriş yaptı ama profili yoksa (olağandışı durum) boşta bir kullanıcı adıyla oluştur
      final displayName = result.user!.displayName ?? email.split('@')[0];
      try {
        final username = await _firebaseService.generateUniqueUsername(displayName);
        await _yeniHesabaBagla(_currentUid!);
        await _firebaseService.createUserProfile(
          uid: _currentUid!,
          username: username,
          displayName: displayName,
          initialXp: _toplamXp,
          initialStreak: streakCount,
        );
        _currentHandle = username;
      } catch (e) {
        return 'Profil oluşturulamadı. Lütfen tekrar deneyin.';
      }
      _currentUsername = displayName;
      _needsProfile = false;
      await prefs.setString('firebase_username', displayName);
      await prefs.setString('firebase_handle', _currentHandle);
    }

    _firebaseService.initMessaging(_currentUid!);
    unawaited(_profilBilgileriniAl(_currentUid!));
    notifyListeners();
    return null; // Hata yok
  }

  /// Google ile giriş yapar (alternatif yöntem)
  Future<String?> googleIleGirisYap() async {
    try {
      final user = await _firebaseService.signInWithGoogle();
      if (user == null) return 'Google girişi iptal edildi.';

      _currentUid = user.uid;
      final prefs = await SharedPreferences.getInstance();

      final hasProfile = await _firebaseService.hasUserProfile(user.uid);
      if (hasProfile == null) return _baglantiHatasi;

      if (hasProfile) {
        _needsProfile = false;
        _currentUsername = prefs.getString('firebase_username') ?? user.displayName ?? '';
        _currentHandle = prefs.getString('firebase_handle') ?? '';
        if (_currentHandle.isEmpty) {
          final doc = await _firebaseService.getUserProfileFuture(user.uid);
          if (doc != null) {
            _currentHandle = doc.username;
            await prefs.setString('firebase_handle', _currentHandle);
          }
        }
        await _bulutlaBirlestir(user.uid);
      } else {
        final googleName = user.displayName ?? 'Google Kullanıcı';
        String base = googleName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (base.isEmpty) base = 'kullanici';

        try {
          final isAvailable = await _firebaseService.isUsernameAvailable(base);
          if (!isAvailable) {
            // İsim doluysa UI'a sinyal gönder (UI modal açacak ve completeGoogleRegistration çağıracak)
            return 'google_username_taken';
          }
          await _yeniHesabaBagla(user.uid);
          await _firebaseService.createUserProfile(
            uid: user.uid,
            username: base,
            displayName: googleName,
            initialXp: _toplamXp,
            initialStreak: streakCount,
          );
        } catch (e) {
          if (e == FirebaseService.kullaniciAdiAlindiHatasi) return 'google_username_taken';
          return e is String ? e : 'Profil oluşturulamadı. Lütfen tekrar deneyin.';
        }
        _currentUsername = googleName;
        _currentHandle = base;
        _needsProfile = false;
        await prefs.setString('firebase_username', googleName);
        await prefs.setString('firebase_handle', base);
      }

      _firebaseService.initMessaging(user.uid);
      unawaited(_profilBilgileriniAl(user.uid));
      notifyListeners();
      return null; // Hata yok
    } catch (e) {
      debugPrint('🔐 Google giriş hatası (Provider): $e');
      return e.toString().contains('İnternet') ? e.toString() : 'Google ile giriş yapılamadı.';
    }
  }

  /// Google kaydını username seçimi ile tamamlar (Çakışma varsa UI'dan çağrılır).
  /// Görünen ad Google hesabından alınır; [displayName] yalnızca o yoksa kullanılır.
  Future<String?> completeGoogleRegistration({required String username, String? displayName}) async {
    if (_currentUid == null) return 'Oturum bulunamadı.';

    try {
      final isAvailable = await _firebaseService.isUsernameAvailable(username);
      if (!isAvailable) return 'Bu kullanıcı adı daha önce alınmış.';
    } catch (e) {
      return e.toString();
    }

    final prefs = await SharedPreferences.getInstance();
    final googleAdi = _firebaseService.currentUser?.displayName;
    final gorunenAd = (googleAdi != null && googleAdi.isNotEmpty)
        ? googleAdi
        : (displayName ?? username);

    await _yeniHesabaBagla(_currentUid!);
    try {
      await _firebaseService.createUserProfile(
        uid: _currentUid!,
        username: username,
        displayName: gorunenAd,
        initialXp: _toplamXp,
        initialStreak: streakCount,
      );
    } catch (e) {
      return e == FirebaseService.kullaniciAdiAlindiHatasi
          ? FirebaseService.kullaniciAdiAlindiHatasi
          : 'Profil oluşturulamadı. Lütfen tekrar deneyin.';
    }

    _currentUsername = gorunenAd;
    _currentHandle = username;
    _needsProfile = false;
    await prefs.setString('firebase_username', gorunenAd);
    await prefs.setString('firebase_handle', username);
    _firebaseService.initMessaging(_currentUid!);
    _cinsiyetBulutKontrolEdildi = true;
    notifyListeners();

    return null;
  }

  /// Hesaptan çıkış yapar
  Future<void> cikisYap() async {
    await _firebaseService.signOut();
    _currentUid = null;
    _bulutBirlestirildi = false;
    _needsProfile = true;
    _currentUsername = '';
    _currentHandle = '';
    _cinsiyet = null;
    _profilFoto = null;
    FirebaseService.oturumUid = null;
    FirebaseService.engellenenler = {};
    _cinsiyetBulutKontrolEdildi = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firebase_username');
    await prefs.remove('firebase_handle');
    await prefs.remove('cinsiyet');
    notifyListeners();
  }

  /// Arkadaşı siler
  Future<void> arkadasiSil(String targetUid) async {
    if (_currentUid == null) return;
    await _firebaseService.removeFriend(
      currentUid: _currentUid!,
      targetUid: targetUid,
    );
    // UI StreamBuilder kullandığı için otomatik güncellenecektir.
  }

  /// Yerel XP/streak'i Firebase'e arka planda senkronize eder
  void _firebaseCloudSync() {
    if (_currentUid == null) return;
    if (!_bulutBirlestirildi) {
      // Önce bu cihazın verisini hesapla eşleştir (eşleşince kendisi buluta yazar)
      _bulutlaBirlestir(_currentUid!);
      return;
    }
    _firebaseService.updateUserStats(
      uid: _currentUid!,
      totalXp: _toplamXp,
      streak: streakCount,
    );
    _sosyalDurumuGonder();
  }

  /// Bu haftanın (pazartesiden itibaren, sanal güne göre) XP ve kılınan namaz toplamı
  ({String hafta, int xp, int namaz}) get haftalikOzet {
    final bugun = DateFormat('yyyy-MM-dd').parse(getSanalGun());
    final hafta = haftaAnahtari(bugun);
    int xp = 0, namaz = 0;
    for (int i = 0; i < bugun.weekday; i++) {
      final gun = _gunFormati.format(DateTime(bugun.year, bugun.month, bugun.day - i));
      xp += _xpGecmisi[gun] ?? 0;
      namaz += i == 0 ? kildiMi.values.where((v) => v).length : (aylikGecmis[gun] ?? 0);
    }
    return (hafta: hafta, xp: xp, namaz: namaz);
  }

  void _sosyalDurumuGonder() {
    if (_currentUid == null || !_bulutBirlestirildi) return;
    final ozet = haftalikOzet;
    _firebaseService.updateSosyalDurum(
      uid: _currentUid!,
      haftaKey: ozet.hafta,
      haftalikXp: ozet.xp,
      haftalikNamaz: ozet.namaz,
      bugunTarih: getSanalGun(),
      bugunKilinan: [for (final v in vakitIsimleri) if (kildiMi[v] == true) v],
    );
  }

  /// Sosyal akış önbelleğini günceller
  Future<void> updatePrayerCache(List<PrayerPost> prayers) async {
    _cachedPrayers = prayers.take(20).toList();
    await _localDbService.cachePrayers(prayers);
  }

  Position _konumOlustur(double lat, double lng) => Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

  /// Vakitlerin en son hesaplandığı konum (GPS veya seçilen şehir)
  Future<Position?> _vakitKonumu() async {
    final prefs = await SharedPreferences.getInstance();
    final lat = prefs.getDouble('vakit_lat') ?? prefs.getDouble('last_lat');
    final lng = prefs.getDouble('vakit_lng') ?? prefs.getDouble('last_lng');
    if (lat == null || lng == null) return null;
    return _konumOlustur(lat, lng);
  }

  /// Konum değiştiyse eski konumun vakit takvimi kullanılmasın
  Future<void> _vakitKonumunuKaydet(double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    final eskiLat = prefs.getDouble('vakit_lat');
    final eskiLng = prefs.getDouble('vakit_lng');
    if (eskiLat == null ||
        eskiLng == null ||
        Geolocator.distanceBetween(eskiLat, eskiLng, lat, lng) > 5000) {
      _vakitTakvimi = {};
      await prefs.remove('vakit_takvimi');
    }
    await prefs.setDouble('vakit_lat', lat);
    await prefs.setDouble('vakit_lng', lng);
  }

  /// Takvimde bugünün vakitleri varsa onları kullan: uygulama günlerce çevrimdışı kalsa da
  /// her gün o günün vakitleri gösterilir. Değişiklik olduysa true döner.
  bool _takvimdenBugunuYukle() {
    final bugun = _vakitTakvimi[_gunFormati.format(DateTime.now())];
    if (bugun == null || mapEquals(bugun, vakitler)) return false;
    vakitler = Map<String, String>.from(bugun);
    SharedPreferences.getInstance().then(
      (prefs) => prefs.setString('cached_vakitler', json.encode(vakitler)),
    );
    return true;
  }

  /// Önümüzdeki günlerin vakitlerini indirir (7 günlük bildirim ve çevrimdışı kullanım için)
  Future<void> _takvimiGuncelle(Position konum) async {
    final simdi = DateTime.now();
    final ileri = DateTime(simdi.year, simdi.month, simdi.day + _bildirimGunSayisi);
    final aylar = {(simdi.year, simdi.month), (ileri.year, ileri.month)};

    final yeni = <String, Map<String, String>>{};
    try {
      for (final (yil, ay) in aylar) {
        yeni.addAll(await _namazServisi.aylikVakitleriGetir(yil, ay, konum));
      }
    } catch (e) {
      debugPrint('📅 Vakit takvimi alınamadı: $e');
      return;
    }

    final dun = _gunFormati.format(DateTime(simdi.year, simdi.month, simdi.day - 1));
    _vakitTakvimi = {
      for (final e in yeni.entries)
        if (e.key.compareTo(dun) >= 0) e.key: e.value,
    };
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vakit_takvimi', json.encode(_vakitTakvimi));

    if (_takvimdenBugunuYukle()) _ilkVakitHesapla();
    await _bildirimleriGuncelle();
  }

  /// Yeni alınan bugünün vakitlerini uygular: önbellek, gün sıfırlama, sayaç, bildirimler, takvim
  Future<void> _vakitleriUygula(Map<String, String> veriler, double lat, double lng) async {
    final prefs = await SharedPreferences.getInstance();
    vakitler = veriler;
    await prefs.setString('cached_vakitler', json.encode(vakitler));
    await _vakitKonumunuKaydet(lat, lng);

    await _sabahVaktiSifirlamaKontrolu();
    _ilkVakitHesapla();
    _sayaciBaslat();
    await _bildirimleriGuncelle();
    unawaited(_takvimiGuncelle(_konumOlustur(lat, lng)));
  }

  /// İnternet veya GPS yokken: önbellekteki vakitler/takvimle günü yine de ilerlet
  Future<void> _cevrimdisiDevamEt() async {
    if (vakitler == null) return;
    _takvimdenBugunuYukle();
    await _sabahVaktiSifirlamaKontrolu();
    _ilkVakitHesapla();
    _sayaciBaslat();
  }

  /// GPS ile vakitleri yeniler. Kullanıcı elle şehir seçtiyse şehrin vakitleri yenilenir.
  /// Vakitler alındıysa true döner.
  Future<bool> konumVeApiIstegi({bool kullaniciTetikledi = false}) async {
    if (seciliSehir.isNotEmpty) {
      return sehirVakitleriniGetir(seciliSehir);
    }

    if (vakitler == null) {
      isLoading = true;
      notifyListeners();
    }

    bool basarili = false;
    try {
      Position? position = await _namazServisi.konumGetir(
        izinIste: kullaniciTetikledi,
      );

      if (position == null) {
        if (vakitler == null) {
          konumBilgisi = "Konum İzni Gerekli";
          hataMesaji = "Vakitleri gösterebilmemiz için konum izni verin veya şehir seçin.";
        }
        await _cevrimdisiDevamEt();
      } else {
        final veriler = await _namazServisi.vakitleriGetir(position);
        await _vakitleriUygula(veriler, position.latitude, position.longitude);
        _adresGuncelle(position);
        hataMesaji = "";
        basarili = true;
      }
    } catch (e) {
      String errStr = e.toString();
      if (vakitler == null) {
        konumBilgisi = "Şehir Seçin";
        hataMesaji = "Konum alınamadı. Konum servisini açın veya şehir seçin.\nDetay: $errStr";
      } else if (kullaniciTetikledi) {
        if (errStr.toLowerCase().contains("konum") || e is TimeoutException) {
          hataMesaji = "Konum servisi ulaşılamadığı için çevrimdışı veriler kullanılıyor.\nDetay: $errStr";
        } else {
          hataMesaji = "Bağlantı hatası oluştu, çevrimdışı veriler kullanılıyor.\nDetay: $errStr";
        }
      }
      await _cevrimdisiDevamEt();
    }

    isLoading = false;
    notifyListeners();
    return basarili;
  }

  /// Seçilen ilin merkez koordinatlarıyla vakitleri getirir. Başarılıysa true döner.
  Future<bool> sehirVakitleriniGetir(String sehir) async {
    final il = ilBul(sehir);
    if (il == null) return false;

    if (vakitler == null) {
      isLoading = true;
      notifyListeners();
    }

    bool basarili = false;
    try {
      final veriler = await _namazServisi.vakitleriGetir(_konumOlustur(il.lat, il.lng));
      final prefs = await SharedPreferences.getInstance();

      seciliSehir = sehir;
      konumBilgisi = "TÜRKİYE, ${sehir.trBuyuk}";
      await prefs.setString('secili_sehir', sehir);
      await prefs.setString('cached_location', konumBilgisi);
      // GPS'e dönüldüğünde adres yeniden çözülsün
      await prefs.remove('last_lat');
      await prefs.remove('last_lng');

      await _vakitleriUygula(veriler, il.lat, il.lng);
      hataMesaji = "";
      basarili = true;
    } catch (e) {
      if (vakitler == null) {
        konumBilgisi = "Şehir Seçilmeli";
        hataMesaji =
            "Şehir verileri alınamadı. Lütfen bağlantınızı kontrol edin.\nDetay: ${e.toString()}";
      }
      await _cevrimdisiDevamEt();
    }

    isLoading = false;
    notifyListeners();
    return basarili;
  }

  /// Kullanıcının şehir seçimi. [sehir] null ise "Konumumu kullan": GPS'e döner.
  /// Hata olursa kullanıcıya gösterilecek mesajı döner, önceki seçim korunur.
  Future<String?> sehirSec(String? sehir) async {
    if (sehir != null) {
      final basarili = await sehirVakitleriniGetir(sehir);
      return basarili ? null : 'Şehir vakitleri alınamadı. İnternet bağlantınızı kontrol edin.';
    }

    final eskiSehir = seciliSehir;
    final eskiKonumBilgisi = konumBilgisi;
    seciliSehir = "";
    final basarili = await konumVeApiIstegi(kullaniciTetikledi: true);
    if (!basarili) {
      seciliSehir = eskiSehir;
      konumBilgisi = eskiKonumBilgisi;
      hataMesaji = ""; // Hata, seçim penceresinden ayrıca gösteriliyor
      notifyListeners();
      return 'Konum alınamadı. Konum servisinin açık ve iznin verilmiş olduğundan emin olun.';
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('secili_sehir');
    if (konumBilgisi == eskiKonumBilgisi && eskiSehir.isNotEmpty) {
      konumBilgisi = "MEVCUT KONUM"; // Adres çözülünce güncellenir
      notifyListeners();
    }
    return null;
  }

  void _adresGuncelle(Position pos) async {
    final prefs = await SharedPreferences.getInstance();
    double lastLat = prefs.getDouble('last_lat') ?? 0.0;
    double lastLng = prefs.getDouble('last_lng') ?? 0.0;
    double distance = Geolocator.distanceBetween(
      lastLat,
      lastLng,
      pos.latitude,
      pos.longitude,
    );

    if (distance < 5000 &&
        konumBilgisi != "Yükleniyor..." &&
        !konumBilgisi.contains("İzni")) {
      return;
    }

    try {
      List<Placemark> p = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      ).timeout(const Duration(seconds: 5));
      if (p.isNotEmpty) {
        konumBilgisi =
            "${p[0].country?.trBuyuk}, ${p[0].administrativeArea?.trBuyuk}";
        await prefs.setString('cached_location', konumBilgisi);
        await prefs.setDouble('last_lat', pos.latitude);
        await prefs.setDouble('last_lng', pos.longitude);
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final simdi = DateTime.now();
    ekranTarihi = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(simdi);
    _sonKontrolEdilenGun = DateFormat('yyyy-MM-dd').format(simdi);

    // 🔥 İLK AÇILIŞ TARİHİNİ KONTROL ET VE KAYDET
    String? ilkTarihStr = prefs.getString('ilk_acilis_tarihi');
    if (ilkTarihStr == null) {
      // Eğer daha önce kaydedilmemişse (ilk girişse) bugünü kaydet
      ilkTarihStr = DateFormat('yyyy-MM-dd').format(simdi);
      await prefs.setString('ilk_acilis_tarihi', ilkTarihStr);
    }
    ilkAcilisTarihi = DateFormat('yyyy-MM-dd').parse(ilkTarihStr);

    streakCount = prefs.getInt('streakCount') ?? 0;
    toplamTamamlanan = prefs.getInt('toplamKilinan') ?? 0;

    // 🔥 XP YÜKLEME
    _toplamXp = prefs.getInt('toplam_xp') ?? 0;
    final xpGecmisiStr = prefs.getString('xpGecmisi') ?? '{}';
    try {
      _xpGecmisi = Map<String, int>.from(json.decode(xpGecmisiStr));
    } catch (_) {
      _xpGecmisi = {};
    }

    sonSifirlamaTarihi = prefs.getString('lastResetDate') ?? "";
    konumBilgisi = prefs.getString('cached_location') ?? "Yükleniyor...";
    seciliSehir = prefs.getString('secili_sehir') ?? "";
    _cinsiyet = prefs.getString('cinsiyet');
    duaPaylasimSayisi = prefs.getInt('dua_paylasim_sayisi') ?? 0;
    orucModu = prefs.getBool('oruc_modu') ?? false;
    orucGunleri = (prefs.getStringList('oruc_gunleri') ?? []).toSet();
    kazaOrucBorcu = prefs.getInt('kaza_oruc_borcu') ?? 0;
    kilinanKazaOrucu = prefs.getInt('kilinan_kaza_orucu') ?? 0;

    String? cachedVakitlerString = prefs.getString('cached_vakitler');
    if (cachedVakitlerString != null) {
      try {
        vakitler = Map<String, String>.from(json.decode(cachedVakitlerString));
      } catch (e) {
        vakitler = null;
        await prefs.remove('cached_vakitler');
      }
    }
    for (var vkt in vakitIsimleri) {
      kildiMi[vkt] = prefs.getBool('kildi_$vkt') ?? false;
    }
    for (var vkt in vakitIsimleri) {
      kazaNamazlari[vkt] = prefs.getInt('kaza_$vkt') ?? 0;
    }

    bildirimlerAcik = prefs.getBool('bildirimler_acik') ?? true;
    bildirimSesi = prefs.getString('bildirim_sesi') ?? "varsayilan";
    ozelSesYolu = prefs.getString('ozel_ses_yolu');

    // 🔥 KAZA HATIRLATICISI
    kazaHatirlatmaAcik = prefs.getBool('kaza_hatirlatma_acik') ?? false;
    kazaHatirlatmaSaat = prefs.getInt('kaza_hatirlatma_saat') ?? 20;
    kazaHatirlatmaDakika = prefs.getInt('kaza_hatirlatma_dakika') ?? 0;

    // 🔥 VAKİT TAKVİMİ
    try {
      final ham = json.decode(prefs.getString('vakit_takvimi') ?? '{}') as Map<String, dynamic>;
      _vakitTakvimi = ham.map((k, v) => MapEntry(k, Map<String, String>.from(v)));
    } catch (_) {
      _vakitTakvimi = {};
    }

    // 🔥 ZİKİRMATİK VERİLERİNİ YÜKLE
    _zikirSayaci = prefs.getInt('zikirSayaci') ?? 0;
    _zikirHedefi = prefs.getInt('zikirHedefi') ?? 33;
    _zikirXpKazanilan = prefs.getInt('zikirXpKazanilan') ?? 0;
    final zikirGecmisiStr = prefs.getString('zikirGecmisi') ?? '{}';
    try {
      _zikirGecmisi = Map<String, int>.from(json.decode(zikirGecmisiStr));
    } catch (_) {
      _zikirGecmisi = {};
    }

    await istatistikleriYukle();
    
    // 🔥 KAZA GEÇMİŞİNİ YÜKLE
    final kazaGecmisiStr = prefs.getString('kazaGecmisi') ?? '{}';
    try {
      kazaGecmisi = Map<String, int>.from(json.decode(kazaGecmisiStr));
    } catch (_) {
      kazaGecmisi = {};
    }

    // 🔥 SOSYAL AKIŞ ÖNBELLEĞİNİ YÜKLE
    _cachedPrayers = await _localDbService.getCachedPrayers();
    // 📿 KAZA BORÇLARINI YÜKLE
    await kazaBorclariniYukle();
    notifyListeners();
  }

  // ══════════════════════════════════════════
  // 📿 KAZA NAMAZI YÖNETİMİ
  // ══════════════════════════════════════════

  // Kaza borç durumu: {vakit: {toplamBorc, kilinmis}}
  Map<String, Map<String, int>> _kazaBorclari = {};
  Map<String, Map<String, int>> get kazaBorclariMap => _kazaBorclari;

  /// Toplam kaza borcu (tüm vakitler)
  int get toplamKazaBorcu {
    int toplam = 0;
    for (final v in _kazaBorclari.values) {
      toplam += v['toplamBorc'] ?? 0;
    }
    return toplam;
  }

  /// Toplam kılınan kaza (tüm vakitler)
  int get toplamKilinanKaza {
    int toplam = 0;
    for (final v in _kazaBorclari.values) {
      toplam += v['kilinmis'] ?? 0;
    }
    return toplam;
  }

  /// Kaza borç verisini SQLite'dan yükler
  Future<void> kazaBorclariniYukle() async {
    _kazaBorclari = await _localDbService.getKazaBorclari();
    // Eğer eski SharedPreferences kazaNamazlari varsa onu da birleştir
    for (final vakit in vakitIsimleri) {
      final eskiBorc = kazaNamazlari[vakit] ?? 0;
      if (eskiBorc > 0 && (_kazaBorclari[vakit]?['toplamBorc'] ?? 0) == 0) {
        _kazaBorclari[vakit] = {'toplamBorc': eskiBorc, 'kilinmis': 0};
      }
    }
    notifyListeners();
  }

  /// Belirtilen vakitten [adet] kaza namazı kılar: SQLite günceller + XP kazandırır.
  /// Gerçekte kılınan (kalan borçla sınırlı) adedi döner.
  Future<int> kazaKil(String vakit, {int adet = 1}) async {
    final mevcut = _kazaBorclari[vakit] ?? {'toplamBorc': 0, 'kilinmis': 0};
    final borc = mevcut['toplamBorc'] ?? 0;
    final kilinmis = mevcut['kilinmis'] ?? 0;
    final kalan = borc - kilinmis;
    if (kalan <= 0 || adet <= 0) return 0;

    final kilinan = min(adet, kalan);
    final yeniKilinmis = kilinmis + kilinan;
    _kazaBorclari[vakit] = {'toplamBorc': borc, 'kilinmis': yeniKilinmis};
    await _localDbService.updateKazaBorc(vakit, kilinmis: yeniKilinmis);
    await xpEkle(SeviyeServisi.kazaXp * kilinan);

    // Günlük kaza geçmişini kaydet (Haftalık grafik için)
    final simdi = DateTime.now();
    final bugunStr = DateFormat('yyyy-MM-dd').format(simdi);
    kazaGecmisi[bugunStr] = (kazaGecmisi[bugunStr] ?? 0) + kilinan;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('kazaGecmisi', json.encode(kazaGecmisi));

    await _rozetKontrol();
    notifyListeners();
    return kilinan;
  }

  /// Tüm vakitler için toplu kaza kılar (1 günlük paket = her vakitten 1). Kılınan toplam adedi döner.
  Future<int> kazaKilGunlukPaket() async {
    int toplam = 0;
    for (final vakit in vakitIsimleri) {
      toplam += await kazaKil(vakit, adet: 1);
    }
    return toplam;
  }

  /// Hesaplanan borç miktarlarını SQLite'a kaydeder
  Future<void> kazaBorcunuAyarla(Map<String, int> borclar) async {
    for (final vakit in borclar.keys) {
      final yeniBorc = borclar[vakit]!;
      // Kılınmış sayısı yeni borçtan fazla olamaz (kalan eksiye düşmesin)
      final kilinmis = min(_kazaBorclari[vakit]?['kilinmis'] ?? 0, yeniBorc);
      _kazaBorclari[vakit] = {'toplamBorc': yeniBorc, 'kilinmis': kilinmis};
      await _localDbService.updateKazaBorc(vakit, toplamBorc: yeniBorc, kilinmis: kilinmis);
    }
    notifyListeners();
  }

  /// Günlük kaza hatırlatıcısını kaydeder ve kurar (bildirimler yeniden planlansa da korunur)
  Future<void> kazaHatirlatmaAyarla({required int saat, required int dakika, bool acik = true}) async {
    kazaHatirlatmaAcik = acik;
    kazaHatirlatmaSaat = saat;
    kazaHatirlatmaDakika = dakika;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kaza_hatirlatma_acik', acik);
    await prefs.setInt('kaza_hatirlatma_saat', saat);
    await prefs.setInt('kaza_hatirlatma_dakika', dakika);
    await _bildirimleriGuncelle();
    notifyListeners();
  }

  /// Kaza verilerini sıfırlar
  Future<void> sifirlaKaza() async {
    for (final vakit in vakitIsimleri) {
      _kazaBorclari[vakit] = {'toplamBorc': 0, 'kilinmis': 0};
    }
    await _localDbService.sifirlaKazaBorclari();
    notifyListeners();
  }

  /// Eski SharedPreferences tabanlı kaza metodu (geriye uyumluluk)
  Future<void> kazaGuncelle(String vakit, int miktar) async {
    final prefs = await SharedPreferences.getInstance();
    int yeniMiktar = (kazaNamazlari[vakit] ?? 0) + miktar;
    if (yeniMiktar < 0) yeniMiktar = 0;
    kazaNamazlari[vakit] = yeniMiktar;
    await prefs.setInt('kaza_$vakit', yeniMiktar);
    notifyListeners();
  }


  Future<void> vaktiKildimIsaretle(String vakitIsmi, bool yeniDurum) async {
    // Sadece 5 vakit işaretlenebilir ("Güneş" bir namaz vakti değil)
    if (!vakitIsimleri.contains(vakitIsmi)) return;
    // Sadece içinde bulunulan vakit işaretlenebilir; vakit çıkınca durum kesinleşir
    if (!vakitIsaretlenebilirMi(vakitIsmi)) return;
    // 🔥 XP SUİSTİMALİNİ ÖNLEME: Zaten aynı durumdaysa işlem yapma
    if (kildiMi[vakitIsmi] == yeniDurum) return;

    // 🔥 DURUMU HEMEN GÜNCELLE (Race condition önlemek için await öncesinde)
    kildiMi[vakitIsmi] = yeniDurum;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kildi_$vakitIsmi', yeniDurum);

    if (yeniDurum) {
      toplamTamamlanan++;

      int miktar = SeviyeServisi.namazXp;
      int kilinanSayisi = kildiMi.values.where((v) => v == true).length;
      if (kilinanSayisi == 5) {
        miktar += SeviyeServisi.tamGunBonusu;
        streakCount++; // Seri: 5 vakti tamamlanan gün sayısı
      }
      await _xpGuncelle(miktar);
      
    } else {
      if (toplamTamamlanan > 0) toplamTamamlanan--;

      int kilinanSayisi = kildiMi.values.where((v) => v == true).length;
      int geriAlinacakXp = SeviyeServisi.namazXp;
      if (kilinanSayisi == 4) {
        geriAlinacakXp += SeviyeServisi.tamGunBonusu;
        if (streakCount > 0) streakCount--; // Tamamlanmış gün geri alındı
      }

      await _xpGuncelle(-geriAlinacakXp);
    }
    
    await prefs.setInt('streakCount', streakCount);
    await prefs.setInt('toplamKilinan', toplamTamamlanan);

    // 🔥 FIREBASE CLOUD SYNC (fire-and-forget)
    _firebaseCloudSync();

    // 🔥 BİLDİRİMLERİ GÜNCELLE (Hatırlatıcıları iptal etmek veya yeniden planlamak için)
    await _bildirimleriGuncelle();

    await istatistikleriYukle();
    await _rozetKontrol();
    notifyListeners();
  }

  Future<void> bildirimAyariDegistir(bool yeniDurum) async {
    bildirimlerAcik = yeniDurum;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bildirimler_acik', yeniDurum);
    await _bildirimleriGuncelle();
    notifyListeners();
  }

  Future<void> bildirimSesiDegistir(String yeniSes) async {
    bildirimSesi = yeniSes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('bildirim_sesi', yeniSes);
    await _bildirimleriGuncelle();
    notifyListeners();
  }

  Future<void> ozelSesSec() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );

      if (result != null && result.files.single.path != null) {
        ozelSesYolu = result.files.single.path;
        bildirimSesi = "ozel";
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('bildirim_sesi', "ozel");
        await prefs.setString('ozel_ses_yolu', ozelSesYolu!);
        
        await _bildirimleriGuncelle();
        notifyListeners();
        // Önizleme çal
        sesOnizlemeCal("ozel", ozelSesYolu);
      }
    } catch (e) {
      debugPrint("Dosya seçme hatası: $e");
    }
  }

  Future<void> sesOnizlemeCal(String sound, String? path) async {
    try {
      await _audioPlayer.stop();
      
      if (sound == "varsayilan") {
        return; // Sistem varsayılanı için önizleme yapılmıyor
      }
      
      if (sound == "ozel" && path != null) {
        // Özel dosya yolu varsa çal
        await _audioPlayer.play(DeviceFileSource(path));
      } else if (sound != "varsayilan") {
        // Assets/sounds klasöründeki dosyayı çal (uzantı .mp3 varsayıyoruz)
        await _audioPlayer.play(AssetSource('sounds/$sound.mp3'));
      }
    } catch (e) {
      debugPrint("Önizleme çalma hatası ($sound): $e");
    }
  }



  // ══════════════════════════════════════════
  // 📅 GÜN SIFIRLAMA VE VAKİT HESABI
  // ══════════════════════════════════════════

  /// Uygulama hiç açılmadığında otomatik kazaya yazılacak en fazla gün sayısı.
  /// Daha uzun aralarda kullanıcının uygulamayı bıraktığı varsayılır.
  static const int _maxOtomatikKazaGunu = 30;

  bool _sifirlamaDevamEdiyor = false;

  Future<void> _kutucuklariSifirla(String sanalBugunStr) async {
    // Durumu await'lerden önce güncelle: eşzamanlı çağrılar aynı günü iki kez işlemesin
    final oncekiGun = sonSifirlamaTarihi;
    final oncekiDurum = Map<String, bool>.from(kildiMi);
    kildiMi.updateAll((key, value) => false);
    sonSifirlamaTarihi = sanalBugunStr;

    final prefs = await SharedPreferences.getInstance();

    if (oncekiGun.isNotEmpty) {
      // 🔥 KAÇIRILAN NAMAZLARI KAZA BORCUNA EKLE
      // Son kayıtlı günün kılınmayan vakitleri + uygulamanın hiç açılmadığı günler
      final gunFarki = _gunFarki(oncekiGun, sanalBugunStr);
      if (gunFarki > 0) {
        final acilmayanGun = min(gunFarki - 1, _maxOtomatikKazaGunu - 1);
        for (final vakit in vakitIsimleri) {
          final eksik = (oncekiDurum[vakit] == true ? 0 : 1) + acilmayanGun;
          if (eksik == 0) continue;
          final mevcut = _kazaBorclari[vakit] ?? {'toplamBorc': 0, 'kilinmis': 0};
          final yeniToplam = (mevcut['toplamBorc'] ?? 0) + eksik;
          _kazaBorclari[vakit] = {
            'toplamBorc': yeniToplam,
            'kilinmis': mevcut['kilinmis'] ?? 0,
          };
          await _localDbService.updateKazaBorc(vakit, toplamBorc: yeniToplam);
        }
        debugPrint("📅 Gün değişti ($gunFarki gün): Kaçırılan namazlar kaza borcuna eklendi.");
      }

      // --- BİTEN GÜNÜN VERİLERİNİ KAYDET ---
      String? historyJson = prefs.getString('history_stats');
      Map<String, dynamic> history = historyJson != null ? json.decode(historyJson) : {};
      history[oncekiGun] = oncekiDurum.values.where((v) => v).length;
      await prefs.setString('history_stats', json.encode(history));

      String? detailsJson = prefs.getString('history_details');
      Map<String, dynamic> details = detailsJson != null ? json.decode(detailsJson) : {};
      details[oncekiGun] = oncekiDurum;
      await prefs.setString('history_details', json.encode(details));
    }

    for (var vkt in vakitIsimleri) {
      await prefs.setBool('kildi_$vkt', false);
    }
    await prefs.setString('lastResetDate', sanalBugunStr);

    await istatistikleriYukle();
    _sosyalDurumuGonder();
    notifyListeners();
  }

  DateTime getSanalSimdi() {
    final simdi = DateTime.now();
    if (vakitler == null) return simdi;

    final sabahVakti = _parseTime(vakitler!['Sabah']!);
    // Eğer şu anki saat Sabah vaktinden önceyse, henüz dünkü "dini" gündeyiz.
    if (simdi.isBefore(sabahVakti)) {
      return simdi.subtract(const Duration(days: 1));
    }
    return simdi;
  }

  String getSanalGun() {
    return DateFormat('yyyy-MM-dd').format(getSanalSimdi());
  }

  /// Yeni dini güne geçildiyse (sabah vakti girdiyse) dünü kapatır ve kutucukları sıfırlar.
  /// Açılışta, vakitler yenilendiğinde ve her saniye sayaçta kontrol edilir.
  Future<void> _sabahVaktiSifirlamaKontrolu() async {
    if (vakitler == null || _sifirlamaDevamEdiyor) return;
    final sanalBugunStr = getSanalGun();
    if (sonSifirlamaTarihi == sanalBugunStr) return;

    _sifirlamaDevamEdiyor = true;
    try {
      // Seri gün sonunda bozulur: dün eksik kaldıysa veya arada hiç açılmayan gün varsa
      if (sonSifirlamaTarihi.isNotEmpty && streakCount > 0) {
        final dunuTamamladiMi = kildiMi.values.every((v) => v == true);
        final gunAtlandi = _gunFarki(sonSifirlamaTarihi, sanalBugunStr) > 1;
        if (!dunuTamamladiMi || gunAtlandi) {
          // Ayda bir hak: tek bir eksik gün (arada atlanan gün yoksa) seriyi bozmaz
          if (!gunAtlandi && await _seriDondurmaKullan(sanalBugunStr)) {
            seriDondurmaMesaji =
                "❄️ Dün eksik kaldı ama bu ayki seri dondurma hakkın kullanıldı, $streakCount günlük serin korundu.";
          } else {
            await _streakSifirla();
          }
        }
      }
      await _kutucuklariSifirla(sanalBugunStr);
    } finally {
      _sifirlamaDevamEdiyor = false;
    }
  }

  /// Bu ay seri dondurma hakkı kullanılmadıysa kullanır
  Future<bool> _seriDondurmaKullan(String gun) async {
    final prefs = await SharedPreferences.getInstance();
    final ay = gun.substring(0, 7);
    if (prefs.getString('seri_dondurma_ay') == ay) return false;
    await prefs.setString('seri_dondurma_ay', ay);
    return true;
  }

  /// Bu ay seri dondurma hakkı duruyor mu?
  Future<bool> seriDondurmaHakkiVar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('seri_dondurma_ay') != getSanalGun().substring(0, 7);
  }

  /// Ana ekranda bir kez gösterilecek seri dondurma bilgisi
  String? seriDondurmaMesaji;

  // ══════════════════════════════════════════
  // 🏅 ROZETLER
  // ══════════════════════════════════════════

  int duaPaylasimSayisi = 0;
  int arkadasSayisi = 0;
  /// Ana ekranda bir kez gösterilecek "yeni rozet" bilgisi
  Rozet? yeniRozet;

  List<Rozet> get rozetler => RozetServisi.hesapla(
        toplamNamaz: toplamTamamlanan,
        gunlukKilinan: {...aylikGecmis, getSanalGun(): kildiMi.values.where((v) => v).length},
        kilinanKaza: toplamKilinanKaza,
        toplamZikir: _zikirGecmisi.values.fold(0, (t, v) => t + v),
        duaPaylasimi: duaPaylasimSayisi,
        arkadasSayisi: arkadasSayisi,
      );

  /// Yeni kazanılan rozet varsa kaydeder ve [yeniRozet] olarak duyurur
  Future<void> _rozetKontrol() async {
    final prefs = await SharedPreferences.getInstance();
    final eski = (prefs.getStringList('kazanilan_rozetler') ?? []).toSet();
    final kazanilan = rozetler.where((r) => r.kazanildi).toList();
    final yeni = kazanilan.where((r) => !eski.contains(r.id)).toList();
    if (yeni.isEmpty) return;
    await prefs.setStringList('kazanilan_rozetler', kazanilan.map((r) => r.id).toList());
    // İlk kurulumda geçmiş rozetler toplu duyurulmasın; sadece biri yeni kazanıldıysa göster
    if (prefs.getBool('rozetler_baslatildi') ?? false) yeniRozet = yeni.last;
    await prefs.setBool('rozetler_baslatildi', true);
    if (!_kapatildi) notifyListeners();
  }

  Future<void> duaPaylasildi() async {
    duaPaylasimSayisi++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('dua_paylasim_sayisi', duaPaylasimSayisi);
    await _rozetKontrol();
  }

  Future<void> _streakSifirla() async {
    streakCount = 0;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('streakCount', 0);
    _firebaseCloudSync();
    notifyListeners();
  }

  /// Şu anki vakit dilimi ve bitiş zamanı. Güneş doğunca Sabah vakti çıkar ("Güneş" dilimi);
  /// bu dilimde Öğle'ye kadar kılınacak bir farz yoktur.
  ({String vakit, DateTime bitis}) _vakitDilimi(DateTime simdi) {
    final yarin = DateTime(simdi.year, simdi.month, simdi.day + 1);
    return vakitDilimiHesapla(vakitler!, simdi, yarinSabah: _vakitTakvimi[_gunFormati.format(yarin)]?['Sabah']);
  }

  /// Saatten bağımsız (test edilebilir) vakit dilimi hesabı. Güneş doğunca Sabah vakti çıkar
  /// ("Güneş" dilimi); Sabah'tan önce hâlâ dünkü Yatsı'dayız.
  static ({String vakit, DateTime bitis}) vakitDilimiHesapla(
    Map<String, String> v,
    DateTime simdi, {
    String? yarinSabah,
  }) {
    DateTime saat(String s, [int gunEkle = 0]) {
      final p = s.split(' ').first.split(':');
      return DateTime(simdi.year, simdi.month, simdi.day + gunEkle, int.parse(p[0]), int.parse(p[1]));
    }

    final sabah = saat(v['Sabah']!);
    if (simdi.isBefore(sabah)) return (vakit: 'Yatsı', bitis: sabah);

    const dilimler = ['Sabah', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
    String onceki = 'Sabah';
    for (final dilim in dilimler.skip(1)) {
      final s = v[dilim];
      if (s == null) continue; // Eski önbellekte Güneş olmayabilir
      final baslangic = saat(s);
      if (simdi.isBefore(baslangic)) return (vakit: onceki, bitis: baslangic);
      onceki = dilim;
    }

    // Yatsı: yarının sabah vaktine kadar
    return (vakit: 'Yatsı', bitis: saat(yarinSabah ?? v['Sabah']!, 1));
  }

  /// Kerahat vakitleri (yaklaşık 45 dk): güneş doğarken, tam tepedeyken (öğleden önce), batarken (akşamdan önce)
  static const Duration kerahatSuresi = Duration(minutes: 45);

  static ({String neden, DateTime bitis})? kerahatHesapla(Map<String, String> v, DateTime simdi) {
    DateTime? saat(String ad) {
      final s = v[ad];
      if (s == null) return null;
      final p = s.split(' ').first.split(':');
      return DateTime(simdi.year, simdi.month, simdi.day, int.parse(p[0]), int.parse(p[1]));
    }

    final gunes = saat('Güneş'), ogle = saat('Öğle'), aksam = saat('Akşam');
    bool icinde(DateTime bas, DateTime son) => !simdi.isBefore(bas) && simdi.isBefore(son);
    if (gunes != null && icinde(gunes, gunes.add(kerahatSuresi))) {
      return (neden: 'Güneş doğuyor', bitis: gunes.add(kerahatSuresi));
    }
    if (ogle != null && icinde(ogle.subtract(kerahatSuresi), ogle)) {
      return (neden: 'Güneş tam tepede (istiva)', bitis: ogle);
    }
    if (aksam != null && icinde(aksam.subtract(kerahatSuresi), aksam)) {
      return (neden: 'Güneş batıyor', bitis: aksam);
    }
    return null;
  }

  ({String neden, DateTime bitis})? get kerahatVakti =>
      vakitler == null ? null : kerahatHesapla(vakitler!, DateTime.now());

  /// Yalnızca şu anki vakit işaretlenebilir. Geçmiş vakitler sonradan işaretlenemez;
  /// kullanıcı vakit içinde bildirimlerle uygulamaya çağrılır.
  bool vakitIsaretlenebilirMi(String vakit) =>
      vakitler != null && _vakitDilimi(DateTime.now()).vakit == vakit;

  void _ilkVakitHesapla() {
    if (vakitler == null) return;
    aktifVakit = _vakitDilimi(DateTime.now()).vakit;
    notifyListeners();
  }

  /// "05:12" veya "05:12 (+03)" saatini verilen güne uygular
  DateTime _saatiTariheUygula(DateTime gun, String saat) {
    final parts = saat.split(' ').first.split(':');
    return DateTime(gun.year, gun.month, gun.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  DateTime _parseTime(String timeStr) => _saatiTariheUygula(DateTime.now(), timeStr);

  /// İki "yyyy-MM-dd" tarihi arasındaki gün farkı (b - a)
  int _gunFarki(String a, String b) {
    try {
      DateTime utc(String s) {
        final p = s.split('-').map(int.parse).toList();
        return DateTime.utc(p[0], p[1], p[2]);
      }
      return utc(b).difference(utc(a)).inDays;
    } catch (_) {
      return 1;
    }
  }

  void _sayaciBaslat() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (vakitler == null) return;
      final simdi = DateTime.now();
      final bugunStr = _gunFormati.format(simdi);

      // --- 00:00 GÜN DEĞİŞİMİ: günün ayeti, takvimden yeni günün vakitleri, bildirim penceresi ---
      if (_sonKontrolEdilenGun != bugunStr) {
        _sonKontrolEdilenGun = bugunStr;
        _gununAyetiniYukle();
        _takvimdenBugunuYukle();
        _bildirimleriGuncelle();
      }

      // --- SABAH VAKTİ: yeni dini gün (uygulama arka plandan dönse de yakalanır) ---
      if (!_sifirlamaDevamEdiyor && sonSifirlamaTarihi != getSanalGun()) {
        _sabahVaktiSifirlamaKontrolu();
      }

      final dilim = _vakitDilimi(simdi);
      bool degisti = false;
      if (aktifVakit != dilim.vakit) {
        aktifVakit = dilim.vakit;
        degisti = true;
      }

      final fark = dilim.bitis.difference(simdi);
      kalanSureNotifier.value =
          "${fark.inHours.toString().padLeft(2, '0')}:${(fark.inMinutes % 60).toString().padLeft(2, '0')}:${(fark.inSeconds % 60).toString().padLeft(2, '0')}";
      guncelSaatNotifier.value = DateFormat("HH:mm").format(simdi);

      final yeniTarih = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(simdi);
      if (ekranTarihi != yeniTarih) {
        ekranTarihi = yeniTarih;
        degisti = true;
      }

      _temaGuncelle();
      if (degisti) notifyListeners();
    });
  }

  void _temaGuncelle() {
    if (vakitler == null) return;
    final simdi = DateTime.now();
    try {
      final sabah = _parseTime(vakitler!['Sabah']!);
      final gunes = vakitler!.containsKey('Güneş')
          ? _parseTime(vakitler!['Güneş']!)
          : sabah.add(const Duration(hours: 1));
      final ogle = _parseTime(vakitler!['Öğle']!);
      final ikindi = _parseTime(vakitler!['İkindi']!);
      final aksam = _parseTime(vakitler!['Akşam']!);
      final yatsi = _parseTime(vakitler!['Yatsı']!);

      String yeniTema = "night";
      if (simdi.isAfter(sabah) && simdi.isBefore(gunes)) {
        yeniTema = "dawn";
      } else if (simdi.isAfter(gunes) && simdi.isBefore(ogle)) {
        yeniTema = "morning";
      } else if (simdi.isAfter(ogle) && simdi.isBefore(ikindi)) {
        yeniTema = "day";
      } else if (simdi.isAfter(ikindi) && simdi.isBefore(aksam)) {
        yeniTema = "afternoon";
      } else if (simdi.isAfter(aksam) && simdi.isBefore(yatsi)) {
        yeniTema = "sunset";
      } else {
        yeniTema = "night";
      }

      if (vaktinTemasi != yeniTema) {
        vaktinTemasi = yeniTema;
        notifyListeners();
      }
    } catch (_) {
      if (vaktinTemasi != "night") {
        vaktinTemasi = "night";
        notifyListeners();
      }
    }
  }

  Future<void> istatistikleriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('history_stats');
    Map<String, dynamic> history = historyJson != null
        ? json.decode(historyJson)
        : {};

    // 🔥 TÜM GEÇMİŞİ AYLIK TAKVİM İÇİN HARİTAYA AKTAR
    aylikGecmis.clear();

    // YENİ EKLENEN: GÜNLÜK DETAYLARI YÜKLE
    String? detailsJson = prefs.getString('history_details');
    gunlukDetaylar = detailsJson != null
        ? Map<String, dynamic>.from(json.decode(detailsJson))
        : {};

    history.forEach((key, value) {
      aylikGecmis[key] = (value as num).toInt();
    });

    List<FlSpot> tempSpots = [];
    List<String> tempLabels = [];
    // Sanal bugünü bulalım ki grafik ona göre bitsin
    final sanalBugunStr = getSanalGun();
    DateTime sanalBugun = DateFormat('yyyy-MM-dd').parse(sanalBugunStr);
    
    int pztUzaklik = sanalBugun.weekday - 1;
    DateTime buHaftaninPazartesisi = sanalBugun.subtract(Duration(days: pztUzaklik));

    for (int i = 0; i < 7; i++) {
      DateTime hedefGun = buHaftaninPazartesisi.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(hedefGun);
      
      int count;
      if (dateKey == sanalBugunStr) {
        // Eğer hedef gün "sanal bugün" ise ve kalıcı kaydı henüz oluşmadıysa, live datayı göster
        count = history[dateKey] ?? kildiMi.values.where((v) => v).length;
      } else {
        count = history[dateKey] ?? 0;
      }
      
      tempSpots.add(FlSpot(i.toDouble(), count.toDouble()));
      tempLabels.add(DateFormat('E', 'tr_TR').format(hedefGun));
    }
    grafikNoktalari = tempSpots;
    gunIsimleri = tempLabels;
    notifyListeners();
  }

  Future<void> verileriSifirla() async {
    final prefs = await SharedPreferences.getInstance();
    // Oturum ve tanıtım bilgileri korunur; "verileri sıfırla" hesaptan çıkış demek değil
    const korunanlar = ['onboarding_completed', 'firebase_username', 'firebase_handle', 'cinsiyet'];
    final korunan = {
      for (final k in korunanlar)
        if (prefs.containsKey(k)) k: prefs.get(k),
    };
    await prefs.clear();
    for (final e in korunan.entries) {
      final deger = e.value;
      if (deger is bool) await prefs.setBool(e.key, deger);
      if (deger is String) await prefs.setString(e.key, deger);
    }

    await _notificationService.cancelAll();
    await sifirlaKaza(); // 🔥 KAZA VERİLERİNİ DE SIFIRLA (SQLite)

    // Buluttaki XP/seri de sıfırlanmalı; yoksa bir sonraki birleştirmede geri gelir
    if (_currentUid != null) {
      await _firebaseService.updateUserStats(uid: _currentUid!, totalXp: 0, streak: 0);
    }
    _bulutBirlestirildi = false;
    await _uygulamayiBaslat();
  }

  /// Ana ekran widget'ına bugünün ve sonraki 2 günün vakitlerini yazar; sıradaki vakti widget kendisi hesaplar
  Future<void> _widgetGuncelle() async {
    if (vakitler == null) return;
    try {
      final bugun = DateTime.now();
      final gunler = <String, Map<String, String>>{};
      for (int g = 0; g < 3; g++) {
        final anahtar = _gunFormati.format(DateTime(bugun.year, bugun.month, bugun.day + g));
        final v = _vakitTakvimi[anahtar] ?? (g == 0 ? vakitler : null);
        if (v != null) gunler[anahtar] = v;
      }
      await HomeWidget.saveWidgetData<String>('widget_vakitler', json.encode(gunler));
      await HomeWidget.saveWidgetData<String>(
        'widget_alt_bilgi',
        '${kildiMi.values.where((x) => x).length}/5 bugün${streakCount > 0 ? ' • 🔥 $streakCount gün' : ''}',
      );
      await HomeWidget.saveWidgetData<String>('widget_kilinan', json.encode(kildiMi));
      await HomeWidget.saveWidgetData<String>('widget_kilinan_gun', _gunFormati.format(bugun));
      await HomeWidget.saveWidgetData<int>('widget_seri', streakCount);
      await HomeWidget.saveWidgetData<String>('widget_ayet_meal', gununAyetiMeali);
      await HomeWidget.saveWidgetData<String>('widget_ayet_ref', gununAyetiReferans);
      final bugunAnahtar = _gunFormati.format(bugun);
      final diniGunler = (tumDiniGunler.entries.where((e) => e.key.compareTo(bugunAnahtar) >= 0).toList()
            ..sort((a, b) => a.key.compareTo(b.key)))
          .take(6)
          .map((e) => '${e.key}|${e.value.turkishName}')
          .toList();
      await HomeWidget.saveWidgetData<String>('widget_dini_gunler', json.encode(diniGunler));
      for (final ad in const [
        'VakitWidgetProvider',
        'VakitlerWidgetProvider',
        'AyetWidgetProvider',
        'TakipWidgetProvider',
        'OrucWidgetProvider',
        'DiniGunWidgetProvider',
      ]) {
        await HomeWidget.updateWidget(androidName: ad);
      }
    } catch (e) {
      debugPrint('🧩 Widget güncelleme hatası: $e');
    }
  }

  Future<void>? _bildirimKuyrugu;

  /// Planlamalar sırayla çalışır; eşzamanlı iki planlama birbirinin cancelAll'ını bozmasın
  Future<void> _bildirimleriGuncelle() {
    unawaited(_widgetGuncelle());
    final yeni = (_bildirimKuyrugu ?? Future<void>.value()).then((_) => _bildirimleriPlanla());
    _bildirimKuyrugu = yeni;
    return yeni;
  }

  /// Önümüzdeki 7 günün vakit bildirimlerini ve vakit çıkmadan önceki hatırlatmaları kurar.
  /// iOS en fazla 64 bekleyen bildirim tuttuğu için: 35 vakit + ≤11 hatırlatma + 1 kaza + 14 manevi.
  Future<void> _bildirimleriPlanla() async {
    try {
      // 1. Tüm eski bildirimleri temizle
      await _notificationService.cancelAll();

      // 2. Eğer bildirimler kapalıysa çık
      if (!bildirimlerAcik) return;

      // Kaza hatırlatıcısı (her gün aynı saatte tekrarlar)
      if (kazaHatirlatmaAcik) {
        await _notificationService.scheduleKazaHatirlatma(
          hour: kazaHatirlatmaSaat,
          minute: kazaHatirlatmaDakika,
          sound: bildirimSesi,
          ozelSesYolu: ozelSesYolu,
        );
      }

      // Manevi Rehber bildirimleri (oruç modunda sahur/iftara yer açmak için azaltılır; iOS 64 sınırı)
      await _notificationService.scheduleManeviRehberNotifications(adet: orucModu ? 4 : 14);

      // Haftalık özet: bu pazar 20:00 (geçtiyse gelecek pazar). Metin son açılıştaki verilerle güncellenir.
      final ozet = haftalikOzet;
      final su = DateTime.now();
      var pazar = DateTime(su.year, su.month, su.day + (7 - su.weekday) % 7, 20);
      final yeniHafta = !pazar.isAfter(su);
      if (yeniHafta) pazar = pazar.add(const Duration(days: 7));
      await _notificationService.scheduleNotification(
        id: 800,
        title: '📊 Haftalık Özetin',
        body: yeniHafta
            ? 'Yeni haftaya başla! Bu hafta 35 vaktin hepsini kılmayı hedefle.'
            : 'Bu hafta ${ozet.namaz}/35 vakit kıldın, ${ozet.xp} XP kazandın'
                '${streakCount > 0 ? ' ve serin $streakCount gün' : ''}. Haftanı tamamla!',
        scheduledDate: pazar,
        sound: bildirimSesi,
        ozelSesYolu: ozelSesYolu,
      );

      // 3. Vakitler yüklenmemişse vakit bildirimlerini planlayamaz
      if (vakitler == null) return;

      final simdi = DateTime.now();
      final bugun = DateTime(simdi.year, simdi.month, simdi.day);
      DateTime gun(int g) => DateTime(bugun.year, bugun.month, bugun.day + g);
      Map<String, String>? gununVakitleri(int g) =>
          _vakitTakvimi[_gunFormati.format(gun(g))] ?? (g == 0 ? vakitler : null);

      // 🕌 Cuma: önümüzdeki Cuma, öğleden 1 saat önce (ID 810)
      for (int g = 0; g < _bildirimGunSayisi; g++) {
        final v = gununVakitleri(g);
        if (gun(g).weekday != DateTime.friday || v?['Öğle'] == null) continue;
        final zaman = _saatiTariheUygula(gun(g), v!['Öğle']!).subtract(const Duration(hours: 1));
        if (!zaman.isAfter(simdi)) continue;
        await _notificationService.scheduleNotification(
          id: 810,
          title: '🕌 Hayırlı Cumalar',
          body: 'Cuma namazına hazırlan. Kehf suresini okumayı ve bol salavat getirmeyi unutma.',
          scheduledDate: zaman,
          sound: bildirimSesi,
          ozelSesYolu: ozelSesYolu,
        );
        break;
      }

      // 🌙 Oruç modu: 5 gün sahur (imsaktan 45 dk önce) ve iftar (ID 600+)
      if (orucModu) {
        for (int g = 0; g < 5; g++) {
          final o = orucVakitleri(gun(g));
          if (o == null) continue;
          final sahur = o.imsak.subtract(const Duration(minutes: 45));
          if (sahur.isAfter(simdi)) {
            await _notificationService.scheduleNotification(
              id: 600 + g * 2,
              title: '🌙 Sahur vakti',
              body: 'İmsaka 45 dakika kaldı (${DateFormat('HH:mm').format(o.imsak)}). Niyet etmeyi unutma.',
              scheduledDate: sahur,
              sound: bildirimSesi,
              ozelSesYolu: ozelSesYolu,
            );
          }
          if (o.iftar.isAfter(simdi)) {
            await _notificationService.scheduleNotification(
              id: 601 + g * 2,
              title: '🍽️ İftar vakti',
              body: 'Allah orucunu kabul etsin. Orucunu uygulamada işaretlemeyi unutma.',
              scheduledDate: o.iftar,
              sound: bildirimSesi,
              ozelSesYolu: ozelSesYolu,
            );
          }
        }
      }

      // Vakit girdi bildirimleri (ID: gün*10 + vakit)
      for (int g = 0; g < _bildirimGunSayisi; g++) {
        final v = gununVakitleri(g);
        if (v == null) continue;
        for (int i = 0; i < vakitIsimleri.length; i++) {
          final vakitAdi = vakitIsimleri[i];
          final saat = v[vakitAdi];
          if (saat == null) continue;
          final zaman = _saatiTariheUygula(gun(g), saat);
          if (!zaman.isAfter(simdi)) continue;
          await _notificationService.scheduleNotification(
            id: g * 10 + i,
            title: 'Namaz Vakti: $vakitAdi',
            body: '$vakitAdi vakti girdi. Namazını kıl ve vakit çıkmadan uygulamadan işaretle.',
            scheduledDate: zaman,
            sound: bildirimSesi,
            ozelSesYolu: ozelSesYolu,
          );
        }
      }

      // Hatırlatma: vakit çıkmadan 20 dk önce, kılınmadıysa (dün, bugün, yarın; ID: 100+)
      // Sabah → Güneş, Öğle → İkindi, İkindi → Akşam, Akşam → Yatsı, Yatsı → ertesi Sabah
      final sanalGun = getSanalGun();
      for (int g = -1; g <= 1; g++) {
        final v = gununVakitleri(g);
        final ertesi = gununVakitleri(g + 1);
        final tarihStr = _gunFormati.format(gun(g));
        for (int i = 0; i < vakitIsimleri.length; i++) {
          final vakitAdi = vakitIsimleri[i];
          final bitisSaati = switch (vakitAdi) {
            'Sabah' => v?['Güneş'],
            'Öğle' => v?['İkindi'],
            'İkindi' => v?['Akşam'],
            'Akşam' => v?['Yatsı'],
            _ => ertesi?['Sabah'],
          };
          if (bitisSaati == null) continue;
          final bitis = _saatiTariheUygula(vakitAdi == 'Yatsı' ? gun(g + 1) : gun(g), bitisSaati);
          var hatirlatma = bitis.subtract(const Duration(minutes: 20));
          if (vakitAdi == 'Yatsı' && v?['Yatsı'] != null) {
            // Sabaha 20 dk kala kullanıcıyı uyandırmasın: en geç 23:00, ama vakit girdikten en az 30 dk sonra
            final yatsiGirisi = _saatiTariheUygula(gun(g), v!['Yatsı']!);
            final gece = DateTime(gun(g).year, gun(g).month, gun(g).day, 23);
            final enErken = yatsiGirisi.add(const Duration(minutes: 30));
            final hedef = gece.isAfter(enErken) ? gece : enErken;
            if (hedef.isBefore(hatirlatma)) hatirlatma = hedef;
          }
          if (!hatirlatma.isAfter(simdi)) continue;
          if (tarihStr == sanalGun && (kildiMi[vakitAdi] ?? false)) continue;

          // Bugünün diğer vakitleri tamsa: bu vakit kaçarsa seri bozulur
          final seriTehlikede = tarihStr == sanalGun &&
              streakCount > 0 &&
              vakitIsimleri.where((x) => x != vakitAdi).every((x) => kildiMi[x] ?? false);
          await _notificationService.scheduleNotification(
            id: 100 + (g + 1) * 10 + i,
            title: seriTehlikede ? '🔥 $streakCount günlük serin bozulmak üzere' : '⏳ $vakitAdi vakti çıkıyor',
            body: seriTehlikede
                ? 'Bugün sadece $vakitAdi kaldı. Kıldıysan şimdi işaretle; vakit çıkınca işaretlenemez.'
                : '$vakitAdi vaktinin çıkmasına 20 dakika kaldı. Kıldıysan şimdi işaretle; vakit çıkınca işaretlenemez.',
            scheduledDate: hatirlatma,
            sound: bildirimSesi,
            ozelSesYolu: ozelSesYolu,
          );
        }
      }
    } catch (e) {
      debugPrint("🔔 Bildirim planlama hatası: $e");
    }
  }

  Future<void> _gununAyetiniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sonSecilenGun = prefs.getString('son_ayet_gunu') ?? "";

    if (bugun == sonSecilenGun && prefs.containsKey('son_ayet_sure_no')) {
      gununAyetiMeali = prefs.getString('son_ayet_meal') ?? "";
      gununAyetiReferans = prefs.getString('son_ayet_ref') ?? "";
      gununAyetiSureNo = prefs.getInt('son_ayet_sure_no') ?? 1;
      gununAyetiNo = prefs.getInt('son_ayet_no') ?? 1;
      
      if (gununAyetiMeali.isNotEmpty) {
        notifyListeners();
        return;
      }
    }

    try {
      final random = Random();
      // Rastgele sure (1-114)
      final sureNo = random.nextInt(114) + 1;
      // O surenin ayet sayısı
      final ayetSayisi = quran.getVerseCount(sureNo);
      // Rastgele ayet (1-ayetSayisi)
      final ayetNo = random.nextInt(ayetSayisi) + 1;

      gununAyetiMeali = quran.getVerseTranslation(
        sureNo,
        ayetNo,
        translation: quran.Translation.trSaheeh,
      );
      
      final sureIsmi = quran.getSurahNameTurkish(sureNo);
      gununAyetiReferans = "$sureIsmi Suresi, $ayetNo. Ayet";
      gununAyetiSureNo = sureNo;
      gununAyetiNo = ayetNo;

      await prefs.setString('son_ayet_gunu', bugun);
      await prefs.setString('son_ayet_meal', gununAyetiMeali);
      await prefs.setString('son_ayet_ref', gununAyetiReferans);
      await prefs.setInt('son_ayet_sure_no', sureNo);
      await prefs.setInt('son_ayet_no', ayetNo);
    } catch (e) {
      // Hata durumunda varsayılan ayet
      gununAyetiMeali = "Şüphesiz güçlükle beraber bir kolaylık vardır.";
      gununAyetiReferans = "İnşirah Suresi, 5. Ayet";
      gununAyetiSureNo = 94;
      gununAyetiNo = 5;
    }
    notifyListeners();
  }



  // --- ZİKİRMATİK METOTLARI ---
  Future<void> zikirArtir() async {
    // Sayaç await'ten önce artırılır: hızlı dokunuşlarda eski değer okunup hedef kaçmasın
    _zikirSayaci++;
    final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _zikirGecmisi[bugun] = (_zikirGecmisi[bugun] ?? 0) + 1;
    // Her 10 zikirde +1 XP
    final xpKazanildi = _zikirSayaci % 10 == 0;
    if (xpKazanildi) _zikirXpKazanilan += 1;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('zikirSayaci', _zikirSayaci);
    await prefs.setString('zikirGecmisi', json.encode(_zikirGecmisi));
    if (xpKazanildi) {
      await prefs.setInt('zikirXpKazanilan', _zikirXpKazanilan);
      await _xpGuncelle(1);
    }
  }

  /// Tesbihattan gelen zikir: geçmişe ve XP'ye işler, zikirmatikteki sayaca dokunmaz
  int _tesbihatSayaci = 0;
  Future<void> tesbihatZikri() async {
    final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _zikirGecmisi[bugun] = (_zikirGecmisi[bugun] ?? 0) + 1;
    _tesbihatSayaci++;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('zikirGecmisi', json.encode(_zikirGecmisi));
    if (_tesbihatSayaci % 10 == 0) await _xpGuncelle(1); // Zikirmatikle aynı oran
  }

  Future<void> zikirHedefBelirle(int hedef) async {
    final prefs = await SharedPreferences.getInstance();
    _zikirHedefi = hedef;
    await prefs.setInt('zikirHedefi', _zikirHedefi);
    notifyListeners();
  }

  Future<void> zikirSifirla() async {
    final prefs = await SharedPreferences.getInstance();
    _zikirSayaci = 0;
    _zikirXpKazanilan = 0;
    await prefs.setInt('zikirSayaci', _zikirSayaci);
    await prefs.setInt('zikirXpKazanilan', _zikirXpKazanilan);
    notifyListeners();
  }
  
  /// Bugünden sonraki ilk dini gün ve kalan gün sayısı
  ({ReligiousDay gun, int kalan})? get siradakiDiniGun {
    final bugun = _gunFormati.format(DateTime.now());
    final sirali = tumDiniGunler.keys.where((k) => k.compareTo(bugun) > 0).toList()..sort();
    if (sirali.isEmpty) return null;
    return (gun: tumDiniGunler[sirali.first]!, kalan: _gunFarki(bugun, sirali.first));
  }

  // ══════════════════════════════════════════
  // 🌙 ORUÇ TAKİBİ
  // ══════════════════════════════════════════

  static const int orucXp = 30;
  bool orucModu = false; // Açıkken sahur ve iftar bildirimleri kurulur
  Set<String> orucGunleri = {}; // Tutulan oruçlar ("yyyy-MM-dd")
  int kazaOrucBorcu = 0;
  int kilinanKazaOrucu = 0;

  bool get bugunOrucTutuldu => orucGunleri.contains(_gunFormati.format(DateTime.now()));

  /// İmsak (sahur sonu) = Sabah vakti, iftar = Akşam vakti. Yarınki imsak takvimden alınır.
  ({DateTime imsak, DateTime iftar})? orucVakitleri(DateTime gun) {
    final v = _vakitTakvimi[_gunFormati.format(gun)] ??
        (_gunFormati.format(gun) == _gunFormati.format(DateTime.now()) ? vakitler : null);
    if (v == null || v['Sabah'] == null || v['Akşam'] == null) return null;
    return (imsak: _saatiTariheUygula(gun, v['Sabah']!), iftar: _saatiTariheUygula(gun, v['Akşam']!));
  }

  Future<void> _orucKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('oruc_modu', orucModu);
    await prefs.setStringList('oruc_gunleri', orucGunleri.toList());
    await prefs.setInt('kaza_oruc_borcu', kazaOrucBorcu);
    await prefs.setInt('kilinan_kaza_orucu', kilinanKazaOrucu);
  }

  Future<void> orucModuDegistir(bool acik) async {
    orucModu = acik;
    await _orucKaydet();
    await _bildirimleriGuncelle();
    notifyListeners();
  }

  Future<void> bugunOrucDegistir(bool tuttu) async {
    final bugun = _gunFormati.format(DateTime.now());
    if (tuttu == orucGunleri.contains(bugun)) return;
    tuttu ? orucGunleri.add(bugun) : orucGunleri.remove(bugun);
    await _xpGuncelle(tuttu ? orucXp : -orucXp);
    await _orucKaydet();
    notifyListeners();
  }

  Future<void> kazaOrucBorcuAyarla(int borc) async {
    kazaOrucBorcu = max(0, borc);
    await _orucKaydet();
    notifyListeners();
  }

  /// Bir kaza orucu tutuldu: borçtan düşer, bugünü de tutulmuş sayar
  Future<void> kazaOrucuTuttum() async {
    if (kazaOrucBorcu <= 0) return;
    kazaOrucBorcu--;
    kilinanKazaOrucu++;
    await _orucKaydet();
    await bugunOrucDegistir(true);
  }

  // --- DİNİ GÜNLER (ALADHAN API) ---
  Future<void> seciliAyDiniGunleriGetir(int year, int month) async {
    String cacheKey = "$year-$month";
    if (_aylikDiniGunlerCache.contains(cacheKey)) return;

    isDiniGunlerLoading = true;
    notifyListeners();

    try {
      // Hicri tarih Türkiye genelinde aynıdır; konum yoksa Ankara kullanılır
      final pos = await _vakitKonumu() ?? _konumOlustur(39.9334, 32.8597);
      final List<ReligiousDay> liste =
          await _namazServisi.diniGunleriGetir(year, month, position: pos);

      for (var d in liste) {
        tumDiniGunler[d.dateStr] = d;
      }
      _aylikDiniGunlerCache.add(cacheKey);
    } catch (_) {}

    isDiniGunlerLoading = false;
    notifyListeners();
  }
  // ════════════════════════════════════════
  // 📸 HİKAYE (STORY) İŞLEMLERİ
  // ════════════════════════════════════════

  /// Haftalık özeti story olarak paylaşır
  Future<void> paylasHaftalikStory(Uint8List imageBytes) async {
    if (currentUid == null) return;

    try {
      // Future sürümünü kullanarak profil verisini al
      final user = await _firebaseService.getUserProfileFuture(currentUid!);
      if (user == null) return;

      final base64Image = base64Encode(imageBytes);
      
      await _firebaseService.uploadStory(
        uid: currentUid!,
        username: user.username,
        displayName: user.displayName,
        photoUrl: user.photoUrl,
        base64Image: base64Image,
      );
      
      debugPrint('📸 Hikaye paylaşıldı');
    } catch (e) {
      debugPrint('📸 Hikaye paylaşma hatası: $e');
      rethrow;
    }
  }

  /// Arkadaşların hikayelerini dinler
  Stream<List<UserStory>> arkadasHikayeleriniDinle() {
    if (currentUid == null) return Stream.value([]);
    
    // Arkadaş listesini al ve hikayeleri getir
    // getUserProfile bir Stream döner
    return _firebaseService.getUserProfile(currentUid!).asyncExpand((user) {
      if (user == null || user.friends.isEmpty) return Stream.value([]);
      return _firebaseService.getFriendStories(user.friends);
    });
  }

  /// Belirli bir kullanıcının hikayesini getirir
  Future<UserStory?> hikayeGetir(String uid) => _firebaseService.getUserStory(uid);
}
