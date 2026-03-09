import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_colors.dart';
import 'services/namaz_servis.dart';
import 'services/bildirim_servisi.dart';
import 'providers/namaz_provider.dart';
import 'views/ana_sayfa.dart';
import 'views/statistics_screen.dart';
import 'views/settings_screen.dart';
import 'views/kaza_sayfasi.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  // Bildirim Servisini Başlat
  await BildirimServisi.init();

  // Dependency Injection Kurulumu
  final namazServisi = NamazServisi();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NamazProvider(namazServisi)),
      ],
      child: const NamazTakipApp(),
    ),
  );
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
        scaffoldBackgroundColor:
            AppColors.arkaPlanRengi, // Sabitlerden çekiliyor
        primaryColor: AppColors.anaRenk,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.anaRenk,
          surface: AppColors.arkaPlanRengi,
        ),
        fontFamily: 'Roboto',
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: AppColors.yaziRengi, fontSize: 16),
          bodyLarge: TextStyle(
            color: AppColors.yaziRengi,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          displayLarge: TextStyle(
            color: AppColors.yaziRengi,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      home: const AnaUygulamaEkrani(),
    );
  }
}

class AnaUygulamaEkrani extends StatefulWidget {
  const AnaUygulamaEkrani({super.key});
  @override
  State<AnaUygulamaEkrani> createState() => _AnaUygulamaEkraniState();
}

class _AnaUygulamaEkraniState extends State<AnaUygulamaEkrani> {
  int _seciliSayfaIndex = 0;

  // Sayfalar views klasöründeki dosyalardan geliyor
  final List<Widget> _sayfalar = [
    const AnaSayfa(),
    const KazaSayfasi(),
    const IstatistikSayfasi(),
    const AyarlarSayfasi(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack sayfa durumlarını korur
      body: IndexedStack(index: _seciliSayfaIndex, children: _sayfalar),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.kartRengi,
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
          selectedItemColor: AppColors.anaRenk,
          unselectedItemColor: AppColors.pasifRenk,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          iconSize: 26,
          onTap: (index) => setState(() => _seciliSayfaIndex = index),
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.home_rounded),
              label: 'Ana Sayfa',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.history_rounded),
              label: 'Kaza',
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
