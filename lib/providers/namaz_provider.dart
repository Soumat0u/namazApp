import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/namaz_servis.dart';
import '../services/bildirim_servisi.dart';
import '../services/seviye_servisi.dart'; // Seviye servisini ekledik

class NamazProvider extends ChangeNotifier {
  final NamazServisi _namazServisi;

  NamazProvider(this._namazServisi) {
    _uygulamayiBaslat();
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

  int streakCount = 0;
  int toplamTamamlanan = 0;

  // 🔥 SEVİYE SİSTEMİ DEĞİŞKENLERİ
  int _toplamXp = 0;
  int get toplamXp => _toplamXp;
  String get mevcutUnvan => SeviyeServisi.unvanGetir(_toplamXp);
  double get seviyeIlerleme => SeviyeServisi.ilerlemeHesapla(_toplamXp);

  String sonSifirlamaTarihi = "";

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

  Future<void> _uygulamayiBaslat() async {
    await loadData();

    if (vakitler != null) {
      isLoading = false;
      _ilkVakitHesapla();
      _sayaciBaslat();
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

      bool bildirimAcik = prefs.getBool('bildirimler_acik') ?? true;
      if (bildirimAcik) BildirimServisi.vakitBildirimleriniKur(vakitler!);

      _adresGuncelle(position);
      _sabahVaktiSifirlamaKontrolu();
      _ilkVakitHesapla();
      _sayaciBaslat();

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

      bool bildirimAcik = prefs.getBool('bildirimler_acik') ?? true;
      if (bildirimAcik) BildirimServisi.vakitBildirimleriniKur(vakitler!);

      _sabahVaktiSifirlamaKontrolu();
      _ilkVakitHesapla();
      _sayaciBaslat();

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
    final prefs = await SharedPreferences.getInstance();
    kildiMi[vakitIsmi] = yeniDurum;
    await prefs.setBool('kildi_$vakitIsmi', yeniDurum);

    if (yeniDurum) {
      streakCount++;
      toplamTamamlanan++;
      await xpKazandir(); // 🔥 NAMAZ KILINCA XP VERİYORUZ
    } else {
      if (streakCount > 0) streakCount--;
      if (toplamTamamlanan > 0) toplamTamamlanan--;

      // Geri alınan namazda XP'yi de geri alabiliriz (Opsiyonel)
      if (_toplamXp >= 10) {
        _toplamXp -= 10;
        await prefs.setInt('toplam_xp', _toplamXp);
      }
    }
    await prefs.setInt('streakCount', streakCount);
    await prefs.setInt('toplamKilinan', toplamTamamlanan);

    final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String? historyJson = prefs.getString('history_stats');
    Map<String, dynamic> history = historyJson != null
        ? json.decode(historyJson)
        : {};
    history[bugun] = kildiMi.values.where((v) => v).length;
    await prefs.setString('history_stats', json.encode(history));
    await istatistikleriYukle();
    notifyListeners();
  }

  Future<void> _kutucuklariSifirla(String bugunStr) async {
    final prefs = await SharedPreferences.getInstance();
    kildiMi.updateAll((key, value) => false);
    sonSifirlamaTarihi = bugunStr;
    for (var vkt in vakitIsimleri) {
      await prefs.setBool('kildi_$vkt', false);
    }
    await prefs.setString('lastResetDate', bugunStr);
    notifyListeners();
  }

  void _sabahVaktiSifirlamaKontrolu() {
    if (vakitler == null) return;
    final bugunStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (sonSifirlamaTarihi != bugunStr) {
      bool dunuTamamladiMi = kildiMi.values.every((v) => v == true);
      if (!dunuTamamladiMi && streakCount > 0) _streakSifirla();
      _kutucuklariSifirla(bugunStr);
    }
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
        if (!(kildiMi[aktifVakit] ?? false)) _streakSifirla();
        if (bulunanVakit == "Sabah" && sonSifirlamaTarihi != bugunStr) {
          _kutucuklariSifirla(bugunStr);
        }
        aktifVakit = bulunanVakit;
      }

      final fark = bitisZamani.difference(simdi);
      kalanSureNotifier.value =
          "${fark.inHours.toString().padLeft(2, '0')}:${(fark.inMinutes % 60).toString().padLeft(2, '0')}:${(fark.inSeconds % 60).toString().padLeft(2, '0')}";
      guncelSaatNotifier.value = DateFormat("HH:mm").format(simdi);

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

    List<FlSpot> tempSpots = [];
    List<String> tempLabels = [];
    DateTime bugun = DateTime.now();
    int pztUzaklik = bugun.weekday - 1;
    DateTime buHaftaninPazartesisi = bugun.subtract(Duration(days: pztUzaklik));

    for (int i = 0; i < 7; i++) {
      DateTime hedefGun = buHaftaninPazartesisi.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(hedefGun);
      int count = history[dateKey] ?? 0;
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
    await _uygulamayiBaslat();
  }
}
