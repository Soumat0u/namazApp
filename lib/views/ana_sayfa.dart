import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../providers/theme_provider.dart';
import '../services/seviye_servisi.dart';

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();

    if (provider.isLoading && provider.vakitler == null) {
      return Center(
        child: CircularProgressIndicator(color: context.renkler.anaRenk),
      );
    }

    if (provider.hataMesaji.contains("çevrimdışı") &&
        provider.vakitler != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(provider.hataMesaji)));
        provider.hataMesaji = "";
      });
    }

    if (provider.vakitler == null && provider.hataMesaji.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
              child: Text(
                provider.hataMesaji,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.renkler.yaziRengi,
                  fontSize: Responsive.sp(16),
                ),
              ),
            ),
            SizedBox(height: Responsive.h(20)),
            ElevatedButton(
              onPressed: () => context.read<NamazProvider>().konumVeApiIstegi(
                kullaniciTetikledi: true,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.renkler.anaRenk,
                foregroundColor: Colors.white,
              ),
              child: const Text("Konum İzni Ver / Tekrar Dene"),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: context.renkler.anaRenk,
        backgroundColor: context.renkler.kartRengi,
        onRefresh: () => context.read<NamazProvider>().konumVeApiIstegi(
          kullaniciTetikledi: true,
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(Responsive.w(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLevelCard(context, provider),
                SizedBox(height: Responsive.h(16)),
                _buildHeader(context, provider),
                SizedBox(height: Responsive.h(16)),
                _buildMainClock(context, provider),
                SizedBox(height: Responsive.h(16)),
                _buildVakitGrid(context, provider),
                SizedBox(height: Responsive.h(16)),
                _buildPrayerButton(context, provider),
                SizedBox(height: Responsive.h(10)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥 XP BARI VE SEVİYE KARTI
Widget _buildLevelCard(BuildContext context, NamazProvider provider) {
  final r = context.renkler; // Güvenli renk okuması (build içinde)
  
  return InkWell(
    // 🔥 ÇÖZÜM BURADA: r değişkenini doğrudan fonksiyona yolluyoruz
    onTap: () => _unvanlariGoster(context, provider, r), 
    borderRadius: BorderRadius.circular(Responsive.w(16)),
    child: Container(
      padding: EdgeInsets.all(Responsive.w(14)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: r.anaRenk.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.military_tech_rounded, color: r.anaRenk, size: Responsive.w(22)),
                  SizedBox(width: Responsive.w(8)),
                  Text(
                    provider.mevcutUnvan,
                    style: TextStyle(
                      color: r.yaziRengi,
                      fontWeight: FontWeight.bold,
                      fontSize: Responsive.sp(15),
                    ),
                  ),
                ],
              ),
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 800),
                tween: Tween<double>(begin: 0, end: provider.seviyeIlerleme),
                builder: (context, value, child) {
                  return Text(
                    "%${(value * 100).toStringAsFixed(0)}",
                    style: TextStyle(
                        color: r.anaRenk,
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.sp(12)),
                  );
                },
              ),
            ],
          ),
          SizedBox(height: Responsive.h(12)),
          TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeInOutCubic,
            tween: Tween<double>(begin: 0, end: provider.seviyeIlerleme),
            builder: (context, value, child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: LinearProgressIndicator(
                  value: value,
                  backgroundColor: r.arkaPlanRengi,
                  valueColor: AlwaysStoppedAnimation<Color>(r.anaRenk),
                  minHeight: Responsive.h(8),
                ),
              );
            },
          ),
        ],
      ),
    ),
  );
}

