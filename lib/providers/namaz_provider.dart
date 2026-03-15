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
import '../models/gorev_model.dart';
import '../services/gorev_servisi.dart';

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
  
  // SEVİYE SİSTEMİ
  int _toplamXp = 0;
  int get toplamXp => _toplamXp;
  String get mevcutUnvan => SeviyeServisi.unvanGetir(_toplamXp);
  double get seviyeIlerleme => SeviyeServisi.ilerlemeHesapla(_toplamXp);

  // GÖREV SİSTEMİ
  List<Gorev> _gorevler = [];
  List<Gorev> get gorevler => _gorevler;

  String sonSifirlamaTarihi = "";
  String sonHaftalikSifirlama = ""; 

  Map<String, bool> kildiMi = {
    "Sabah": false, "Öğle": false, "İkindi": false, "Akşam": false, "Yatsı": false,
  };
  final List<String> vakitIsimleri = ["Sabah", "Öğle", "İkindi", "Akşam", "Yatsı"];
  Map<String, int> kazaNamazlari = {
    "Sabah": 0, "Öğle": 0, "İkindi": 0, "Akşam": 0, "Yatsı": 0,
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
    // Uygulama her açıldığında "Güne Merhaba" görevini bitir
    await gorevTamamlaById('g_merhaba');
    
    if (vakitler != null) {
      isLoading = false;
      _ilkVakitHesapla();
      _sayaciBaslat();
      notifyListeners();
    }
    await konumVeApiIstegi(kullaniciTetikledi: false);
  }

  // 🔥 GÖREV DENETLEYİCİ
  Future<void> gorevleriDenetle() async {
    bool degisiklikVar = false;
    for (var gorev in _gorevler) {
      if (gorev.tamamlandiMi) continue;

      if (gorev.id == 'g_full_house') {
        int bugunKilinan = kildiMi.values.where((v) => v).length;
        gorev.ilerleme = bugunKilinan / 5;
        if (bugunKilinan == 5) { 
          gorev.tamamlandiMi = true; 
          gorev.ilerleme = 1.0; 
          degisiklikVar = true; 
        }
      } else if (gorev.id == 'h_sampiyon' && toplamTamamlanan >= 30) {
        gorev.tamamlandiMi = true; 
        gorev.ilerleme = 1.0; 
        degisiklikVar = true;
      } else if (gorev.id == 'z_ilk_namaz' && toplamTamamlanan >= 1) {
        gorev.tamamlandiMi = true; 
        gorev.ilerleme = 1.0; 
        degisiklikVar = true;
      }
    }
    if (degisiklikVar) { await gorevleriKaydet(); notifyListeners(); }
  }

  // 🔥 ID İLE ÖZEL GÖREV TAMAMLAMA
  Future<void> gorevTamamlaById(String id) async {
    int index = _gorevler.indexWhere((g) => g.id == id);
    if (index != -1 && !_gorevler[index].tamamlandiMi) {
      _gorevler[index].tamamlandiMi = true;
      _gorevler[index].ilerleme = 1.0;
      await gorevleriKaydet();
      notifyListeners();
    }
  }

  // 🔥 ÖDÜLÜ AL BUTONU
  Future<void> oduluAl(Gorev gorev) async {
    if (gorev.tamamlandiMi && !gorev.odulAlindiMi) {
      gorev.odulAlindiMi = true;
      await xpKazandir(gorev.xpOdulu);
      await gorevleriKaydet();
      notifyListeners();
    }
  }

  Future<void> gorevleriKaydet() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> gorevJsonList = _gorevler.map((g) => jsonEncode(g.toJson())).toList();
    await prefs.setStringList('user_tasks', gorevJsonList);
  }

  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final simdi = DateTime.now();
    ekranTarihi = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(simdi);

    streakCount = prefs.getInt('streakCount') ?? 0;
    toplamTamamlanan = prefs.getInt('toplamKilinan') ?? 0;
    _toplamXp = prefs.getInt('toplam_xp') ?? 0;
    sonSifirlamaTarihi = prefs.getString('lastResetDate') ?? "";
    sonHaftalikSifirlama = prefs.getString('lastWeeklyReset') ?? "";
    konumBilgisi = prefs.getString('cached_location') ?? "Yükleniyor...";

    _gorevler = GorevServisi.tumGorevleriGetir();
    List<String>? savedTasks = prefs.getStringList('user_tasks');
    if (savedTasks != null) {
      for (var taskStr in savedTasks) {
        var taskJson = jsonDecode(taskStr);
        int index = _gorevler.indexWhere((g) => g.id == taskJson['id']);
        if (index != -1) {
          _gorevler[index].tamamlandiMi = taskJson['tamamlandiMi'] ?? false;
          _gorevler[index].odulAlindiMi = taskJson['odulAlindiMi'] ?? false;
          _gorevler[index].ilerleme = (taskJson['ilerleme'] ?? 0.0).toDouble();
        }
      }
    }
    _zamanliGorevSifirlamaKontrolu();

    String? cachedVakitlerString = prefs.getString('cached_vakitler');
    if (cachedVakitlerString != null) {
      vakitler = Map<String, String>.from(json.decode(cachedVakitlerString));
    }
    for (var vkt in vakitIsimleri) { kildiMi[vkt] = prefs.getBool('kildi_$vkt') ?? false; }
    for (var vkt in vakitIsimleri) { kazaNamazlari[vkt] = prefs.getInt('kaza_$vkt') ?? 0; }
    await istatistikleriYukle();
  }

  void _zamanliGorevSifirlamaKontrolu() async {
    final prefs = await SharedPreferences.getInstance();
    final simdi = DateTime.now();
    String bugunStr = DateFormat('yyyy-MM-dd').format(simdi);
    
    if (sonSifirlamaTarihi != bugunStr) {
      for (var g in _gorevler.where((g) => g.tip == GorevTipi.gunluk)) { 
        g.tamamlandiMi = false; 
        g.odulAlindiMi = false; 
        g.ilerleme = 0.0; 
      }
    }
    
    String buHaftaStr = "W-${simdi.year}-${DateFormat('w').format(simdi)}";
    if (sonHaftalikSifirlama != buHaftaStr) {
      for (var g in _gorevler.where((g) => g.tip == GorevTipi.haftalik)) { 
        g.tamamlandiMi = false; 
        g.odulAlindiMi = false; 
        g.ilerleme = 0.0; 
      }
      await prefs.setString('lastWeeklyReset', buHaftaStr);
    }
    await gorevleriKaydet();
  }

  Future<void> kazaGuncelle(String vakit, int miktar) async {
    final prefs = await SharedPreferences.getInstance();
    int yeniMiktar = (kazaNamazlari[vakit] ?? 0) + miktar;
    if (yeniMiktar < 0) yeniMiktar = 0;
    kazaNamazlari[vakit] = yeniMiktar;
    await prefs.setInt('kaza_$vakit', yeniMiktar);
    await gorevleriDenetle(); 
    notifyListeners();
  }

  Future<void> vaktiKildimIsaretle(String vakitIsmi, bool yeniDurum) async {
    final prefs = await SharedPreferences.getInstance();
    kildiMi[vakitIsmi] = yeniDurum;
    await prefs.setBool('kildi_$vakitIsmi', yeniDurum);

    if (yeniDurum) {
      streakCount++;
      toplamTamamlanan++;
      await xpKazandir(SeviyeServisi.namazXp); 
    } else {
      if (streakCount > 0) streakCount--;
      if (toplamTamamlanan > 0) toplamTamamlanan--;
      if (_toplamXp >= 10) _toplamXp -= 10;
      await prefs.setInt('toplam_xp', _toplamXp);
    }
    await prefs.setInt('streakCount', streakCount);
    await prefs.setInt('toplamKilinan', toplamTamamlanan);
    await gorevleriDenetle();
    await istatistikleriYukle();
    notifyListeners();
  }

  Future<void> xpKazandir(int miktar) async {
    final prefs = await SharedPreferences.getInstance();
    _toplamXp += miktar;
    await prefs.setInt('toplam_xp', _toplamXp);
    notifyListeners();
  }

  Future<void> verileriSifirla() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    await _uygulamayiBaslat();
  }

  // --- DİĞER METODLAR (AYNEN KORUNDU) ---
  Future<void> konumVeApiIstegi({bool kullaniciTetikledi = false}) async {
    if (vakitler == null) { isLoading = true; notifyListeners(); }
    try {
      Position? position = await _namazServisi.konumGetir(izinIste: kullaniciTetikledi);
      if (position == null) {
        if (vakitler == null) {
          konumBilgisi = "Konum İzni Gerekli";
          hataMesaji = "Konum izni verilmediği için vakitler hesaplanamıyor.";
          isLoading = false;
          notifyListeners();
        }
        return;
      }
      final veriler = await _namazServisi.vakitleriGetir(position);
      final prefs = await SharedPreferences.getInstance();
      vakitler = veriler;
      await prefs.setString('cached_vakitler', json.encode(vakitler));
      _adresGuncelle(position);
      _sabahVaktiSifirlamaKontrolu();
      _ilkVakitHesapla();
      _sayaciBaslat();
      hataMesaji = ""; isLoading = false; notifyListeners();
    } catch (e) {
      if (vakitler == null) _varsayilanKonumKullan(e.toString());
      else { isLoading = false; notifyListeners(); }
    }
  }

  Future<void> _varsayilanKonumKullan(String hata) async {
    Position fallbackPos = Position(latitude: 38.6748, longitude: 39.2225, timestamp: DateTime.now(), accuracy: 0, altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0);
    try {
      final veriler = await _namazServisi.vakitleriGetir(fallbackPos);
      vakitler = veriler;
      konumBilgisi = "Varsayılan: ELAZIĞ";
      _ilkVakitHesapla(); _sayaciBaslat(); isLoading = false; hataMesaji = "";
    } catch (e) { isLoading = false; hataMesaji = "Bağlantı yok."; }
    notifyListeners();
  }

  void _adresGuncelle(Position pos) async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(pos.latitude, pos.longitude).timeout(const Duration(seconds: 5));
      if (p.isNotEmpty) {
        konumBilgisi = "${p[0].country?.toUpperCase()}, ${p[0].administrativeArea?.toUpperCase()}";
        notifyListeners();
      }
    } catch (_) {}
  }

  void _sabahVaktiSifirlamaKontrolu() {
    if (vakitler == null) return;
    final bugunStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (sonSifirlamaTarihi != bugunStr) {
      bool dunuTamamladiMi = kildiMi.values.every((v) => v == true);
      if (!dunuTamamladiMi && streakCount > 0) _streakSifirla();
      _kutucuklariSifirla(bugunStr);
      _zamanliGorevSifirlamaKontrolu();
    }
  }

  Future<void> _kutucuklariSifirla(String bugunStr) async {
    final prefs = await SharedPreferences.getInstance();
    kildiMi.updateAll((key, value) => false);
    sonSifirlamaTarihi = bugunStr;
    for (var vkt in vakitIsimleri) { await prefs.setBool('kildi_$vkt', false); }
    await prefs.setString('lastResetDate', bugunStr);
    notifyListeners();
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
    if (simdi.isBefore(sabahVakti)) bulunan = "Yatsı";
    else {
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
    return DateTime(now.year, now.month, now.day, int.parse(parts[0]), int.parse(parts[1].split(" ")[0]));
  }

  void _sayaciBaslat() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (vakitler == null) return;
      final simdi = DateTime.now();
      final sabahVakti = _parseTime(vakitler!["Sabah"]!);
      String bulunanVakit = "Yatsı";
      DateTime? bitisZamani;
      if (simdi.isBefore(sabahVakti)) { bulunanVakit = "Yatsı"; bitisZamani = sabahVakti; }
      else {
        for (var i = 0; i < vakitIsimleri.length; i++) {
          var vktDT = _parseTime(vakitler![vakitIsimleri[i]]!);
          if (simdi.isBefore(vktDT)) { bulunanVakit = i == 0 ? "Yatsı" : vakitIsimleri[i - 1]; bitisZamani = vktDT; break; }
        }
      }
      bitisZamani ??= sabahVakti.add(const Duration(days: 1));
      if (aktifVakit != bulunanVakit) {
        if (!(kildiMi[aktifVakit] ?? false)) _streakSifirla();
        aktifVakit = bulunanVakit;
      }
      final fark = bitisZamani.difference(simdi);
      kalanSure = "${fark.inHours.toString().padLeft(2, '0')}:${(fark.inMinutes % 60).toString().padLeft(2, '0')}:${(fark.inSeconds % 60).toString().padLeft(2, '0')}";
      notifyListeners();
    });
  }

  Future<void> istatistikleriYukle() async {
    final prefs = await SharedPreferences.getInstance();
    String? historyJson = prefs.getString('history_stats');
    Map<String, dynamic> history = historyJson != null ? json.decode(historyJson) : {};
    List<FlSpot> tempSpots = [];
    List<String> tempLabels = [];
    DateTime bugun = DateTime.now();
    DateTime buHaftaninPazartesisi = bugun.subtract(Duration(days: bugun.weekday - 1));
    for (int i = 0; i < 7; i++) {
      DateTime hedefGun = buHaftaninPazartesisi.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(hedefGun);
      int count = history[dateKey] ?? 0;
      tempSpots.add(FlSpot(i.toDouble(), count.toDouble()));
      tempLabels.add(DateFormat('E', 'tr_TR').format(hedefGun));
    }
    grafikNoktalari = tempSpots; gunIsimleri = tempLabels; notifyListeners();
  }
}