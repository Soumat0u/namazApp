import 'views/widgets/cinsiyet_secici.dart';
import 'views/widgets/sayfa_arka_plani.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
import 'views/onboarding_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('tr_TR', null);

  // 🔥 Firebase'i başlat
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Servisleri Kur
  final namazServisi = NamazServisi();
  final notificationService = NotificationService();
  final firebaseService = FirebaseService();
  await notificationService.init();

  // 🔔 PUSH BİLDİRİMLERİ: açıkken göster, dokununca ilgili sekmeyi aç
  try {
    FirebaseMessaging.onMessage.listen((mesaj) {
      final n = mesaj.notification;
      if (n == null) return;
      notificationService.anlikGoster(
        title: n.title ?? '',
        body: n.body ?? '',
        sekme: mesaj.data['sekme'] ?? 'sosyal',
      );
    });
    FirebaseMessaging.onMessageOpenedApp.listen((mesaj) {
      NotificationService.acilacakSekme.value = mesaj.data['sekme'] ?? 'sosyal';
    });
    final ilk = await FirebaseMessaging.instance.getInitialMessage();
    if (ilk != null)
      NotificationService.acilacakSekme.value = ilk.data['sekme'] ?? 'sosyal';
  } catch (e) {
    debugPrint('🔔 Push dinleyici hatası: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) =>
              NamazProvider(namazServisi, notificationService, firebaseService),
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
      title: 'Takva Yolum',
      theme: themeProvider.buildThemeData(),
      home: const _AuthGate(),
    );
  }
}

/// Auth durumuna göre Onboarding -> AuthScreen veya AnaUygulamaEkrani gösterir
class _AuthGate extends StatefulWidget {
  const _AuthGate();

  @override
  State<_AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<_AuthGate> {
  bool? _onboardingCompleted;

  @override
  void initState() {
    super.initState();
    _checkOnboarding();
  }

  Future<void> _checkOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _onboardingCompleted = prefs.getBool('onboarding_completed') ?? false;
    });
  }

  void _onOnboardingComplete() {
    setState(() => _onboardingCompleted = true);
    // Onboarding bittiğinde konum ve vakitleri tazele
    context.read<NamazProvider>().konumVeApiIstegi(kullaniciTetikledi: true);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NamazProvider>();

    // Yükleniyor (Shared prefs + Firebase Auth kontrolü)
    if (_onboardingCompleted == null || !provider.isAuthReady) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // 1. Profil oluşturulmamışsa ÖNCE auth ekranını göster
    if (provider.needsProfile) {
      return const AuthScreen();
    }

    // Cinsiyeti bilinmeyen hesaplar (Google / eski sürüm) bir kez seçer
    if (provider.cinsiyetSorulmali) {
      return const CinsiyetSecimEkrani();
    }

    // 2. Giriş yapıldıktan sonra, onboarding tamamlanmamışsa göster
    if (!_onboardingCompleted!) {
      return OnboardingScreen(onComplete: _onOnboardingComplete);
    }

    // 3. Her şey tamamsa ana ekran
    return const AnaUygulamaEkrani();
  }
}

class AnaUygulamaEkrani extends StatefulWidget {
  const AnaUygulamaEkrani({super.key});
  @override
  State<AnaUygulamaEkrani> createState() => _AnaUygulamaEkraniState();
}

class _AnaUygulamaEkraniState extends State<AnaUygulamaEkrani>
    with WidgetsBindingObserver {
  int _seciliSayfaIndex = 0;
  final FirebaseService _firebaseService = FirebaseService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _updateStatus(true);
    NotificationService.acilacakSekme.addListener(_bildirimdenSekmeAc);
    WidgetsBinding.instance.addPostFrameCallback((_) => _bildirimdenSekmeAc());
  }

  /// Bildirime dokunulduysa ilgili sekmeye geç ('ana' → 0, 'sosyal' → 2)
  void _bildirimdenSekmeAc() {
    final sekme = NotificationService.acilacakSekme.value;
    if (sekme == null || !mounted) return;
    NotificationService.acilacakSekme.value = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _seciliSayfaIndex = sekme == 'sosyal' ? 2 : 0);
  }

  @override
  void dispose() {
    NotificationService.acilacakSekme.removeListener(_bildirimdenSekmeAc);
    WidgetsBinding.instance.removeObserver(this);
    _updateStatus(false);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateStatus(true);
    } else {
      _updateStatus(false);
    }
  }

  void _updateStatus(bool isOnline) {
    final provider = context.read<NamazProvider>();
    if (provider.currentUid != null) {
      _firebaseService.setUserStatus(provider.currentUid!, isOnline);
    }
  }

  final List<Widget> _sayfalar = [
    const AnaSayfa(),
    const IstatistikSayfasi(),
    const SosyalSayfasi(),
  ];

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final temaProvider = context.watch<ThemeProvider>();
    final tema = temaProvider.aktifTema;
    final vakitTemasi = context.select<NamazProvider, String>(
      (p) => p.vaktinTemasi,
    );

    return Scaffold(
      // Yüzen alt menü: arka plan menünün çevresinden görünür
      extendBody: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Seçilen arka plan modu (sayfaların zemini şeffaf)
          SayfaArkaPlani(
            mod: temaProvider.arkaPlanModu,
            vakitTemasi: vakitTemasi,
            zemin: tema.arkaPlanRengi,
            koyuTema: tema.brightness == Brightness.dark,
          ),
          // İçerik menünün altına girmesin: menü yüksekliği kadar boşluk bırakılır
          Builder(
            builder: (context) => Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom,
              ),
              child: MediaQuery.removePadding(
                context: context,
                removeBottom: true,
                child: IndexedStack(
                  index: _seciliSayfaIndex,
                  children: _sayfalar,
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: EdgeInsets.fromLTRB(
            Responsive.w(16),
            0,
            Responsive.w(16),
            Responsive.h(10),
          ),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: tema.kartRengi,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: tema.anaRenk.withOpacity(0.12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.25),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          // Dokununca tüm menüye yayılan dalga/vurgu efekti kapalı
          child: Theme(
            data: Theme.of(context).copyWith(
              splashFactory: NoSplash.splashFactory,
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
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
        ),
      ),
    );
  }
}