// 🔥 ÜNVANLARI LİSTELEYEN ŞIK BOTTOMSHEET
// ÇÖZÜM: AppThemeColors r parametresini buraya ekledik. Böylece içeride tekrar context.renkler çağırmıyoruz.
void _unvanlariGoster(BuildContext context, NamazProvider provider, AppThemeColors r) {
  showModalBottomSheet(
    context: context,
    backgroundColor: r.arkaPlanRengi,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    isScrollControlled: true,
    builder: (sheetContext) {
      return DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        expand: false,
        builder: (sheetContext, scrollController) {
          // Ünvanları XP sırasına göre listeleme
          final sortedKeys = SeviyeServisi.unvanlar.keys.toList()..sort();

          return Column(
            children: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                height: 4,
                width: 40,
                decoration: BoxDecoration(
                    color: r.pasifRenk, borderRadius: BorderRadius.circular(10)),
              ),
              Text(
                "VAKİT SAVAŞÇISI RÜTBELERİ",
                style: TextStyle(
                    color: r.anaRenk,
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.sp(18)),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: sortedKeys.length,
                  itemBuilder: (listContext, index) {
                    int xpLimit = sortedKeys[index];
                    String unvanIsmi = SeviyeServisi.unvanlar[xpLimit]!;
                    bool kilitli = provider.toplamXp < xpLimit;
                    bool suanki = provider.mevcutUnvan == unvanIsmi;

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: suanki ? r.anaRenk.withOpacity(0.1) : r.kartRengi,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: suanki
                              ? r.anaRenk
                              : (kilitli ? Colors.transparent : r.anaRenk.withOpacity(0.3)),
                          width: 1.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            kilitli ? Icons.lock_outline : Icons.military_tech,
                            color: kilitli ? r.pasifRenk : r.anaRenk,
                            size: 30,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  unvanIsmi,
                                  style: TextStyle(
                                    color: kilitli
                                        ? r.yaziRengi.withOpacity(0.4)
                                        : r.yaziRengi,
                                    fontWeight: FontWeight.bold,
                                    fontSize: Responsive.sp(16),
                                  ),
                                ),
                                Text(
                                  kilitli ? "$xpLimit XP Gerekiyor" : "Kazanıldı!",
                                  style: TextStyle(
                                      color: r.anaRenk.withOpacity(0.7),
                                      fontSize: Responsive.sp(12)),
                                ),
                              ],
                            ),
                          ),
                          if (suanki)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                  color: r.anaRenk,
                                  borderRadius: BorderRadius.circular(8)),
                              child: const Text("ŞU ANKİ",
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      );
    },
  );
}

