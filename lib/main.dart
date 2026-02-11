import 'package:flutter/material.dart';

import 'dart:convert';

import 'dart:async';

import 'package:http/http.dart' as http;

import 'package:geolocator/geolocator.dart';

import 'package:intl/intl.dart';

import 'package:intl/date_symbol_data_local.dart';

import 'package:shared_preferences/shared_preferences.dart';

// --- RENK PALETİ (Pastel & Sıcak) ---

const Color kArkaPlanRengi = Color(0xFFFFF8E1); // Krem/Bej

const Color kKartRengi = Color(0xFFFFFFFF); // Beyaz

const Color kAnaRenk = Color(0xFFFFAB91); // Pastel Şeftali/Turuncu

const Color kYaziRengi = Color(0xFF5D4037); // Koyu Kahve

const Color kPasifRenk = Color(0xFFD7CCC8); // Açık Kahve/Gri

const Color kAktifYesil = Color(0xFFA5D6A7); // Pastel Yeşil

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('tr_TR', null);

  runApp(const NamazTakipApp());
}

class NamazTakipApp extends StatelessWidget {
  const NamazTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Namaz Vakti',

      theme: ThemeData(
        useMaterial3: true,

        scaffoldBackgroundColor: kArkaPlanRengi,

        primaryColor: kAnaRenk,

        colorScheme: ColorScheme.fromSeed(
          seedColor: kAnaRenk,

          surface: kArkaPlanRengi,
        ),

        fontFamily: 'Roboto', // Varsa özel font eklenebilir

        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: kYaziRengi),

          bodyLarge: TextStyle(color: kYaziRengi),

          displayLarge: TextStyle(color: kYaziRengi),
        ),
      ),

      home: const AnaUygulamaEkrani(),
    );
  }
}

// --- NAVİGASYON VE SAYFA YÖNETİMİ ---

class AnaUygulamaEkrani extends StatefulWidget {
  const AnaUygulamaEkrani({super.key});

  @override
  State<AnaUygulamaEkrani> createState() => _AnaUygulamaEkraniState();
}

class _AnaUygulamaEkraniState extends State<AnaUygulamaEkrani> {
  int _seciliSayfaIndex = 0;

  // Sayfalar listesi

  final List<Widget> _sayfalar = [
    const AnaSayfa(), // Ana kodumuz burada çalışacak

    const IstatistikSayfasi(), // Placeholder (Boş sayfa)

    const AyarlarSayfasi(), // Placeholder (Boş sayfa)
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _seciliSayfaIndex, children: _sayfalar),

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kKartRengi,

          boxShadow: [
            BoxShadow(
              color: Colors.brown.withOpacity(0.1),

              blurRadius: 20,

              offset: const Offset(0, -5),
            ),
          ],
        ),

        child: BottomNavigationBar(
          backgroundColor: Colors.transparent,

          elevation: 0,

          currentIndex: _seciliSayfaIndex,

          selectedItemColor: kAnaRenk,

          unselectedItemColor: kPasifRenk,

          showUnselectedLabels: false,

          type: BottomNavigationBarType.fixed,

          onTap: (index) {
            setState(() {
              _seciliSayfaIndex = index;
            });
          },

          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),

              label: 'Ana Sayfa',
            ),

            BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart_rounded),

              label: 'İstatistik',
            ),

            BottomNavigationBarItem(
              icon: Icon(Icons.settings_rounded),

              label: 'Ayarlar',
            ),
          ],
        ),
      ),
    );
  }
}

