import 'core/utils/bildirim.dart';
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
import 'services/updater.dart';
import 'providers/namaz_provider.dart';
import 'providers/theme_provider.dart';
import 'views/ana_sayfa.dart';
import 'views/statistics_screen.dart';
import 'views/social_screen.dart';
import 'views/auth_screen.dart';
import 'views/kuran_screen.dart';
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
        ChangeNotifierProvider(create: (_) => Updater()..check()),
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
      navigatorKey: Bildirim.navigatorKey, // üstten inen bildirimler (core/utils/bildirim.dart)
      debugShowCheckedModeBanner: false,
      title: 'Takva Yolum',
      theme: themeProvider.buildThemeData(),
      // Uygulama içi yazı boyutu, telefonun yazı boyutuyla çarpılır (toplam en fazla 2 kat)
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        final toplam = (mq.textScaler.scale(1) * themeProvider.yaziOlcegi).clamp(0.8, 2.0);
        return MediaQuery(
          data: mq.copyWith(textScaler: TextScaler.linear(toplam)),
          child: child!,
        );
      },
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

  /// Bildirime dokunulduysa ilgili yere git: 'ana' → 0. sekme, 'sosyal' → 2. sekme,
  /// `ayet:<sure>:<ayet>` → Kur'an'da o ayet
  void _bildirimdenSekmeAc() {
    final sekme = NotificationService.acilacakSekme.value;
    if (sekme == null || !mounted) return;
    NotificationService.acilacakSekme.value = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
    final ayet = RegExp(r'^ayet:(\d+):(\d+)$').firstMatch(sekme);
    if (ayet != null) {
      setState(() => _seciliSayfaIndex = 0);
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => KuranSureScreen(sure: int.parse(ayet.group(1)!), baslangicAyet: int.parse(ayet.group(2)!)),
      ));
      return;
    }
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
      context.read<Updater>().resumed();
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
            vurgu: tema.anaRenk,
            koyuTema: tema.brightness == Brightness.dark,
          ),
          // Sayfalar ekranın en altına kadar uzanır; içerik kaydırılınca yüzen
          // menünün arkasından geçer. extendBody sayesinde MediaQuery'nin alt
          // padding'i menü (+ güncelleme çubuğu) yüksekliğine eşittir; her sayfa
          // kaydırma içeriğinin sonuna bu kadar boşluk ekler.
          IndexedStack(
            index: _seciliSayfaIndex,
            children: _sayfalar,
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _GuncellemeCubugu(),
            Container(
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
              // Her sekme ayrı düğme: dokununca yalnızca basılan düğme hafifçe aydınlanır
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    for (final (i, ikon, ad) in const [
                      (0, Icons.home_rounded, 'Ana Sayfa'),
                      (1, Icons.bar_chart_rounded, 'İstatistik'),
                      (2, Icons.people_alt_rounded, 'Sosyal'),
                    ])
                      Expanded(
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(22),
                            // Dalga yok: basılıyken yalnızca hafif bir yuvarlak vurgu
                            splashFactory: NoSplash.splashFactory,
                            highlightColor: tema.anaRenk.withOpacity(0.08),
                            onTap: () {
                              if (_seciliSayfaIndex != i) setState(() => _seciliSayfaIndex = i);
                            },
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: Responsive.h(4)),
                              child: TweenAnimationBuilder<Color?>(
                                // Renk yumuşak geçer; boyut sabit kalır (yazı büyüyüp küçülünce ikonlar kıpırdıyordu)
                                tween: ColorTween(end: _seciliSayfaIndex == i ? tema.anaRenk : tema.pasifRenk),
                                duration: const Duration(milliseconds: 200),
                                builder: (_, renk, _) => Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(ikon, size: Responsive.w(22), color: renk),
                                    SizedBox(height: Responsive.h(1)),
                                    Text(
                                      ad,
                                      maxLines: 1,
                                      style: TextStyle(
                                        fontSize: Responsive.sp(11),
                                        height: 1.2,
                                        fontWeight: _seciliSayfaIndex == i ? FontWeight.w700 : FontWeight.w500,
                                        color: renk,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sunucuda yeni sürüm varsa alt menünün üstünde çıkan çubuk
class _GuncellemeCubugu extends StatelessWidget {
  const _GuncellemeCubugu();

  @override
  Widget build(BuildContext context) {
    final u = context.watch<Updater>();
    if (u.available == null) return const SizedBox.shrink();
    final tema = context.watch<ThemeProvider>().aktifTema;
    final String yazi;
    switch (u.step) {
      case UpdateStep.downloading:
        yazi = 'İndiriliyor… ${u.progress == null ? '' : '%${(u.progress! * 100).round()}'}';
      case UpdateStep.needsPermission:
        yazi = 'Ayarlardan "Bu kaynaktan izin ver"i açıp geri dönün';
      case UpdateStep.installing:
        yazi = 'Yükleyici açılıyor…';
      case UpdateStep.failed:
        yazi = 'Güncelleme olmadı: ${u.error}';
      case UpdateStep.idle:
        yazi = 'Yeni sürüm hazır: ${u.availableName ?? ''} (${u.available})'.replaceFirst(':  (', ': (');
    }
    final mesgul = u.step == UpdateStep.downloading || u.step == UpdateStep.installing;
    return Container(
      margin: EdgeInsets.fromLTRB(Responsive.w(16), 0, Responsive.w(16), Responsive.h(6)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: tema.anaRenk,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (u.step == UpdateStep.downloading)
            LinearProgressIndicator(
              value: u.progress,
              minHeight: 2,
              color: Colors.white,
              backgroundColor: Colors.white24,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 6, 2),
            child: Row(
              children: [
                const Icon(Icons.system_update_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(yazi, style: const TextStyle(color: Colors.white))),
                TextButton(
                  onPressed: mesgul ? null : u.update,
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  child: Text(u.step == UpdateStep.failed ? 'Tekrar dene' : 'Güncelle'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