// --- DİĞER WIDGET METODLARI (HEADER, CLOCK VB.) AYNEN DEVAM EDİYOR ---
Widget _buildHeader(BuildContext context, NamazProvider provider) {
  final r = context.renkler;
  return Container(
    padding: EdgeInsets.all(Responsive.w(16)),
    decoration: _sikKutuDecoration(context),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.ekranTarihi.isNotEmpty
                    ? provider.ekranTarihi.split(',')[0]
                    : "Pazartesi",
                style: TextStyle(
                  fontSize: Responsive.sp(18),
                  fontWeight: FontWeight.bold,
                  color: r.yaziRengi,
                ),
              ),
              Text(
                provider.ekranTarihi.contains(',')
                    ? provider.ekranTarihi.split(',')[1].trim()
                    : "10 Mart",
                style: TextStyle(
                  fontSize: Responsive.sp(13),
                  color: r.yaziRengi.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(12),
            vertical: Responsive.h(8),
          ),
          decoration: BoxDecoration(
            color: r.anaRenk.withOpacity(0.15),
            borderRadius: BorderRadius.circular(Responsive.w(20)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: r.anaRenk,
                size: Responsive.w(24),
              ),
              SizedBox(width: Responsive.w(4)),
              Text(
                "${provider.streakCount}",
                style: TextStyle(
                  fontSize: Responsive.sp(20),
                  fontWeight: FontWeight.bold,
                  color: r.yaziRengi,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildMainClock(BuildContext context, NamazProvider provider) {
  final r = context.renkler;
  final tema = context.watch<ThemeProvider>().aktifTema;
  final gradientEnd = tema.brightness == Brightness.dark
      ? tema.kartRengi.withOpacity(0.8)
      : const Color(0xFFFFF3E0);

  return Container(
    padding: EdgeInsets.symmetric(
      vertical: Responsive.h(24),
      horizontal: Responsive.w(16),
    ),
    decoration: _sikKutuDecoration(context).copyWith(
      gradient: LinearGradient(
        colors: [r.kartRengi, gradientEnd],
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
            context.read<NamazProvider>().konumVeApiIstegi(
              kullaniciTetikledi: true,
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(10),
              vertical: Responsive.h(3),
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
                  size: Responsive.w(14),
                  color: r.yaziRengi.withOpacity(0.6),
                ),
                SizedBox(width: Responsive.w(4)),
                Flexible(
                  child: Text(
                    provider.konumBilgisi,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.sp(12),
                      fontWeight: FontWeight.w600,
                      color: r.yaziRengi.withOpacity(0.6),
                      letterSpacing: 1,
                    ),
                  ),
                ),
                SizedBox(width: Responsive.w(4)),
                Icon(
                  Icons.refresh,
                  size: Responsive.w(12),
                  color: r.yaziRengi.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
        SizedBox(height: Responsive.h(8)),
        Text(
          provider.aktifVakit.toUpperCase(),
          style: TextStyle(
            fontSize: Responsive.sp(24),
            letterSpacing: 5,
            color: r.anaRenk,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          DateFormat("HH:mm").format(DateTime.now()),
          style: TextStyle(
            fontSize: Responsive.sp(64),
            fontWeight: FontWeight.bold,
            color: r.yaziRengi,
            letterSpacing: -2,
            height: 1.0,
          ),
        ),
        SizedBox(height: Responsive.h(8)),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(16),
            vertical: Responsive.h(6),
          ),
          decoration: BoxDecoration(
            color: r.yaziRengi.withOpacity(0.08),
            borderRadius: BorderRadius.circular(Responsive.w(15)),
          ),
          child: Text(
            "Kalan Süre: ${provider.kalanSure}",
            style: TextStyle(
              fontSize: Responsive.sp(15),
              fontWeight: FontWeight.bold,
              color: r.yaziRengi,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildVakitGrid(BuildContext context, NamazProvider provider) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
    decoration: _sikKutuDecoration(context),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _vakitKutusu(context, "Sabah", Icons.wb_twilight,
            provider.vakitler?["Sabah"] ?? "05:00", provider),
        _vakitKutusu(context, "Öğle", Icons.wb_sunny,
            provider.vakitler?["Öğle"] ?? "13:00", provider),
        _vakitKutusu(context, "İkindi", Icons.wb_twighlight,
            provider.vakitler?["İkindi"] ?? "16:00", provider),
        _vakitKutusu(context, "Akşam", Icons.bedtime,
            provider.vakitler?["Akşam"] ?? "19:00", provider),
        _vakitKutusu(context, "Yatsı", Icons.nights_stay,
            provider.vakitler?["Yatsı"] ?? "20:30", provider),
      ],
    ),
  );
}

Widget _buildPrayerButton(BuildContext context, NamazProvider provider) {
  return _AnimatedPrayerButton(
    isDone: provider.kildiMi[provider.aktifVakit] ?? false,
    onTap: () {
      bool suanki = provider.kildiMi[provider.aktifVakit] ?? false;
      provider.vaktiKildimIsaretle(provider.aktifVakit, !suanki);
    },
  );
}

BoxDecoration _sikKutuDecoration(BuildContext context) {
  final r = context.renkler;
  return BoxDecoration(
    color: r.kartRengi,
    borderRadius: BorderRadius.circular(Responsive.w(20)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

Widget _vakitKutusu(
  BuildContext context,
  String ad,
  IconData ikon,
  String saat,
  NamazProvider provider,
) {
  final r = context.renkler;
  bool kildi = provider.kildiMi[ad] ?? false;
  bool suan = provider.aktifVakit == ad;
  String temizSaat = saat.contains(" ") ? saat.split(" ")[0] : saat;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    padding: EdgeInsets.symmetric(
      horizontal: Responsive.w(8),
      vertical: Responsive.h(6),
    ),
    decoration: BoxDecoration(
      color: suan ? r.aktifYesil.withOpacity(0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(Responsive.w(12)),
      border: suan
          ? Border.all(color: r.aktifYesil.withOpacity(0.5), width: 1.5)
          : null,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          ikon,
          size: Responsive.w(24),
          color: kildi
              ? r.aktifYesil
              : (suan ? r.anaRenk : r.pasifRenk),
        ),
        SizedBox(height: Responsive.h(6)),
        Text(
          temizSaat,
          style: TextStyle(
            fontSize: Responsive.sp(13),
            fontWeight: suan ? FontWeight.bold : FontWeight.w500,
            color: suan ? r.yaziRengi : r.yaziRengi.withOpacity(0.5),
          ),
        ),
        SizedBox(height: Responsive.h(3)),
        Text(
          ad,
          style: TextStyle(
            fontSize: Responsive.sp(10),
            color: suan ? r.anaRenk : Colors.transparent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
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
    final r = context.renkler;
    final btnHeight = Responsive.h(120);
    final circleSize = Responsive.w(60);
    final iconSize = Responsive.w(36);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: btnHeight,
          decoration: BoxDecoration(
            color: widget.isDone ? r.aktifYesil : r.kartRengi,
            borderRadius: BorderRadius.circular(Responsive.w(25)),
            border: widget.isDone
                ? null
                : Border.all(
                    color: r.anaRenk.withOpacity(0.3),
                    width: 2,
                  ),
            boxShadow: [
              BoxShadow(
                color: widget.isDone
                    ? r.aktifYesil.withOpacity(0.4)
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
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: r.arkaPlanRengi,
                  border: Border.all(
                    color: widget.isDone ? Colors.white : r.pasifRenk,
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: iconSize,
                  color: widget.isDone ? r.aktifYesil : r.pasifRenk,
                ),
              ),
              SizedBox(height: Responsive.h(10)),
              Text(
                widget.isDone ? "ALLAH KABUL ETSİN!" : "VAKTİ KILDIM",
                style: TextStyle(
                  fontSize: Responsive.sp(15),
                  fontWeight: FontWeight.w900,
                  color: widget.isDone ? Colors.white : r.yaziRengi,
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