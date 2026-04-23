import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/namaz_servis.dart';
import '../services/seviye_servisi.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';
import 'package:quran/quran.dart' as quran;
import 'dart:math';
import '../models/religious_day.dart';
import '../models/prayer_post.dart';
import '../models/story.dart';
import '../services/local_db_service.dart';
import 'dart:typed_data';

class NamazProvider extends ChangeNotifier {
  final NamazServisi _namazServisi;
  final NotificationService _notificationService;
  final FirebaseService _firebaseService;
  final LocalDbService _localDbService = LocalDbService();

  // --- FIREBASE / AUTH DURUMLARI ---
  bool _needsProfile = false;
  bool get needsProfile => _needsProfile;
  String? _currentUid;
  String? get currentUid => _currentUid;
  String _currentUsername = '';
  String get currentUsername => _currentUsername;
  String _currentHandle = '';
  String get currentHandle => _currentHandle;

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

  int streakCount = 0;
  int toplamTamamlanan = 0;
  String gununAyetiMeali = "";
  String gununAyetiReferans = "";

  // 🔥 SEVİYE SİSTEMİ DEĞİŞKENLERİ
  int _toplamXp = 0;
  int get toplamXp => _toplamXp;
  String get mevcutUnvan => SeviyeServisi.unvanGetir(_toplamXp);
  double get seviyeIlerleme => SeviyeServisi.ilerlemeHesapla(_toplamXp);

  String sonSifirlamaTarihi = "";
  String _sonKontrolEdilenGun = ""; // 00:00 kontrolü için

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
  Map<String, dynamic> gunlukDetaylar = {}; // Hangi gün hangi vakit kılındı detayını tutar
  
  // 🔥 DİNİ GÜNLER API STATE
  Map<String, ReligiousDay> tumDiniGunler = {}; // Format: "yyyy-MM-dd"
  Set<String> _aylikDiniGunlerCache = {};
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

  @override
  void dispose() {
    _timer?.cancel();
    kalanSureNotifier.dispose();
    guncelSaatNotifier.dispose();
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
      isLoading = false;
      _ilkVakitHesapla();
      _sayaciBaslat();
      _bildirimleriGuncelle();
      notifyListeners();
    }

    await konumVeApiIstegi(kullaniciTetikledi: false);
    
