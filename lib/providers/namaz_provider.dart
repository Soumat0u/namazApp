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
  String kalanSure = "--:--:--";
  String ekranTarihi = "";
  String konumBilgisi = "Yükleniyor...";

  int streakCount = 0;
  int toplamTamamlanan = 0;
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
        if (vakitler == null) {
          konumBilgisi = "Konum İzni Gerekli";
          hataMesaji = "Konum izni verilmediği için vakitler hesaplanamıyor.";
          isLoading = false;
          notifyListeners();
        } else {
          if (konumBilgisi == "Yükleniyor...")
            konumBilgisi = "Konum İzni Bekleniyor (Önbellek)";
          notifyListeners();
        }
        return;
      }

      final veriler = await _namazServisi.vakitleriGetir(position);
      final prefs = await SharedPreferences.getInstance();
      vakitler = veriler;
      await prefs.setString('cached_vakitler', json.encode(vakitler));

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
      if (vakitler == null) {
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
        !konumBilgisi.contains("İzni"))
      return;

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
    sonSifirlamaTarihi = prefs.getString('lastResetDate') ?? "";
    konumBilgisi = prefs.getString('cached_location') ?? "Yükleniyor...";

    String? cachedVakitlerString = prefs.getString('cached_vakitler');
    if (cachedVakitlerString != null) {
      vakitler = Map<String, String>.from(json.decode(cachedVakitlerString));
    }
    for (var vkt in vakitIsimleri)
      kildiMi[vkt] = prefs.getBool('kildi_$vkt') ?? false;
    for (var vkt in vakitIsimleri)
      kazaNamazlari[vkt] = prefs.getInt('kaza_$vkt') ?? 0;

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

  Future<void> vaktiKildimIsaretle(String vakitIsmi, bool yeniDurum) async {
    final prefs = await SharedPreferences.getInstance();
    kildiMi[vakitIsmi] = yeniDurum;
    await prefs.setBool('kildi_$vakitIsmi', yeniDurum);

    if (yeniDurum) {
      streakCount++;
      toplamTamamlanan++;
    } else {
      if (streakCount > 0) streakCount--;
      if (toplamTamamlanan > 0) toplamTamamlanan--;
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
    for (var vkt in vakitIsimleri) await prefs.setBool('kildi_$vkt', false);
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
        if (bulunanVakit == "Sabah" && sonSifirlamaTarihi != bugunStr)
          _kutucuklariSifirla(bugunStr);
        aktifVakit = bulunanVakit;
      }

      final fark = bitisZamani.difference(simdi);
      kalanSure =
          "${fark.inHours.toString().padLeft(2, '0')}:${(fark.inMinutes % 60).toString().padLeft(2, '0')}:${(fark.inSeconds % 60).toString().padLeft(2, '0')}";

      // Her saniye state yenilememek için sadece saat değiştiğinde UI güncelle (Performans için)
      // Ancak sayaç aktığı için mecburen saniyede bir güncelliyoruz
      notifyListeners();
    });
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
