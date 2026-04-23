import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../services/notification_service.dart';
import '../services/firebase_service.dart';
import '../providers/namaz_provider.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onComplete;
  const OnboardingScreen({super.key, required this.onComplete});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Animasyonlar
  late AnimationController _iconController;
  late AnimationController _fadeController;
  late Animation<double> _iconScale;
  late Animation<double> _iconRotation;
  late Animation<double> _fadeAnim;

  // İzin durumları
  bool _locationGranted = false;
  bool _notificationGranted = false;
  bool _requestingPermission = false;

  @override
  void initState() {
    super.initState();
    _iconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _iconScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _iconController, curve: const Interval(0.0, 0.6, curve: Curves.elasticOut)),
    );
    _iconRotation = Tween<double>(begin: -0.1, end: 0.0).animate(
      CurvedAnimation(parent: _iconController, curve: const Interval(0.0, 0.5, curve: Curves.easeOut)),
    );

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);

    _iconController.forward();
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _iconController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _goToPage(int page) {
    _pageController.animateToPage(
      page,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeInOutCubic,
    );
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    // Her sayfa değiştiğinde animasyonları tekrar oynat
    _iconController.reset();
    _fadeController.reset();
    _iconController.forward();
    _fadeController.forward();
  }

  Future<void> _requestLocationPermission() async {
    setState(() => _requestingPermission = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum servisi kapalı. Lütfen ayarlardan açın.')),
          );
        }
        setState(() => _requestingPermission = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
        setState(() => _locationGranted = true);
      }
    } catch (_) {}
    setState(() => _requestingPermission = false);
  }

  Future<void> _requestNotificationPermission() async {
    setState(() => _requestingPermission = true);
    try {
      // 1. Yerel Bildirim İzinleri (Vakitler vb. için)
      final notifService = NotificationService();
      await notifService.init();
      await notifService.requestPermissions();

      // 2. Firebase (FCM) Bildirim İzinleri (Sosyal bildirimler için)
      final provider = context.read<NamazProvider>();
      if (provider.currentUid != null) {
        final fbService = FirebaseService();
        await fbService.requestMessagingPermission(provider.currentUid!);
      }

      setState(() => _notificationGranted = true);
    } catch (_) {}
    setState(() => _requestingPermission = false);
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      body: SafeArea(
        child: Column(
          children: [
            // Üst Çizgi İlerleme
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(24),
                vertical: Responsive.h(16),
              ),
              child: Row(
                children: List.generate(4, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: EdgeInsets.symmetric(horizontal: Responsive.w(3)),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        color: index <= _currentPage
                            ? r.anaRenk
                            : r.pasifRenk.withOpacity(0.25),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // Sayfa İçeriği
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: [
                  _buildVizyonPage(r),
                  _buildSeviyePage(r),
                  _buildSosyalPage(r),
                  _buildHazirlikPage(r),
                ],
              ),
            ),

            // Alt Butonlar
            Padding(
              padding: EdgeInsets.fromLTRB(
                Responsive.w(24),
                Responsive.h(8),
                Responsive.w(24),
                Responsive.h(24),
              ),
              child: _currentPage < 3
                  ? Row(
                      children: [
                        if (_currentPage > 0)
                          TextButton(
                            onPressed: () => _goToPage(_currentPage - 1),
                            child: Text(
                              "Geri",
                              style: TextStyle(
                                color: r.pasifRenk,
                                fontWeight: FontWeight.w600,
                                fontSize: Responsive.sp(14),
                              ),
                            ),
                          ),
                        const Spacer(),
                        _buildNextButton(r),
                      ],
                    )
                  : _buildStartButton(r),
            ),
          ],
        ),
      ),
    );
  }

  // ═══════════════════════════════════════════
  // SAYFA 1: VİZYON
  // ═══════════════════════════════════════════

  Widget _buildVizyonPage(AppThemeColors r) {
    return _buildPageLayout(
      r: r,
      icon: Icons.mosque_rounded,
      iconGradient: [r.anaRenk, r.anaRenk.withOpacity(0.6)],
      title: "Takva Yolu'na\nHoş Geldin!",
      description:
          "Sadece namaz vakitleri değil; gönül kardeşlerinle buluştuğun dijital dünyaya adım attın.",
      decorationWidget: _buildFloatingParticles(r),
    );
  }

  // ═══════════════════════════════════════════
  // SAYFA 2: SEVİYE SİSTEMİ
  // ═══════════════════════════════════════════

  Widget _buildSeviyePage(AppThemeColors r) {
    return _buildPageLayout(
      r: r,
      icon: Icons.auto_awesome_rounded,
      iconGradient: [const Color(0xFFFFD54F), const Color(0xFFFFA726)],
      title: "Kendi Takva\nYolculuğun",
      description:
          "Namazlarını kıldıkça XP kazan, Talip'likten\nSüreyya makamına manevi bir yolculuğa çık.",
      decorationWidget: _buildXpBar(r),
    );
  }

  // ═══════════════════════════════════════════
  // SAYFA 3: SOSYAL
  // ═══════════════════════════════════════════

  Widget _buildSosyalPage(AppThemeColors r) {
    return _buildPageLayout(
      r: r,
      icon: Icons.volunteer_activism_rounded,
      iconGradient: [const Color(0xFFE91E63), const Color(0xFFFF5252)],
      title: "Dua ile\nGönül Birliği",
      description:
          "Meclis akışında dua paylaş, dostlarının dualarına \"Amîn\" diyerek manevi desteğini hissettir.",
      decorationWidget: _buildAminPreview(r),
    );
  }

  // ═══════════════════════════════════════════
  // SAYFA 4: HAZIRLIK (İZİNLER)
  // ═══════════════════════════════════════════

  Widget _buildHazirlikPage(AppThemeColors r) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(28)),
      child: Column(
        children: [
          SizedBox(height: Responsive.h(30)),

          // Animasyonlu İkon
          ScaleTransition(
            scale: _iconScale,
            child: RotationTransition(
              turns: _iconRotation,
              child: Container(
                width: Responsive.w(110),
                height: Responsive.w(110),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [r.aktifYesil, r.aktifYesil.withOpacity(0.6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: r.aktifYesil.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.location_on_rounded,
                  color: Colors.white,
                  size: Responsive.w(50),
                ),
              ),
            ),
          ),

          SizedBox(height: Responsive.h(32)),

          // Başlık
          FadeTransition(
            opacity: _fadeAnim,
            child: Text(
              "Yolculuğa\nHazır Mısın?",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: r.yaziRengi,
                fontWeight: FontWeight.w900,
                fontSize: Responsive.sp(28),
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
          ),

          SizedBox(height: Responsive.h(12)),

          FadeTransition(
            opacity: _fadeAnim,
            child: Text(
              "Vakitlerin doğru hesaplanması ve hiçbir anı kaçırmaman için konum ve bildirim iznine ihtiyacımız var.",
              textAlign: TextAlign.center,
              style: TextStyle(
                color: r.yaziRengi.withOpacity(0.55),
                fontSize: Responsive.sp(14),
                height: 1.6,
              ),
            ),
          ),

          SizedBox(height: Responsive.h(36)),

          // Konum İzni Kartı
          _buildPermissionCard(
            r: r,
            icon: Icons.location_on_rounded,
            title: "Konum İzni",
            description: "Namaz vakitlerini konumuna göre doğru hesaplamak için gerekli.",
            isGranted: _locationGranted,
            onRequest: _requestLocationPermission,
          ),

          SizedBox(height: Responsive.h(14)),

          // Bildirim İzni Kartı
          _buildPermissionCard(
            r: r,
            icon: Icons.notifications_active_rounded,
            title: "Bildirim İzni",
            description: "Namaz vakitlerinden önce ve manevi hatırlatıcılar için bildirim gönderelim.",
            isGranted: _notificationGranted,
            onRequest: _requestNotificationPermission,
          ),

          SizedBox(height: Responsive.h(20)),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════
  // YARDIMCI WİDGETLAR
  // ═══════════════════════════════════════════

  Widget _buildPageLayout({
    required AppThemeColors r,
    required IconData icon,
    required List<Color> iconGradient,
    required String title,
    required String description,
    Widget? decorationWidget,
  }) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(28)),
      child: Column(
        children: [
          SizedBox(height: Responsive.h(50)),

          // Animasyonlu Büyük İkon
          ScaleTransition(
            scale: _iconScale,
            child: RotationTransition(
              turns: _iconRotation,
              child: Container(
                width: Responsive.w(110),
                height: Responsive.w(110),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: iconGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconGradient[0].withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: Colors.white, size: Responsive.w(50)),
              ),
            ),
          ),

          SizedBox(height: Responsive.h(36)),

          // Başlık
          FadeTransition(
            opacity: _fadeAnim,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: r.yaziRengi,
                fontWeight: FontWeight.w900,
                fontSize: Responsive.sp(28),
                height: 1.15,
                letterSpacing: -0.5,
              ),
            ),
          ),

          SizedBox(height: Responsive.h(16)),

          // Açıklama
          FadeTransition(
            opacity: _fadeAnim,
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: r.yaziRengi.withOpacity(0.55),
                fontSize: Responsive.sp(14),
                height: 1.6,
              ),
            ),
          ),

          SizedBox(height: Responsive.h(40)),

          // Dekoratif Widget
          if (decorationWidget != null)
            FadeTransition(opacity: _fadeAnim, child: decorationWidget),
        ],
      ),
    );
  }

  Widget _buildPermissionCard({
    required AppThemeColors r,
    required IconData icon,
    required String title,
    required String description,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(18)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isGranted ? r.aktifYesil.withOpacity(0.4) : r.pasifRenk.withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // İkon
          Container(
            width: Responsive.w(48),
            height: Responsive.w(48),
            decoration: BoxDecoration(
              color: isGranted
                  ? r.aktifYesil.withOpacity(0.1)
                  : r.anaRenk.withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              isGranted ? Icons.check_circle_rounded : icon,
              color: isGranted ? r.aktifYesil : r.anaRenk,
              size: 24,
            ),
          ),

          SizedBox(width: Responsive.w(14)),

          // Metin
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: r.yaziRengi,
                    fontWeight: FontWeight.w700,
                    fontSize: Responsive.sp(14),
                  ),
                ),
                SizedBox(height: Responsive.h(4)),
                Text(
                  description,
                  style: TextStyle(
                    color: r.yaziRengi.withOpacity(0.5),
                    fontSize: Responsive.sp(11),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),

          SizedBox(width: Responsive.w(8)),

          // Buton
          if (!isGranted)
            SizedBox(
              height: 36,
              child: ElevatedButton(
                onPressed: _requestingPermission ? null : onRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: r.anaRenk,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(14)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _requestingPermission
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        "İzin Ver",
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: Responsive.sp(12),
                        ),
                      ),
              ),
            )
          else
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(10),
                vertical: Responsive.h(6),
              ),
              decoration: BoxDecoration(
                color: r.aktifYesil.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                "Aktif ✓",
                style: TextStyle(
                  color: r.aktifYesil,
                  fontWeight: FontWeight.w700,
                  fontSize: Responsive.sp(11),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // İleri Butonu
  Widget _buildNextButton(AppThemeColors r) {
    return SizedBox(
      height: Responsive.h(52),
      child: ElevatedButton(
        onPressed: () => _goToPage(_currentPage + 1),
        style: ElevatedButton.styleFrom(
          backgroundColor: r.anaRenk,
          elevation: 0,
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(32)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Devam",
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: Responsive.sp(15),
              ),
            ),
            SizedBox(width: Responsive.w(8)),
            const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }

  // Başla Butonu
  Widget _buildStartButton(AppThemeColors r) {
    final allGranted = _locationGranted && _notificationGranted;

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: Responsive.h(56),
          child: ElevatedButton(
            onPressed: _completeOnboarding,
            style: ElevatedButton.styleFrom(
              backgroundColor: allGranted ? r.aktifYesil : r.anaRenk,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  allGranted ? Icons.check_circle_rounded : Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 22,
                ),
                SizedBox(width: Responsive.w(10)),
                Text(
                  allGranted ? "Başlayalım!" : "Şimdilik Atla",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.sp(16),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!allGranted) ...[
          SizedBox(height: Responsive.h(8)),
          Text(
            "İzinleri daha sonra ayarlardan da verebilirsiniz.",
            style: TextStyle(
              color: r.pasifRenk,
              fontSize: Responsive.sp(11),
            ),
          ),
        ],
      ],
    );
  }

  // ═══════════════════════════════════════════
  // DEKORATİF WİDGETLAR
  // ═══════════════════════════════════════════

  // Sayfa 1: Parlayan parçacıklar (vizyon)
  Widget _buildFloatingParticles(AppThemeColors r) {
    return SizedBox(
      height: Responsive.h(120),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Üç yüzen hilâl-yıldız
          for (int i = 0; i < 5; i++)
            Positioned(
              left: Responsive.w(30 + (i * 55).toDouble()),
              top: Responsive.h(10 + (i * 18).toDouble()),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: Duration(milliseconds: 800 + i * 200),
                curve: Curves.easeOutBack,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, (1 - value) * 20),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: Icon(
                        [Icons.star_rounded, Icons.auto_awesome, Icons.star_border_rounded, Icons.nightlight_round, Icons.auto_awesome][i],
                        color: r.anaRenk.withOpacity(0.15 + i * 0.08),
                        size: Responsive.w(22 + i * 4),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // Sayfa 2: Seviye ilerleme çubuğu
  Widget _buildXpBar(AppThemeColors r) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(20)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: Responsive.w(10),
                  vertical: Responsive.h(5),
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFD54F).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "⭐ Talip",
                  style: TextStyle(
                    color: const Color(0xFFFFA726),
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.sp(12),
                  ),
                ),
              ),
              const Spacer(),
              Text(
                "150 / 500 XP",
                style: TextStyle(
                  color: r.pasifRenk,
                  fontSize: Responsive.sp(11),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),
          // Kendi animasyonlu ilerleme çubuğu
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 0.3),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: value,
                  minHeight: 10,
                  backgroundColor: r.pasifRenk.withOpacity(0.15),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFFFA726)),
                ),
              );
            },
          ),
          SizedBox(height: Responsive.h(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildMiniStat(r, "Namaz", "+25 XP", Icons.mosque_rounded),
              _buildMiniStat(r, "Zikir", "+10 XP", Icons.circle_outlined),
              _buildMiniStat(r, "Dua", "+5 XP", Icons.volunteer_activism_rounded),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(AppThemeColors r, String label, String xp, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: r.anaRenk.withOpacity(0.6), size: 18),
        SizedBox(height: Responsive.h(4)),
        Text(label, style: TextStyle(color: r.yaziRengi.withOpacity(0.6), fontSize: Responsive.sp(10), fontWeight: FontWeight.w600)),
        Text(xp, style: TextStyle(color: r.aktifYesil, fontSize: Responsive.sp(10), fontWeight: FontWeight.w800)),
      ],
    );
  }

  // Sayfa 3: Amîn ön izleme kartı
  Widget _buildAminPreview(AppThemeColors r) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(18)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dua kartı header
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: r.anaRenk.withOpacity(0.1),
                child: Text("A", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
              ),
              SizedBox(width: Responsive.w(10)),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Bir Kardeşin", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w700, fontSize: Responsive.sp(13))),
                  Text("2 dk önce", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10))),
                ],
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),
          Text(
            "\"Ya Rabbi, ümmeti Muhammed'e şifa ver, dertlerine derman eyle...\"",
            style: TextStyle(
              color: r.yaziRengi.withOpacity(0.7),
              fontSize: Responsive.sp(13),
              fontStyle: FontStyle.italic,
              height: 1.5,
            ),
          ),
          SizedBox(height: Responsive.h(14)),
          // Amîn butonu (animasyonlu)
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.scale(
                scale: value.clamp(0.0, 1.0),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Responsive.w(14),
                        vertical: Responsive.h(8),
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 18),
                          SizedBox(width: Responsive.w(6)),
                          Text(
                            "Amîn · 12",
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w700,
                              fontSize: Responsive.sp(12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
