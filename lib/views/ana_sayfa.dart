import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geocoding/geocoding.dart';

// --- RENK PALETİ ---
const Color kArkaPlanRengi = Color(0xFFFFFDF5);
const Color kKartRengi = Color(0xFFFFFFFF);
const Color kAnaRenk = Color(0xFFE67E22);
const Color kYaziRengi = Color(0xFF3E2723);
const Color kPasifRenk = Color(0xFFBCAAA4);
const Color kAktifYesil = Color(0xFF2E7D32);

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});
  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  Map<String, String>? _vakitler;
  String _aktifVakit = "Sabah";
  String _kalanSure = "--:--:--";
  String _ekranTarihi = "";
  String _konumBilgisi = "Yükleniyor...";

  Timer? _timer;
  bool _isLoading = true;
  String _hataMesaji = "";
  int _streakCount = 0;
  String _sonSifirlamaTarihi = "";

  Map<String, bool> kildiMi = {
    "Sabah": false,
    "Öğle": false,
    "İkindi": false,
    "Akşam": false,
    "Yatsı": false,
  };

  final List<String> _vakitIsimleri = [
    "Sabah",
    "Öğle",
    "İkindi",
    "Akşam",
    "Yatsı",
  ];

  @override
  void initState() {
    super.initState();
    _uygulamayiBaslat();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // --- MANTIK FONKSİYONLARI ---

  Future<void> _uygulamayiBaslat() async {
    await _loadData();

    if (_vakitler != null) {
      setState(() {
        _isLoading = false;
      });
      _ilkVakitHesapla();
      _sayaciBaslat();
    }

    // Normal açılışta zorlaYenile: false
    _konumVeApiIstegi(zorlaYenile: false);
  }

  Future<void> _konumVeApiIstegi({bool zorlaYenile = false}) async {
    if (zorlaYenile || (_vakitler == null && mounted)) {
      setState(() {
        _isLoading = true;
        _hataMesaji = "";
      });
    }

    try {
      Position position;

      if (zorlaYenile) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
        ).timeout(const Duration(seconds: 6));
      } else {
        Position? lastKnown = await Geolocator.getLastKnownPosition();
        if (lastKnown != null) {
          position = lastKnown;
        } else {
          try {
            position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.lowest,
            ).timeout(const Duration(seconds: 4));
          } catch (e) {
            position = Position(
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
          }
        }
      }

      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings?latitude=${position.latitude}&longitude=${position.longitude}&method=13',
      );

      final response = await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data']['timings'];
        final prefs = await SharedPreferences.getInstance();

        if (!mounted) return;

        setState(() {
          _vakitler = {
            "Sabah": data['Fajr'],
            "Öğle": data['Dhuhr'],
            "İkindi": data['Asr'],
            "Akşam": data['Maghrib'],
            "Yatsı": data['Isha'],
          };
          _isLoading = false;
        });

        await prefs.setString('cached_vakitler', json.encode(_vakitler));

        _sabahVaktiSifirlamaKontrolu();
        _ilkVakitHesapla();
        _sayaciBaslat();
        _adresGuncelle(position);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          if (zorlaYenile) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  "Güncelleme başarısız: İnternet veya GPS sorunu.",
                ),
                backgroundColor: Colors.redAccent,
              ),
            );
          } else if (_vakitler == null) {
            _hataMesaji = "Bağlantı hatası.";
          }
        });
      }
    }
  }

  void _adresGuncelle(Position pos) async {
    try {
      List<Placemark> p = await placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      ).timeout(const Duration(seconds: 5));

      if (p.isNotEmpty && mounted) {
        String city =
            "${p[0].country?.toUpperCase()}, ${p[0].administrativeArea?.toUpperCase()}";
        setState(() => _konumBilgisi = city);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('cached_location', city);
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final simdi = DateTime.now();

    if (mounted) {
      setState(() {
        _ekranTarihi = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(simdi);
        _streakCount = prefs.getInt('streakCount') ?? 0;
        _sonSifirlamaTarihi = prefs.getString('lastResetDate') ?? "";

        _konumBilgisi =
            prefs.getString('cached_location') ?? "Konum Alınıyor...";

        String? cachedVakitlerString = prefs.getString('cached_vakitler');
        if (cachedVakitlerString != null) {
          _vakitler = Map<String, String>.from(
            json.decode(cachedVakitlerString),
          );
        }

        for (var vkt in _vakitIsimleri) {
          kildiMi[vkt] = prefs.getBool('kildi_$vkt') ?? false;
        }
      });
    }
  }

  Future<void> _saveKildiMi() async {
    final prefs = await SharedPreferences.getInstance();
    // 1. Mevcut checkbox durumunu kaydet
    kildiMi.forEach((key, value) => prefs.setBool('kildi_$key', value));

    // 2. İstatistik için tarih bazlı kayıt (ARKA PLAN İŞLEMİ)
    final bugun = DateFormat('yyyy-MM-dd').format(DateTime.now());
    String? historyJson = prefs.getString('history_stats');
    Map<String, dynamic> history = historyJson != null
        ? json.decode(historyJson)
        : {};

    int gunlukToplam = kildiMi.values.where((v) => v).length;
    history[bugun] = gunlukToplam;
    await prefs.setString('history_stats', json.encode(history));
  }

  Future<void> _kutucuklariSifirla(String bugunStr) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      kildiMi.updateAll((key, value) => false);
      _sonSifirlamaTarihi = bugunStr;
    });
    for (var vkt in _vakitIsimleri) {
      await prefs.setBool('kildi_$vkt', false);
    }
    await prefs.setString('lastResetDate', bugunStr);
  }

  void _sabahVaktiSifirlamaKontrolu() {
    if (_vakitler == null) return;
    final simdi = DateTime.now();
    final bugunTarihStr = DateFormat('yyyy-MM-dd').format(simdi);
    if (_sonSifirlamaTarihi != bugunTarihStr) {
      bool dunuTamamladiMi = kildiMi.values.every((v) => v == true);
      if (!dunuTamamladiMi && _streakCount > 0) {
        _streakSifirla();
      }
      _kutucuklariSifirla(bugunTarihStr);
    } else {
      int suankiIndex = _vakitIsimleri.indexOf(_aktifVakit);
      for (int i = 0; i < suankiIndex; i++) {
        if (kildiMi[_vakitIsimleri[i]] == false) {
          _streakSifirla();
          break;
        }
      }
    }
  }

  void _ilkVakitHesapla() {
    if (_vakitler == null) return;
    final simdi = DateTime.now();
    String bulunan = "Yatsı";
    final sabahVakti = _parseTime(_vakitler!['Sabah']!);
    if (simdi.isBefore(sabahVakti)) {
      bulunan = "Yatsı";
    } else {
      for (var i = 0; i < _vakitIsimleri.length; i++) {
        if (simdi.isBefore(_parseTime(_vakitler![_vakitIsimleri[i]]!))) {
          bulunan = i == 0 ? "Yatsı" : _vakitIsimleri[i - 1];
          break;
        }
      }
    }
    setState(() => _aktifVakit = bulunan);
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
      if (_vakitler == null || !mounted) return;
      final simdi = DateTime.now();
      final bugunStr = DateFormat('yyyy-MM-dd').format(simdi);

      setState(
        () => _ekranTarihi = DateFormat(
          'dd MMMM yyyy, EEEE',
          'tr_TR',
        ).format(simdi),
      );

      var sabahVakti = _parseTime(_vakitler!["Sabah"]!);
      String bulunanVakit = "Yatsı";
      DateTime? bitisZamani;

      if (simdi.isBefore(sabahVakti)) {
        bulunanVakit = "Yatsı";
        bitisZamani = sabahVakti;
      } else {
        for (var i = 0; i < _vakitIsimleri.length; i++) {
          var vktDT = _parseTime(_vakitler![_vakitIsimleri[i]]!);
          if (simdi.isBefore(vktDT)) {
            bulunanVakit = i == 0 ? "Yatsı" : _vakitIsimleri[i - 1];
            bitisZamani = vktDT;
            break;
          }
        }
      }
      bitisZamani ??= sabahVakti.add(const Duration(days: 1));

      if (_aktifVakit != bulunanVakit) {
        if (!(kildiMi[_aktifVakit] ?? false)) _streakSifirla();
        if (bulunanVakit == "Sabah" && _sonSifirlamaTarihi != bugunStr) {
          _kutucuklariSifirla(bugunStr);
        }
        setState(() => _aktifVakit = bulunanVakit);
      }

      final fark = bitisZamani.difference(simdi);
      if (mounted) {
        setState(() {
          _kalanSure =
              "${fark.inHours.toString().padLeft(2, '0')}:${(fark.inMinutes % 60).toString().padLeft(2, '0')}:${(fark.inSeconds % 60).toString().padLeft(2, '0')}";
        });
      }
    });
  }

  void _streakSifirla() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _streakCount = 0);
    prefs.setInt('streakCount', 0);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Seri bozuldu!")));
  }

  void _streakIslem(bool artir) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (artir) {
        _streakCount++;
        // İstatistik için toplam sayıyı güncelle (Arka plan işlemi)
        int total = prefs.getInt('toplamKilinan') ?? 0;
        prefs.setInt('toplamKilinan', total + 1);
      } else if (_streakCount > 0) {
        _streakCount--;
        // İstatistik için toplam sayıyı güncelle (Arka plan işlemi)
        int total = prefs.getInt('toplamKilinan') ?? 0;
        if (total > 0) prefs.setInt('toplamKilinan', total - 1);
      }
    });
    prefs.setInt('streakCount', _streakCount);
  }

  // --- UI BUILD ---
  @override
  Widget build(BuildContext context) {
    // Ekran boyutunu alıyoruz
    final ekranYuksekligi = MediaQuery.of(context).size.height;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: kAnaRenk));
    }

    if (_hataMesaji.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _hataMesaji,
              style: const TextStyle(color: kYaziRengi, fontSize: 16),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => _konumVeApiIstegi(zorlaYenile: true),
              style: ElevatedButton.styleFrom(
                backgroundColor: kAnaRenk,
                foregroundColor: Colors.white,
              ),
              child: const Text("Tekrar Dene"),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: kAnaRenk,
        backgroundColor: kKartRengi,
        onRefresh: () async {
          await _konumVeApiIstegi(zorlaYenile: true);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. HEADER
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: _sikKutuDecoration(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _ekranTarihi.split(',')[0],
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: kYaziRengi,
                            ),
                          ),
                          Text(
                            _ekranTarihi.contains(',')
                                ? _ekranTarihi.split(',')[1].trim()
                                : "",
                            style: TextStyle(
                              fontSize: 16,
                              color: kYaziRengi.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: kAnaRenk.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.local_fire_department,
                              color: kAnaRenk,
                              size: 28,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              "$_streakCount",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: kYaziRengi,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 2. ORTA VİTRİN
                Container(
                  height: ekranYuksekligi * 0.35,
                  decoration: _sikKutuDecoration().copyWith(
                    gradient: const LinearGradient(
                      colors: [kKartRengi, Color(0xFFFFF3E0)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Konum güncelleniyor..."),
                              duration: Duration(seconds: 1),
                            ),
                          );
                          _konumVeApiIstegi(zorlaYenile: true);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.location_on,
                                size: 16,
                                color: kYaziRengi.withOpacity(0.6),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _konumBilgisi,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: kYaziRengi.withOpacity(0.6),
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                Icons.refresh,
                                size: 14,
                                color: kYaziRengi.withOpacity(0.4),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        _aktifVakit.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 28,
                          letterSpacing: 5,
                          color: kAnaRenk,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        DateFormat("HH:mm").format(DateTime.now()),
                        style: const TextStyle(
                          fontSize: 75,
                          fontWeight: FontWeight.bold,
                          color: kYaziRengi,
                          letterSpacing: -2,
                          height: 1.0,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: kYaziRengi.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Text(
                          "Kalan Süre: $_kalanSure",
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: kYaziRengi,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 3. VAKİT KUTUCUKLARI
                Container(
                  height: 130,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: _sikKutuDecoration(),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _vakitKutusu(
                        "Sabah",
                        Icons.wb_twilight,
                        _vakitler?["Sabah"] ?? "--:--",
                      ),
                      _vakitKutusu(
                        "Öğle",
                        Icons.wb_sunny,
                        _vakitler?["Öğle"] ?? "--:--",
                      ),
                      _vakitKutusu(
                        "İkindi",
                        Icons.wb_twighlight,
                        _vakitler?["İkindi"] ?? "--:--",
                      ),
                      _vakitKutusu(
                        "Akşam",
                        Icons.bedtime,
                        _vakitler?["Akşam"] ?? "--:--",
                      ),
                      _vakitKutusu(
                        "Yatsı",
                        Icons.nights_stay,
                        _vakitler?["Yatsı"] ?? "--:--",
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),

                // 4. BUTON
                SizedBox(
                  height: ekranYuksekligi * 0.15,
                  child: _AnimatedPrayerButton(
                    isDone: kildiMi[_aktifVakit] ?? false,
                    onTap: () {
                      setState(() {
                        bool suanki = kildiMi[_aktifVakit] ?? false;
                        kildiMi[_aktifVakit] = !suanki;
                        _saveKildiMi();
                        _streakIslem(!suanki);
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration _sikKutuDecoration() => BoxDecoration(
    color: kKartRengi,
    borderRadius: BorderRadius.circular(25),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  );

  Widget _vakitKutusu(String ad, IconData ikon, String saat) {
    bool kildi = kildiMi[ad] ?? false;
    bool suan = _aktifVakit == ad;
    String temizSaat = saat.contains(" ") ? saat.split(" ")[0] : saat;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: suan ? kAktifYesil.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
        border: suan
            ? Border.all(color: kAktifYesil.withOpacity(0.5), width: 1.5)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            ikon,
            size: 28,
            color: kildi ? kAktifYesil : (suan ? kAnaRenk : kPasifRenk),
          ),
          const SizedBox(height: 8),
          Text(
            temizSaat,
            style: TextStyle(
              fontSize: 15,
              fontWeight: suan ? FontWeight.bold : FontWeight.w500,
              color: suan ? kYaziRengi : kYaziRengi.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            ad,
            style: TextStyle(
              fontSize: 12,
              color: suan ? kAnaRenk : Colors.transparent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _AnimatedPrayerButton extends StatefulWidget {
  final bool isDone;
  final VoidCallback onTap;
  const _AnimatedPrayerButton({required this.isDone, required this.onTap});
  @override
  State<_AnimatedPrayerButton> createState() => _AnimatedPrayerButtonState();
}

class _AnimatedPrayerButtonState extends State<_AnimatedPrayerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: widget.isDone ? kAktifYesil : kKartRengi,
            borderRadius: BorderRadius.circular(30),
            border: widget.isDone
                ? null
                : Border.all(color: kAnaRenk.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.isDone
                    ? kAktifYesil.withOpacity(0.4)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kArkaPlanRengi,
                  border: Border.all(
                    color: widget.isDone ? Colors.white : kPasifRenk,
                    width: 4,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 45,
                  color: widget.isDone ? kAktifYesil : kPasifRenk,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                widget.isDone ? "ALLAH KABUL ETSİN!" : "VAKTİ KILDIM",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: widget.isDone ? Colors.white : kYaziRengi,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
