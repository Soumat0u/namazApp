import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'core/utils/responsive.dart';

import 'services/namaz_servis.dart';
import 'services/notification_service.dart';
import 'services/firebase_service.dart';
import 'providers/namaz_provider.dart';
import 'providers/theme_provider.dart';
import 'views/ana_sayfa.dart';
import 'views/statistics_screen.dart';
import 'views/social_screen.dart';
import 'views/auth_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  // 🔥 Firebase'i başlat
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Servisleri Kur
  final namazServisi = NamazServisi();
  final notificationService = NotificationService();
  final firebaseService = FirebaseService();
  await notificationService.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => NamazProvider(namazServisi, notificationService, firebaseService),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ],
      child: const NamazTakipApp(),
    ),
  );
}

class NamazTakipApp extends StatelessWidget {
  const NamazTakipApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Namaz Vakti',
      theme: themeProvider.buildThemeData(),
      home: const _AuthGate(),
    );
  }
}

/// Auth durumuna göre AuthScreen veya AnaUygulamaEkrani gösterir
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NamazProvider>();

    // Profil oluşturulmamışsa auth ekranını göster
    if (provider.needsProfile) {
      return const AuthScreen();
    }

    return const AnaUygulamaEkrani();
  }
}

class AnaUygulamaEkrani extends StatefulWidget {
  const AnaUygulamaEkrani({super.key});
  @override
  State<AnaUygulamaEkrani> createState() => _AnaUygulamaEkraniState();
}

class _AnaUygulamaEkraniState extends State<AnaUygulamaEkrani> {
  int _seciliSayfaIndex = 0;

  final List<Widget> _sayfalar = [
    const AnaSayfa(),
    const IstatistikSayfasi(),
    const SosyalSayfasi(),
  ];

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final tema = context.watch<ThemeProvider>().aktifTema;

    return Scaffold(
      body: IndexedStack(index: _seciliSayfaIndex, children: _sayfalar),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: tema.kartRengi,
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
          selectedItemColor: tema.anaRenk,
          unselectedItemColor: tema.pasifRenk,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          iconSize: Responsive.w(22),
          selectedFontSize: Responsive.sp(11),
          unselectedFontSize: Responsive.sp(10),
          onTap: (index) => setState(() => _seciliSayfaIndex = index),
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
              icon: Icon(Icons.people_alt_rounded),
              label: 'Sosyal',
            ),
          ],
        ),
      ),
    );
  }
}
