// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

// Sayfalarımızı "views" klasöründen çekiyoruz
import 'views/ana_sayfa.dart';
import 'views/statistics_screen.dart'; // Bu dosyayı oluşturduğunu varsayıyorum
import 'views/settings_screen.dart'; // Bu dosyayı oluşturduğunu varsayıyorum

// --- RENK PALETİ ---
// (Not: İleride bunları lib/constants.dart içine taşıyıp her yerden oradan çekebilirsin)
const Color kArkaPlanRengi = Color(0xFFFFFDF5);
const Color kKartRengi = Color(0xFFFFFFFF);
const Color kAnaRenk = Color(0xFFE67E22);
const Color kYaziRengi = Color(0xFF3E2723);
const Color kPasifRenk = Color(0xFFBCAAA4);
const Color kAktifYesil = Color(0xFF2E7D32);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Tarih formatını başlat
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
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: kYaziRengi, fontSize: 16),
          bodyLarge: TextStyle(
            color: kYaziRengi,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          displayLarge: TextStyle(
            color: kYaziRengi,
            fontWeight: FontWeight.bold,
          ),
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

  // Sayfaları burada listeliyoruz
  final List<Widget> _sayfalar = [
    const AnaSayfa(),
    const IstatistikSayfasi(), // views/istatistik_sayfasi.dart dosyasından gelir
    const AyarlarSayfasi(), // views/ayarlar_sayfasi.dart dosyasından gelir
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack, sayfalar arası geçişte durumu (state) korur
      body: IndexedStack(index: _seciliSayfaIndex, children: _sayfalar),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: kKartRengi,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
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
          iconSize: 30,
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