    // Açılışta bu ayın dini günlerini getir
    final simdi = DateTime.now();
    await seciliAyDiniGunleriGetir(simdi.year, simdi.month);
    // Eğer bugün ayın son günüyse, yarın için uyarı göstermek adına sonraki ayı da çek
    final yarin = simdi.add(const Duration(days: 1));
    if (simdi.month != yarin.month) {
      await seciliAyDiniGunleriGetir(yarin.year, yarin.month);
    }
  }

  /// Firebase auth kontrolü — giriş yapmış mı kontrol et
  Future<void> _firebaseAuthKontrol() async {
    try {
      final user = _firebaseService.currentUser;
      if (user != null) {
        _currentUid = user.uid;
        final hasProfile = await _firebaseService.hasUserProfile(user.uid);
        if (hasProfile) {
          _needsProfile = false;
          final prefs = await SharedPreferences.getInstance();
          _currentUsername = prefs.getString('firebase_username') ?? user.displayName ?? '';
          _currentHandle = prefs.getString('firebase_handle') ?? '';
          
          // Eğer handle yoksa Firestore'dan çek (Geriye dönük uyumluluk)
          if (_currentHandle.isEmpty) {
            final doc = await _firebaseService.getUserProfile(user.uid).first;
            if (doc != null) {
              _currentHandle = doc.username;
              await prefs.setString('firebase_handle', _currentHandle);
            }
          }
          
          _firebaseCloudSync();
          _firebaseService.initMessaging(user.uid);
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
    }
    notifyListeners();
  }

  /// Email/Şifre ile kayıt ol
  Future<String?> emailIleKayitOl({
    required String email,
    required String password,
    required String displayName,
    required String username,
  }) async {
    // 1. Kullanıcı adının müsaitliğini kontrol et
    final isAvailable = await _firebaseService.isUsernameAvailable(username);
    if (!isAvailable) return 'Bu kullanıcı adı daha önce alınmış.';

    final result = await _firebaseService.registerWithEmail(
      email: email,
      password: password,
    );

    if (result.error != null) return result.error;
    if (result.user == null) return 'Hesap oluşturulamadı.';

    _currentUid = result.user!.uid;
    final prefs = await SharedPreferences.getInstance();

    await _firebaseService.createUserProfile(
      uid: _currentUid!,
      username: username,
      displayName: displayName,
      initialXp: _toplamXp,
      initialStreak: streakCount,
    );

    _currentUsername = displayName;
    _currentHandle = username;
    _needsProfile = false;
    await prefs.setString('firebase_username', displayName);
    await prefs.setString('firebase_handle', username);
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
    if (hasProfile) {
      _needsProfile = false;
      _currentUsername = prefs.getString('firebase_username') ?? result.user!.displayName ?? '';
      _currentHandle = prefs.getString('firebase_handle') ?? '';
      
      if (_currentHandle.isEmpty) {
        final doc = await _firebaseService.getUserProfile(_currentUid!).first;
        if (doc != null) {
          _currentHandle = doc.username;
          await prefs.setString('firebase_handle', _currentHandle);
        }
      }
      _firebaseCloudSync();
    } else {
      // Email ile giriş yaptı ama profili yoksa (olağandışı durum) oluştur
      final displayName = result.user!.displayName ?? email.split('@')[0];
      final baseUsername = displayName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
      
      await _firebaseService.createUserProfile(
        uid: _currentUid!,
        username: baseUsername.isEmpty ? 'user_${_currentUid!.substring(0,5)}' : baseUsername,
        displayName: displayName,
        initialXp: _toplamXp,
        initialStreak: streakCount,
      );
      _currentUsername = displayName;
      _currentHandle = baseUsername.isEmpty ? 'user_${_currentUid!.substring(0,5)}' : baseUsername;
      _needsProfile = false;
      await prefs.setString('firebase_username', displayName);
      await prefs.setString('firebase_handle', _currentHandle);
    }

    _firebaseService.initMessaging(_currentUid!);
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
      if (hasProfile) {
        _needsProfile = false;
        _currentUsername = prefs.getString('firebase_username') ?? user.displayName ?? '';
        _currentHandle = prefs.getString('firebase_handle') ?? '';
        if (_currentHandle.isEmpty) {
          final doc = await _firebaseService.getUserProfile(user.uid).first;
          if (doc != null) {
            _currentHandle = doc.username;
            await prefs.setString('firebase_handle', _currentHandle);
          }
        }
        _firebaseCloudSync();
      } else {
        final googleName = user.displayName ?? 'Google Kullanıcı';
        String base = googleName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '');
        if (base.isEmpty) base = 'kullanici';

        final isAvailable = await _firebaseService.isUsernameAvailable(base);
        
        if (isAvailable) {
          await _firebaseService.createUserProfile(
            uid: user.uid,
            username: base,
            displayName: googleName,
            initialXp: _toplamXp,
            initialStreak: streakCount,
          );
          _currentUsername = googleName;
          _currentHandle = base;
          _needsProfile = false;
          await prefs.setString('firebase_username', googleName);
          await prefs.setString('firebase_handle', base);
        } else {
          // İsim doluysa UI'a sinyal gönder (UI modal açacak ve completeGoogleRegistration çağıracak)
          return 'google_username_taken';
        }
      }

      _firebaseService.initMessaging(user.uid);
      notifyListeners();
      return null; // Hata yok
    } catch (e) {
      debugPrint('🔐 Google giriş hatası (Provider): $e');
      return 'Google ile giriş yapılamadı.';
    }
  }

  /// Google kaydını username seçimi ile tamamlar (Çakışma varsa UI'dan çağrılır)
  Future<String?> completeGoogleRegistration({required String username, required String displayName}) async {
    if (_currentUid == null) return 'Oturum bulunamadı.';
    
    final isAvailable = await _firebaseService.isUsernameAvailable(username);
    if (!isAvailable) return 'Bu kullanıcı adı daha önce alınmış.';

    final prefs = await SharedPreferences.getInstance();
    
    await _firebaseService.createUserProfile(
      uid: _currentUid!,
      username: username,
      displayName: displayName,
      initialXp: _toplamXp,
      initialStreak: streakCount,
    );
    
    _currentUsername = displayName;
    _needsProfile = false;
    await prefs.setString('firebase_username', displayName);
    _firebaseService.initMessaging(_currentUid!);
    notifyListeners();
    
    return null;
  }

  /// Hesaptan çıkış yapar
  Future<void> cikisYap() async {
    await _firebaseService.signOut();
    _currentUid = null;
    _needsProfile = true;
    _currentUsername = '';
    _currentHandle = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('firebase_username');
    await prefs.remove('firebase_handle');
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
    _firebaseService.updateUserStats(
      uid: _currentUid!,
      totalXp: _toplamXp,
      streak: streakCount,
    );
  }

  /// Sosyal akış önbelleğini günceller
  Future<void> updatePrayerCache(List<PrayerPost> prayers) async {
    _cachedPrayers = prayers.take(20).toList();
    await _localDbService.cachePrayers(prayers);
  }

  Future<void> konumVeApiIstegi({bool kullaniciTetikledi = false}) async {
    if (vakitler == null) {
      isLoading = true;
      notifyListeners();
    }

    try {
      Position? position = await _namazServisi.konumGetir(
        izinIste: kullaniciTetikledi,
      );

      if (position == null) {
        if (seciliSehir.isNotEmpty) {
          await sehirVakitleriniGetir(seciliSehir);
          return;
        }

        konumBilgisi = "Konum İzni Gerekli";
        hataMesaji = "Konum izni verilmediği için vakitler belirlenemedi.";
        isLoading = false;
        notifyListeners();
        return;
      }

      final veriler = await _namazServisi.vakitleriGetir(position);
      final prefs = await SharedPreferences.getInstance();
      vakitler = veriler;
      seciliSehir = ""; // GPS ile alındığı için şehri geçersiz kıl
      await prefs.setString('cached_vakitler', json.encode(vakitler));
      await prefs.remove('secili_sehir');

      //bool bildirimAcik = prefs.getBool('bildirimler_acik') ?? true;

      _adresGuncelle(position);
      _sabahVaktiSifirlamaKontrolu();
      _ilkVakitHesapla();
      _sayaciBaslat();
      await _bildirimleriGuncelle();

      hataMesaji = "";
      isLoading = false;
      notifyListeners();
    } catch (e) {
      String errStr = e.toString();
      if (seciliSehir.isNotEmpty) {
        await sehirVakitleriniGetir(seciliSehir);
      } else if (vakitler == null) {
        _varsayilanKonumKullan(errStr);
      } else {
        isLoading = false;
        if (kullaniciTetikledi) {
          if (errStr.toLowerCase().contains("konum")) {
            hataMesaji = "Konum servisi ulaşılamadığı için çevrimdışı veriler kullanılıyor.\nDetay: $errStr";
          } else {
            hataMesaji = "Bir bağlantı hatası oluştu.\nDetay: $errStr";
          }
        }
        notifyListeners();
      }
    }
  }

  Future<void> sehirVakitleriniGetir(String sehir) async {
    isLoading = true;
    hataMesaji = "";
    notifyListeners();

    try {
      final veriler = await _namazServisi.vakitleriGetirSehirle(sehir);
      final prefs = await SharedPreferences.getInstance();

      vakitler = veriler;
      seciliSehir = sehir;
      konumBilgisi = "TÜRKİYE, ${sehir.toUpperCase()}";

      await prefs.setString('cached_vakitler', json.encode(vakitler));
      await prefs.setString('secili_sehir', sehir);
      await prefs.setString('cached_location', konumBilgisi);

      //bool bildirimAcik = prefs.getBool('bildirimler_acik') ?? true;

      _sabahVaktiSifirlamaKontrolu();
      _ilkVakitHesapla();
      _sayaciBaslat();
      await _bildirimleriGuncelle();

      isLoading = false;
      notifyListeners();
    } catch (e) {
      isLoading = false;
      hataMesaji =
          "Şehir verileri alınamadı. Lütfen bağlantınızı kontrol edin.\nDetay: ${e.toString()}";
      if (vakitler == null) {
        konumBilgisi = "Şehir Seçilmeli";
      }
      notifyListeners();
    }
  }

  Future<void> _varsayilanKonumKullan(String hata) async {
    Position fallbackPos = Position(
      latitude: 38.6748,
      longitude: 39.2225,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      heading: 0,
      speed: 0,
      speedAccuracy: 0,
      altitudeAccuracy: 0,
      headingAccuracy: 0,
    );
    try {
      final veriler = await _namazServisi.vakitleriGetir(fallbackPos);
      vakitler = veriler;
      konumBilgisi = "Varsayılan: ELAZIĞ";
      _ilkVakitHesapla();
      _sayaciBaslat();
      isLoading = false;
      hataMesaji = "";
    } catch (e) {
      isLoading = false;
      hataMesaji =
          "İnternet bağlantısı yok. Uygulamayı kullanmak için internete bağlanın.";
    }
    notifyListeners();
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
            "${p[0].country?.toUpperCase()}, ${p[0].administrativeArea?.toUpperCase()}";
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

    sonSifirlamaTarihi = prefs.getString('lastResetDate') ?? "";
    konumBilgisi = prefs.getString('cached_location') ?? "Yükleniyor...";
    seciliSehir = prefs.getString('secili_sehir') ?? "";

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

    // 🔥 SOSYAL AKIŞ ÖNBELLEĞİNİ YÜKLE
    _cachedPrayers = await _localDbService.getCachedPrayers();
    notifyListeners();
  }

  Future<void> kazaGuncelle(String vakit, int miktar) async {
    final prefs = await SharedPreferences.getInstance();
    int yeniMiktar = (kazaNamazlari[vakit] ?? 0) + miktar;
    if (yeniMiktar < 0) yeniMiktar = 0;
    kazaNamazlari[vakit] = yeniMiktar;
    await prefs.setInt('kaza_$vakit', yeniMiktar);
    notifyListeners();
  }

  Future<void> vaktiKildimIsaretle(String vakitIsmi, bool yeniDurum) async {
    // 🔥 XP SUİSTİMALİNİ ÖNLEME: Zaten aynı durumdaysa işlem yapma
    if (kildiMi[vakitIsmi] == yeniDurum) return;

    // 🔥 DURUMU HEMEN GÜNCELLE (Race condition önlemek için await öncesinde)
    kildiMi[vakitIsmi] = yeniDurum;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kildi_$vakitIsmi', yeniDurum);

    if (yeniDurum) {
      streakCount++;
      toplamTamamlanan++;
      
      _toplamXp += SeviyeServisi.namazXp;
      int kilinanSayisi = kildiMi.values.where((v) => v == true).length;
      if (kilinanSayisi == 5) {
        _toplamXp += SeviyeServisi.tamGunBonusu;
      }
      await prefs.setInt('toplam_xp', _toplamXp);
      
    } else {
      if (streakCount > 0) streakCount--;
      if (toplamTamamlanan > 0) toplamTamamlanan--;

      // Kaç adet işaretli kaldığına bak (Eğer 4 kaldıysa, demek ki az önce 5'ti ve bonus alınmıştı)
      int kilinanSayisi = kildiMi.values.where((v) => v == true).length;
      int geriAlinacakXp = SeviyeServisi.namazXp;
      
      // Eğer az önce 5'i bozup 4'e düşürdüyse haksız kazancı engellemek için Bonus'u da geri al
      if (kilinanSayisi == 4) {
        geriAlinacakXp += SeviyeServisi.tamGunBonusu;
      }

      if (_toplamXp >= geriAlinacakXp) {
        _toplamXp -= geriAlinacakXp;
      } else {
        _toplamXp = 0;
      }
      await prefs.setInt('toplam_xp', _toplamXp);
    }
    
    await prefs.setInt('streakCount', streakCount);
    await prefs.setInt('toplamKilinan', toplamTamamlanan);

    // 🔥 FIREBASE CLOUD SYNC (fire-and-forget)
    _firebaseCloudSync();

    await istatistikleriYukle();
    notifyListeners();
  }

  Future<void> _kutucuklariSifirla(String sanalBugunStr) async {
    final prefs = await SharedPreferences.getInstance();
    
    // --- YENİ: SIFIRLAMADAN ÖNCE BİTEN GÜNÜN VERİLERİNİ KAYDET ---
    if (sonSifirlamaTarihi.isNotEmpty) {
      // İstatistik özetini kaydet
      String? historyJson = prefs.getString('history_stats');
      Map<String, dynamic> history = historyJson != null ? json.decode(historyJson) : {};
      history[sonSifirlamaTarihi] = kildiMi.values.where((v) => v).length;
      await prefs.setString('history_stats', json.encode(history));

      // Detaylı kayıt
      String? detailsJson = prefs.getString('history_details');
      Map<String, dynamic> details = detailsJson != null ? json.decode(detailsJson) : {};
      details[sonSifirlamaTarihi] = Map<String, bool>.from(kildiMi);
      await prefs.setString('history_details', json.encode(details));
    }

    kildiMi.updateAll((key, value) => false);
    sonSifirlamaTarihi = sanalBugunStr;
    for (var vkt in vakitIsimleri) {
      await prefs.setBool('kildi_$vkt', false);
    }
    await prefs.setString('lastResetDate', sanalBugunStr);
    
    await istatistikleriYukle();
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

  void _sabahVaktiSifirlamaKontrolu() {
    if (vakitler == null) return;
    final sanalBugunStr = getSanalGun();
    if (sonSifirlamaTarihi != sanalBugunStr) {
      bool dunuTamamladiMi = kildiMi.values.every((v) => v == true);
      if (!dunuTamamladiMi && streakCount > 0) _streakSifirla();
      _kutucuklariSifirla(sanalBugunStr);
    }
  }

  bool _gunIcindeKacirilanVarMi(String hedefVakit) {
    if (vakitler == null) return false;
    // Sabah'tan önceysek (gece yarısı ile sabah arası) kontrol edilecek bir şey yok
    if (hedefVakit == "Sabah") return false;

    int hedefIndex = vakitIsimleri.indexOf(hedefVakit);
    if (hedefIndex == -1) return false;

    // Hedef vakte kadar olan önceki vakitleri kontrol et
    for (int i = 0; i < hedefIndex; i++) {
      String kontrolVakti = vakitIsimleri[i];
      if (!(kildiMi[kontrolVakti] ?? false)) {
        return true;
      }
    }
    return false;
  }

  void _streakSifirla() async {
    final prefs = await SharedPreferences.getInstance();
    streakCount = 0;
    await prefs.setInt('streakCount', 0);
    notifyListeners();
  }

  void _ilkVakitHesapla() {
    if (vakitler == null) return;
    final simdi = DateTime.now();
    String bulunan = "Yatsı";
    final sabahVakti = _parseTime(vakitler!['Sabah']!);
    if (simdi.isBefore(sabahVakti)) {
      bulunan = "Yatsı";
    } else {
      for (var i = 0; i < vakitIsimleri.length; i++) {
        if (simdi.isBefore(_parseTime(vakitler![vakitIsimleri[i]]!))) {
          bulunan = i == 0 ? "Yatsı" : vakitIsimleri[i - 1];
          break;
        }
      }
    }
    aktifVakit = bulunan;
    
    // NOT: _gunIcindeKacirilanVarMi kontrolü buradan kaldırıldı. 
    // Seri (streak) artık yalnızca vakit geçişlerinde veya gün başında bozulacak.
    
    notifyListeners();
  }

  DateTime _parseTime(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    return DateTime(
      now.year,
      now.month,
      now.day,
      int.parse(parts[0]),
      int.parse(parts[1].split(" ")[0]),
    );
  }

  void _sayaciBaslat() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (vakitler == null) return;
      final simdi = DateTime.now();
      final bugunStr = DateFormat('yyyy-MM-dd').format(simdi);

      // --- 00:00 GÜN DEĞİŞİM KONTROLÜ (Günün Ayeti İçin) ---
      if (_sonKontrolEdilenGun != bugunStr) {
        _sonKontrolEdilenGun = bugunStr;
        _gununAyetiniYukle(); // Ayeti yenile
      }

      var sabahVakti = _parseTime(vakitler!["Sabah"]!);
      String bulunanVakit = "Yatsı";
      DateTime? bitisZamani;

      if (simdi.isBefore(sabahVakti)) {
        bulunanVakit = "Yatsı";
        bitisZamani = sabahVakti;
      } else {
        for (var i = 0; i < vakitIsimleri.length; i++) {
          var vktDT = _parseTime(vakitler![vakitIsimleri[i]]!);
          if (simdi.isBefore(vktDT)) {
            bulunanVakit = i == 0 ? "Yatsı" : vakitIsimleri[i - 1];
            bitisZamani = vktDT;
            break;
          }
        }
      }
      bitisZamani ??= sabahVakti.add(const Duration(days: 1));

      if (aktifVakit != bulunanVakit) {
        // Vakit değiştiğinde, önceki vakit (aktifVakit) kılınmamışsa streak bozulsun
        if (!(kildiMi[aktifVakit] ?? false)) {
          _streakSifirla();
        }

        final sanalBugunStr = getSanalGun();
        if (bulunanVakit == "Sabah" && sonSifirlamaTarihi != sanalBugunStr) {
          _kutucuklariSifirla(sanalBugunStr);
        }
        aktifVakit = bulunanVakit;
      }

      final fark = bitisZamani.difference(simdi);
      kalanSureNotifier.value =
          "${fark.inHours.toString().padLeft(2, '0')}:${(fark.inMinutes % 60).toString().padLeft(2, '0')}:${(fark.inSeconds % 60).toString().padLeft(2, '0')}";
      guncelSaatNotifier.value = DateFormat("HH:mm").format(simdi);
      ekranTarihi = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(simdi);

      _temaGuncelle();
      notifyListeners();
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
    if (detailsJson != null) {
      gunlukDetaylar = Map<String, dynamic>.from(json.decode(detailsJson));
    }

    history.forEach((key, value) {
      aylikGecmis[key] = (value as num).toInt();
    });

    List<FlSpot> tempSpots = [];
    List<String> tempLabels = [];
    DateTime bugun = DateTime.now();
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
    await prefs.clear();
    await _notificationService.cancelAll();
    await _uygulamayiBaslat();
  }

  Future<void> _bildirimleriGuncelle() async {
    // 1. Tüm eski bildirimleri temizle
    await _notificationService.cancelAll();
    
    // 2. Eğer bildirimler kapalıysa çık
    if (!bildirimlerAcik) return;

    // Manevi Rehber bildirimlerini planla (her 5 saatte bir)
    await _notificationService.scheduleManeviRehberNotifications();

    // 3. Vakitler yüklenmemişse vakit bildirimlerini planlayamaz
    if (vakitler == null) return;

    final simdi = DateTime.now();
    final bugunStr = DateFormat('yyyy-MM-dd').format(simdi);
    for (int i = 0; i < vakitIsimleri.length; i++) {
      final vakitAdi = vakitIsimleri[i];
      String? vakitSaati = vakitler![vakitAdi];
      
      if (vakitSaati != null) {
        // Saati temizle (Örn: "05:30 (EEST)" -> "05:30")
        vakitSaati = vakitSaati.split(" ")[0]; 
        
        try {
          final vakitDateTime = DateFormat('yyyy-MM-dd HH:mm').parse('$bugunStr $vakitSaati');
          
          if (vakitDateTime.isAfter(simdi)) {
            await _notificationService.scheduleNotification(
              id: i,
              title: 'Namaz Vakti: $vakitAdi',
              body: '$vakitAdi vakti girdi. Namazını kılmayı unutma.',
              scheduledDate: vakitDateTime,
            );
          }
        } catch (e) {
          debugPrint("Hata: $vakitAdi vakti formatlanamadı -> $e");
        }
      }
    }
  }

  Future<void> _gununAyetiniYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final sonSecilenGun = prefs.getString('son_ayet_gunu') ?? "";

    if (bugun == sonSecilenGun) {
      gununAyetiMeali = prefs.getString('son_ayet_meal') ?? "";
      gununAyetiReferans = prefs.getString('son_ayet_ref') ?? "";
      
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

      await prefs.setString('son_ayet_gunu', bugun);
      await prefs.setString('son_ayet_meal', gununAyetiMeali);
      await prefs.setString('son_ayet_ref', gununAyetiReferans);
    } catch (e) {
      // Hata durumunda varsayılan ayet
      gununAyetiMeali = "Şüphesiz güçlükle beraber bir kolaylık vardır.";
      gununAyetiReferans = "İnşirah Suresi, 5. Ayet";
    }
    notifyListeners();
  }

  Future<void> bildirimAyariDegistir(bool acik) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('bildirimler_acik', acik);
    bildirimlerAcik = acik;
    await _bildirimleriGuncelle();
    notifyListeners();
  }

  // --- ZİKİRMATİK METOTLARI ---
  Future<void> zikirArtir() async {
    final prefs = await SharedPreferences.getInstance();
    
    _zikirSayaci++;
    await prefs.setInt('zikirSayaci', _zikirSayaci);

    // Günlük geçmişi kaydet
    final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _zikirGecmisi[bugun] = (_zikirGecmisi[bugun] ?? 0) + 1;
    await prefs.setString('zikirGecmisi', json.encode(_zikirGecmisi));

    // Her 10 zikirde +1 XP
    if (_zikirSayaci % 10 == 0) {
      _toplamXp += 1;
      _zikirXpKazanilan += 1;
      await prefs.setInt('toplam_xp', _toplamXp);
      await prefs.setInt('zikirXpKazanilan', _zikirXpKazanilan);
      
      // 🔥 FIREBASE CLOUD SYNC
      _firebaseCloudSync();
    }
    
    notifyListeners();
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
  
  // --- DİNİ GÜNLER (ALADHAN API) ---
  Future<void> seciliAyDiniGunleriGetir(int year, int month) async {
    String cacheKey = "$year-$month";
    if (_aylikDiniGunlerCache.contains(cacheKey)) return;

    isDiniGunlerLoading = true;
    notifyListeners();

    try {
      List<ReligiousDay> liste;
      if (seciliSehir.isNotEmpty) {
        liste = await _namazServisi.diniGunleriGetir(year, month, sehir: seciliSehir);
      } else {
        final prefs = await SharedPreferences.getInstance();
        double lat = prefs.getDouble('last_lat') ?? 38.6748; // Elazığ Fallback
        double lng = prefs.getDouble('last_lng') ?? 39.2225;
        Position pos = Position(
          latitude: lat, longitude: lng, timestamp: DateTime.now(),
          accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0,
          altitudeAccuracy: 0, headingAccuracy: 0,
        );
        liste = await _namazServisi.diniGunleriGetir(year, month, position: pos);
      }

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