// --- ANA SAYFA (Mantık ve Yeni Tasarım) ---

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  // --- MANTIK DEĞİŞKENLERİ (Aynen korundu) ---

  Map<String, String>? _vakitler;

  String _aktifVakit = "Sabah";

  String _kalanSure = "--:--:--";

  String _ekranTarihi = "";

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

  // --- MANTIK FONKSİYONLARI (Önceki koddan aynen alındı) ---

  Future<void> _uygulamayiBaslat() async {
    await _loadData();

    await _konumVeApiIstegi();
  }

  Future<void> _konumVeApiIstegi() async {
    setState(() {
      _isLoading = true;

      _hataMesaji = "";
    });

    try {
      Position position = await _getGeoLocation();

      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings?latitude=${position.latitude}&longitude=${position.longitude}&method=13',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data']['timings'];

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

        _sabahVaktiSifirlamaKontrolu();

        _ilkVakitHesapla();

        _sayaciBaslat();
      } else {
        throw Exception("API Hatası");
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _isLoading = false;

          _hataMesaji = "Bağlantı hatası.";
        });
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();

    final simdi = DateTime.now();

    if (mounted) {
      setState(() {
        _ekranTarihi = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(simdi);

        _streakCount = prefs.getInt('streakCount') ?? 0;

        _sonSifirlamaTarihi = prefs.getString('lastResetDate') ?? "";

        for (var vkt in _vakitIsimleri) {
          kildiMi[vkt] = prefs.getBool('kildi_$vkt') ?? false;
        }
      });
    }
  }

  Future<void> _saveKildiMi() async {
    final prefs = await SharedPreferences.getInstance();

    kildiMi.forEach((key, value) => prefs.setBool('kildi_$key', value));
  }

  Future<void> _kutucuklariSifirla(String bugunStr) async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      kildiMi.updateAll((key, value) => false);

      _sonSifirlamaTarihi = bugunStr;
    });

    // Disk üzerindeki tüm kildi_ verilerini temizle

    for (var vkt in _vakitIsimleri) {
      await prefs.setBool('kildi_$vkt', false);
    }

    await prefs.setString('lastResetDate', bugunStr);
  }

  Future<Position> _getGeoLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) return Future.error('Servis kapalı');

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied)
        return Future.error('İzin yok');
    }

    return await Geolocator.getCurrentPosition();
  }

  void _sabahVaktiSifirlamaKontrolu() {
    if (_vakitler == null) return;

    final simdi = DateTime.now();

    final bugunTarihStr = DateFormat('yyyy-MM-dd').format(simdi);

    // Eğer son sıfırlama tarihi bugünden farklıysa (Uygulamaya yeni bir günde girilmişse)

    if (_sonSifirlamaTarihi != bugunTarihStr) {
      // Önceki günden kalan kılınmayan namaz var mı kontrolü (Seri koruma mantığı)

      // Eğer kullanıcı en son girdiğinde tüm vakitleri kılmadıysa seriyi boz

      // (Not: Bu kısmı tercihe göre ekleyebilirsin, aşağıda genel sıfırlama var)

      _kutucuklariSifirla(bugunTarihStr);

      // Eğer arada 1 günden fazla boşluk varsa seriyi de sıfırla

      if (_sonSifirlamaTarihi.isNotEmpty) {
        DateTime sonGiris = DateTime.parse(_sonSifirlamaTarihi);

        int gunFarki = simdi.difference(sonGiris).inDays;

        if (gunFarki > 1) {
          _streakSifirla(); // 1 günden fazla girmemişse seri bozulur
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
        var vkt = _parseTime(_vakitler![_vakitIsimleri[i]]!);

        if (simdi.isBefore(vkt)) {
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

      if (mounted) {
        setState(
          () => _ekranTarihi = DateFormat(
            'dd MMMM yyyy, EEEE',

            'tr_TR',
          ).format(simdi),
        );
      }

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

      if (bitisZamani == null) {
        bitisZamani = sabahVakti.add(const Duration(days: 1));

        bulunanVakit = "Yatsı";
      }

      if (_aktifVakit != bulunanVakit) {
        bool oncekiKilindi = kildiMi[_aktifVakit] ?? false;

        if (!oncekiKilindi) _streakSifirla();

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
      if (artir)
        _streakCount++;
      else if (_streakCount > 0)
        _streakCount--;
    });

    prefs.setInt('streakCount', _streakCount);
  }

  // --- YENİ UI TASARIMI (BUILD) ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: kAnaRenk));
    }

    if (_hataMesaji.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Text(_hataMesaji, style: const TextStyle(color: kYaziRengi)),

            TextButton(
              onPressed: _konumVeApiIstegi,

              child: const Text(
                "Tekrar Dene",

                style: TextStyle(color: kAnaRenk),
              ),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(20.0),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,

          children: [
            // 1. HEADER (STREAK & TARİH KARTI)
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
                          fontSize: 18,

                          fontWeight: FontWeight.bold,

                          color: kYaziRengi,
                        ),
                      ),

                      Text(
                        _ekranTarihi.split(',').length > 1
                            ? _ekranTarihi.split(',')[1].trim()
                            : "",

                        style: TextStyle(
                          fontSize: 14,

                          color: kYaziRengi.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,

                      vertical: 8,
                    ),

                    decoration: BoxDecoration(
                      color: kAnaRenk.withOpacity(0.2),

                      borderRadius: BorderRadius.circular(20),
                    ),

                    child: Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,

                          color: kAnaRenk,

                          size: 24,
                        ),

                        const SizedBox(width: 5),

                        Text(
                          "$_streakCount",

                          style: const TextStyle(
                            fontSize: 18,

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

            // 2. ORTA VİTRİN (SAAT & AKTİF VAKİT)
            Expanded(
              flex: 3,

              child: Container(
                decoration: _sikKutuDecoration().copyWith(
                  gradient: LinearGradient(
                    colors: [kKartRengi, kArkaPlanRengi],

                    begin: Alignment.topLeft,

                    end: Alignment.bottomRight,
                  ),
                ),

                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,

                  children: [
                    Text(
                      _aktifVakit.toUpperCase(),

                      style: const TextStyle(
                        fontSize: 24,

                        letterSpacing: 4,

                        color: kAnaRenk,

                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Text(
                      DateFormat("HH:mm").format(DateTime.now()),

                      style: const TextStyle(
                        fontSize: 70,

                        fontWeight: FontWeight.bold,

                        color: kYaziRengi,
                      ),
                    ),

                    const SizedBox(height: 10),

                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,

                        vertical: 6,
                      ),

                      decoration: BoxDecoration(
                        color: kYaziRengi.withOpacity(0.05),

                        borderRadius: BorderRadius.circular(10),
                      ),

                      child: Text(
                        "Kalan Süre: $_kalanSure",

                        style: TextStyle(
                          fontSize: 16,

                          color: kYaziRengi.withOpacity(0.7),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // 3. VAKİT KUTUCUKLARI (Yatay Liste)
            Container(
              height: 120, // Padding ve yeni yapı için biraz artırdık

              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),

              decoration: _sikKutuDecoration(),

              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,

                children: [
                  _vakitKutusu(
                    "Sabah",

                    Icons.wb_twilight,

                    _vakitler!["Sabah"]!,
                  ),

                  _vakitKutusu("Öğle", Icons.wb_sunny, _vakitler!["Öğle"]!),

                  _vakitKutusu(
                    "İkindi",

                    Icons.wb_cloudy,

                    _vakitler!["İkindi"]!,
                  ),

                  _vakitKutusu(
                    "Akşam",

                    Icons.nights_stay,

                    _vakitler!["Akşam"]!,
                  ),

                  _vakitKutusu("Yatsı", Icons.bedtime, _vakitler!["Yatsı"]!),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // 4. ALT AKSİYON (BUTON)
            Expanded(
              flex: 2,

              child: _AnimatedPrayerButton(
                isDone: kildiMi[_aktifVakit] ?? false,

                onTap: () {
                  setState(() {
                    bool yeniDurum = !(kildiMi[_aktifVakit] ?? false);

                    kildiMi[_aktifVakit] = yeniDurum;

                    _saveKildiMi();

                    _streakIslem(yeniDurum);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Yardımcı UI Metodları

  BoxDecoration _sikKutuDecoration() {
    return BoxDecoration(
      color: kKartRengi,

      borderRadius: BorderRadius.circular(25),

      boxShadow: [
        BoxShadow(
          color: kYaziRengi.withOpacity(0.05),

          blurRadius: 15,

          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  Widget _vakitKutusu(String ad, IconData ikon, String saat) {
    bool kildi = kildiMi[ad] ?? false;

    bool suan = _aktifVakit == ad;

    String temizSaat = saat.split(" ")[0];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),

      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),

      decoration: BoxDecoration(
        // Aktif vakitse arka planı renklendir, değilse şeffaf bırak
        color: suan
            ? const Color.fromARGB(255, 122, 185, 112).withOpacity(0.2)
            : Colors.transparent,

        borderRadius: BorderRadius.circular(15),
      ),

      child: Column(
        mainAxisSize: MainAxisSize.min, // İçeriğe göre daralması için

        mainAxisAlignment: MainAxisAlignment.center,

        children: [
          Icon(
            ikon,

            size: 26,

            color: kildi ? kAktifYesil : (suan ? kAnaRenk : kPasifRenk),
          ),

          const SizedBox(height: 6),

          Text(
            temizSaat,

            style: TextStyle(
              fontSize: 13,

              fontWeight: suan ? FontWeight.bold : FontWeight.w500,

              color: suan ? kYaziRengi : kYaziRengi.withOpacity(0.5),
            ),
          ),

          const SizedBox(height: 2),

          Text(
            ad,

            style: TextStyle(
              fontSize: 10,

              color: suan
                  ? const Color.fromRGBO(93, 64, 55, 50)
                  : Colors.transparent, // Sadece aktifse ismi göster/vurgula

              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

// --- PLACEHOLDER SAYFALAR (Navigasyon Testi İçin) ---

class IstatistikSayfasi extends StatelessWidget {
  const IstatistikSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "İstatistikler Yakında...",

        style: TextStyle(color: kYaziRengi, fontSize: 20),
      ),
    );
  }
}

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        "Ayarlar Yakında...",

        style: TextStyle(color: kYaziRengi, fontSize: 20),
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

      upperBound: 0.1, // %10 küçülme efekti
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(_controller);
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

          curve: Curves.easeInOut,

          decoration: BoxDecoration(
            color: widget.isDone ? kAktifYesil : kKartRengi,

            borderRadius: BorderRadius.circular(25),

            boxShadow: [
              BoxShadow(
                color: widget.isDone
                    ? kAktifYesil.withOpacity(0.4)
                    : kYaziRengi.withOpacity(0.05),

                blurRadius: 15,

                offset: const Offset(0, 8),
              ),
            ],
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              // Yuvarlak İkon Alanı
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),

                width: 65,

                height: 65,

                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  color: kArkaPlanRengi,

                  border: Border.all(
                    color: widget.isDone ? Colors.white : kPasifRenk,

                    width: 3,
                  ),
                ),

                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),

                  child: Icon(
                    Icons.check_rounded,

                    key: ValueKey<bool>(widget.isDone),

                    size: 35,

                    color: widget.isDone ? kAktifYesil : kPasifRenk,
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Text(
                widget.isDone
                    ? "Allah Kabul Etsin!"
                    : "Vakti Kıldım Olarak İşaretle",

                textAlign: TextAlign.center,

                style: TextStyle(
                  fontSize: 16,

                  fontWeight: FontWeight.bold,

                  color: widget.isDone ? Colors.white : kYaziRengi,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
