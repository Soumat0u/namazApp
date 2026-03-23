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
import 'package:quran/quran.dart' as quran;
import 'dart:math';

class NamazProvider extends ChangeNotifier {
  final NamazServisi _namazServisi;
  final NotificationService _notificationService;

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
  Map<String, dynamic> gunlukDetaylar =
      {}; // Hangi gün hangi vakit kılındı detayını tutar

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

  NamazProvider(this._namazServisi, this._notificationService) {
    _uygulamayiBaslat();
  }

  Future<void> _uygulamayiBaslat() async {
    await loadData();
    await _gununAyetiniYukle();

    if (vakitler != null) {
      isLoading = false;
      _ilkVakitHesapla();
      _sayaciBaslat();
      _bildirimleriGuncelle();
      notifyListeners();
    }

    await konumVeApiIstegi(kullaniciTetikledi: false);
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

        if (vakitler == null) {
          konumBilgisi = "Konum İzni Gerekli";
          hataMesaji =
              "Konum izni verilmediği için vakitler hesaplanamıyor. Lütfen bir şehir seçin.";
          isLoading = false;
          notifyListeners();
        } else {
          if (konumBilgisi == "Yükleniyor...") {
            konumBilgisi = "Konum İzni Bekleniyor (Önbellek)";
          }
          notifyListeners();
        }
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
      if (seciliSehir.isNotEmpty) {
        await sehirVakitleriniGetir(seciliSehir);
      } else if (vakitler == null) {
        _varsayilanKonumKullan(e.toString());
      } else {
        isLoading = false;
        if (kullaniciTetikledi) {
          hataMesaji =
              "İnternet bağlantısı yok, çevrimdışı veriler kullanılıyor.";
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
          "Şehir verileri alınamadı. Lütfen internet bağlantınızı kontrol edin.";
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
  }

  Future<void> kazaGuncelle(String vakit, int miktar) async {
    final prefs = await SharedPreferences.getInstance();
    int yeniMiktar = (kazaNamazlari[vakit] ?? 0) + miktar;
    if (yeniMiktar < 0) yeniMiktar = 0;
    kazaNamazlari[vakit] = yeniMiktar;
    await prefs.setInt('kaza_$vakit', yeniMiktar);
    notifyListeners();
  }

  // 🔥 XP KAZANMA FONKSİYONU
  Future<void> xpKazandir() async {
    final prefs = await SharedPreferences.getInstance();
    _toplamXp += SeviyeServisi.namazXp; // Servisten 10 XP çekiyoruz
    await prefs.setInt('toplam_xp', _toplamXp);
    notifyListeners();
  }

  Future<void> vaktiKildimIsaretle(String vakitIsmi, bool yeniDurum) async {
    // 🔥 XP SUİSTİMALİNİ ÖNLEME: Zaten aynı durumdaysa işlem yapma
    // 🔥 DURUMU HEMEN GÜNCELLE (Race condition önlemek için await öncesinde)
    kildiMi[vakitIsmi] = yeniDurum;

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('kildi_$vakitIsmi', yeniDurum);

    if (yeniDurum) {
      streakCount++;
      toplamTamamlanan++;
      await xpKazandir(); // 🔥 NAMAZ KILINCA XP VERİYORUZ
    } else {
      if (streakCount > 0) streakCount--;
      if (toplamTamamlanan > 0) toplamTamamlanan--;

      // Geri alınan namazda XP'yi de geri alıyoruz
      if (_toplamXp >= SeviyeServisi.namazXp) {
        _toplamXp -= SeviyeServisi.namazXp;
        await prefs.setInt('toplam_xp', _toplamXp);
      }
    }
    await prefs.setInt('streakCount', streakCount);
    await prefs.setInt('toplamKilinan', toplamTamamlanan);

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

  // lib/providers/namaz_provider.dart içindeki ilgili kısmı güncelliyorum
Future<void> _bildirimleriGuncelle() async {
  // 1. Tüm eski bildirimleri temizle
  await _notificationService.cancelAll();
  // 2. Eğer bildirimler kapalıysa veya vakitler yüklenmemişse çık
  if (!bildirimlerAcik || vakitler == null) return;
  final simdi = DateTime.now();
  final bugunStr = DateFormat('yyyy-MM-dd').format(simdi);
  for (int i = 0; i < vakitIsimleri.length; i++) {
    final vakitAdi = vakitIsimleri[i];
    String? vakitSaati = vakitler![vakitAdi];
    
    if (vakitSaati != null) {
      // 3. KRİTİK: Saati temizle (Örn: "05:30 (EEST)" -> "05:30")
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
}
