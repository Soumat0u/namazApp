import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/utils/extensions.dart';
import '../providers/namaz_provider.dart';
import 'widgets/vakit_background.dart';
import 'package:share_plus/share_plus.dart';
import '../services/seviye_servisi.dart';
import 'tools_screen.dart'; // Araçlar eklendi
import 'widgets/sehir_secici.dart';
import '../models/religious_day.dart';
import 'package:intl/intl.dart';
import 'package:quran/quran.dart' as quran;

class AnaSayfa extends StatefulWidget {
  const AnaSayfa({super.key});

  @override
  State<AnaSayfa> createState() => _AnaSayfaState();
}

class _AnaSayfaState extends State<AnaSayfa> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    // Yeni rozet kazanıldıysa bir kez kutla
    if (provider.yeniRozet != null) {
      final rozet = provider.yeniRozet!;
      provider.yeniRozet = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Row(children: [
              Icon(rozet.ikon, color: Colors.amber),
              const SizedBox(width: 10),
              Expanded(child: Text("Yeni rozet: ${rozet.ad}! ${rozet.aciklama}")),
            ]),
          ));
        }
      });
    }
    // Seri dondurma kullanıldıysa bir kez bildir
    if (provider.seriDondurmaMesaji != null) {
      final mesaj = provider.seriDondurmaMesaji!;
      provider.seriDondurmaMesaji = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mesaj)));
      });
    }

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

    // Vakitler yoksa bile ana iskeleti göster
    if (provider.vakitler == null && !provider.isLoading) {
      // Hata mesajı varsa SnackBar ile gösterilebilir veya sessizce beklenebilir
    }

    return SafeArea(
      left: false,
      right: false,
      child: RefreshIndicator(
        color: context.renkler.anaRenk,
        backgroundColor: context.renkler.kartRengi,
        onRefresh: () => context.read<NamazProvider>().konumVeApiIstegi(
          kullaniciTetikledi: true,
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(16),
                  Responsive.h(16),
                  Responsive.w(16),
                  0,
                ),
                child: Row(
                  children: [
                    Expanded(child: _buildLevelCard(context, provider)),
                    SizedBox(width: Responsive.w(12)),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AraclarSayfasi()),
                        );
                      },
                      borderRadius: BorderRadius.circular(Responsive.w(16)),
                      child: Container(
                        // Level kartı ile aynı padding/boyut uyumunu sağlamak için
                        padding: EdgeInsets.all(Responsive.w(16)),
                        decoration: BoxDecoration(
                          color: context.renkler.kartRengi,
                          borderRadius: BorderRadius.circular(Responsive.w(16)),
                          border: Border.all(color: context.renkler.anaRenk.withOpacity(0.2), width: 1),
                        ),
                        child: Icon(
                          Icons.grid_view_rounded, // Sosyal yerine Araçlar ikonu
                          color: context.renkler.anaRenk,
                          size: Responsive.w(26),
                        ),
                      ),
                    ),
                  ],
                ),
              ),


              // Senin hazırladığın Header alanı
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(16),
                  Responsive.h(
                    16,
                  ), // Level kartı olduğu için gerekirse burayı 8 yapabilirsin
                  Responsive.w(16),
                  0,
                ),
                child: _buildHeader(context, provider),
              ),

              SizedBox(height: Responsive.h(16)),

              _buildDiniGunBanner(context, provider),
              _buildCumaVeGeriSayim(context, provider),

              if (provider.vakitler == null && !provider.isLoading)
                _buildKonumGerekliKarti(context, provider),

              // Senin hazırladığın Ana Saat alanı (Sayfalı yapıldı)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                child: _buildSwipeableHeader(context, provider),
              ),

              // Alt kısımdaki grid ve butonlar
              Padding(
                padding: EdgeInsets.all(Responsive.w(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildVakitGrid(context, provider),
                    SizedBox(height: Responsive.h(16)),
                    _buildPrayerButton(context, provider),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSwipeableHeader(BuildContext context, NamazProvider provider) {
    return Column(
      children: [
        SizedBox(
          height: Responsive.h(220),
          child: PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: _buildMainClock(context, provider),
              ),
              if (provider.gununAyetiMeali.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Hero(
                    tag: 'gununAyetCard',
                    child: _GununAyetiCard(provider: provider),
                  ),
                ),
            ],
          ),
        ),
        if (provider.gununAyetiMeali.isNotEmpty) ...[
          SizedBox(height: Responsive.h(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(2, (index) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 4),
                height: 8,
                width: _currentPage == index ? 24 : 8,
                decoration: BoxDecoration(
                  color: _currentPage == index
                      ? context.renkler.anaRenk
                      : context.renkler.pasifRenk.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }

  /// Konum izni yok / GPS alınamadı: kullanıcıya izin verme veya şehir seçme imkânı sun
  Widget _buildKonumGerekliKarti(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    return Padding(
      padding: EdgeInsets.fromLTRB(Responsive.w(16), 0, Responsive.w(16), Responsive.h(16)),
      child: Container(
        padding: EdgeInsets.all(Responsive.w(16)),
        decoration: BoxDecoration(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(color: r.anaRenk.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.location_off_rounded, color: r.anaRenk),
                SizedBox(width: Responsive.w(8)),
                Expanded(
                  child: Text(
                    "Vakitler için konum gerekli",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: Responsive.sp(15),
                      color: r.yaziRengi,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(8)),
            Text(
              provider.hataMesaji.isNotEmpty
                  ? provider.hataMesaji.split('\n').first
                  : "Konum izni verin veya bulunduğunuz şehri seçin.",
              style: TextStyle(fontSize: Responsive.sp(12), color: r.yaziRengi.withOpacity(0.7)),
            ),
            SizedBox(height: Responsive.h(12)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => provider.konumVeApiIstegi(kullaniciTetikledi: true),
                    icon: const Icon(Icons.my_location, size: 18),
                    label: const Text("Konum İzni Ver"),
                    style: OutlinedButton.styleFrom(foregroundColor: r.anaRenk),
                  ),
                ),
                SizedBox(width: Responsive.w(8)),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => sehirSeciciGoster(context),
                    icon: const Icon(Icons.location_city, size: 18),
                    label: const Text("Şehir Seç"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: r.anaRenk,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Cuma günü Kehf hatırlatması ve sıradaki dini güne geri sayım (yarın/bugün ise üstteki banner gösterir)
  Widget _buildCumaVeGeriSayim(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    final cuma = DateTime.now().weekday == DateTime.friday;
    final siradaki = provider.siradakiDiniGun;
    final geriSayim = siradaki != null && siradaki.kalan > 1 ? siradaki : null;
    if (!cuma && geriSayim == null) return const SizedBox.shrink();

    Widget satir(IconData ikon, String metin, {Widget? sag}) => Row(
          children: [
            Icon(ikon, color: r.anaRenk, size: Responsive.w(20)),
            SizedBox(width: Responsive.w(10)),
            Expanded(
              child: Text(metin,
                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w600, fontSize: Responsive.sp(13))),
            ),
            if (sag != null) sag,
          ],
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(Responsive.w(16), 0, Responsive.w(16), Responsive.h(12)),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(10)),
        decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(Responsive.w(16))),
        child: Column(
          children: [
            if (cuma)
              satir(
                Icons.mosque_rounded,
                "Hayırlı Cumalar! Kehf suresini okudun mu?",
                sag: TextButton(
                  onPressed: () => _GununAyetiCard(provider: provider)._sureyiGoster(context, 18, 1, r),
                  child: Text("Oku", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
                ),
              ),
            if (cuma && geriSayim != null) Divider(color: r.pasifRenk.withOpacity(0.15), height: Responsive.h(12)),
            if (geriSayim != null)
              satir(
                Icons.nightlight_round,
                "${geriSayim.gun.turkishName}: ${geriSayim.kalan} gün kaldı",
                sag: Text(
                  DateFormat('d MMMM', 'tr_TR').format(DateTime.parse(geriSayim.gun.dateStr)),
                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11)),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDiniGunBanner(BuildContext context, NamazProvider provider) {
    if (provider.isDiniGunlerLoading && provider.tumDiniGunler.isEmpty) {
      return const SizedBox.shrink(); // Yüklenirken gösterme
    }
  
    final simdi = DateTime.now();
    final yarin = simdi.add(const Duration(days: 1));
    
    final bugunStr = DateFormat('yyyy-MM-dd').format(simdi);
    final yarinStr = DateFormat('yyyy-MM-dd').format(yarin);

    ReligiousDay? hDay = provider.tumDiniGunler[bugunStr];
    bool isBugun = true;

    if (hDay == null) {
      hDay = provider.tumDiniGunler[yarinStr];
      isBugun = false;
    }

    if (hDay == null) return const SizedBox.shrink();

    final r = context.renkler;

    return Padding(
      padding: EdgeInsets.fromLTRB(Responsive.w(16), 0, Responsive.w(16), Responsive.h(16)),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(Responsive.w(12)),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD700).withOpacity(0.15),
          border: Border.all(color: const Color(0xFFFFD700).withOpacity(0.5)),
          borderRadius: BorderRadius.circular(Responsive.w(12)),
        ),
        child: Row(
          children: [
            Icon(Icons.star, color: const Color(0xFFD4AF37), size: Responsive.w(24)),
            SizedBox(width: Responsive.w(12)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isBugun ? "Bugün: ${hDay.turkishName}" : "Yarın: ${hDay.turkishName}",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: Responsive.sp(14),
                      color: r.yaziRengi,
                    ),
                  ),
                  if (hDay.description != null)
                    Text(
                      hDay.description!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.sp(11),
                        color: r.yaziRengi.withOpacity(0.8),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
              Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.military_tech_rounded,
                      color: r.anaRenk,
                      size: Responsive.w(22),
                    ),
                    SizedBox(width: Responsive.w(8)),
                    Flexible(
                      child: Text(
                        provider.mevcutUnvan,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: r.yaziRengi,
                          fontWeight: FontWeight.bold,
                          fontSize: Responsive.sp(15),
                        ),
                      ),
                    ),
                    SizedBox(width: Responsive.w(8)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(6), vertical: Responsive.h(2)),
                      decoration: BoxDecoration(
                        color: r.anaRenk.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(Responsive.w(6)),
                      ),
                      child: Text(
                        "${provider.toplamXp} XP",
                        style: TextStyle(
                          color: r.anaRenk,
                          fontWeight: FontWeight.bold,
                          fontSize: Responsive.sp(11),
                        ),
                      ),
                    ),
                  ],
                ),
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
                      fontSize: Responsive.sp(12),
                    ),
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
void _unvanlariGoster(
  BuildContext context,
  NamazProvider provider,
  AppThemeColors r,
) {
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
                  color: r.pasifRenk,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                "Takva Yolun",
                style: TextStyle(
                  color: r.anaRenk,
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.sp(18),
                ),
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
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: suanki
                            ? r.anaRenk.withOpacity(0.1)
                            : r.kartRengi,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: suanki
                              ? r.anaRenk
                              : (kilitli
                                    ? Colors.transparent
                                    : r.anaRenk.withOpacity(0.3)),
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
                                  kilitli
                                      ? "$xpLimit XP Gerekiyor"
                                      : "Kazanıldı!",
                                  style: TextStyle(
                                    color: r.anaRenk.withOpacity(0.7),
                                    fontSize: Responsive.sp(12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (suanki)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: r.anaRenk,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                "ŞU ANKİ",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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

// --- DİĞER WIDGET METODLARI (HEADER, CLOCK VB.) ---
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
  padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(8)),
  decoration: BoxDecoration(
    color: r.anaRenk.withOpacity(0.15),
    borderRadius: BorderRadius.circular(Responsive.w(20)),
  ),
  child: Row(
    children: [
      // Eski streak_icon.png yerine yeni yıldız webp
      Image.asset(
                  'assets/images/streak_icon.png',
                  width: Responsive.w(30),
        height: Responsive.w(30),
        color: r.anaRenk, // Yıldızı temanın ana rengine boyar
        colorBlendMode: BlendMode.srcIn,
      ),
      SizedBox(width: Responsive.w(6)),
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
)
      ],
    ),
  );
}

Widget _buildMainClock(BuildContext context, NamazProvider provider) {
  return VakitBackground(
    tema: provider.vaktinTemasi,
    borderRadius: BorderRadius.circular(Responsive.w(20)),
    child: Container(
      padding: EdgeInsets.symmetric(
        vertical: Responsive.h(24),
        horizontal: Responsive.w(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
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
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: Responsive.w(14),
                    color: Colors.white.withOpacity(0.9),
                  ),
                  SizedBox(width: Responsive.w(4)),
                  Flexible(
                    child: Text(
                      provider.konumBilgisi,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.sp(12),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.w(4)),
                  Icon(
                    Icons.refresh,
                    size: Responsive.w(12),
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.h(8)),
          Text(
            provider.aktifVakit.trBuyuk,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.sp(24),
              letterSpacing: 5,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black45,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: provider.guncelSaatNotifier,
            builder: (context, guncelSaat, child) {
              return Text(
                guncelSaat,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.sp(64),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -2,
                  height: 1.0,
                  shadows: [
                    Shadow(
                      blurRadius: 15,
                      color: Colors.black38,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: Responsive.h(8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(16),
              vertical: Responsive.h(6),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(Responsive.w(15)),
            ),
            child: ValueListenableBuilder<String>(
              valueListenable: provider.kalanSureNotifier,
              builder: (context, kalanSure, child) {
                return Text(
                  "Kalan Süre: $kalanSure",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.sp(15),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildVakitGrid(BuildContext context, NamazProvider provider) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
    decoration: _sikKutuDecoration(context),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _vakitKutusu(
          context,
          "Sabah",
          Icons.wb_twilight,
          provider.vakitler?["Sabah"] ?? "--:--",
          provider,
        ),
        _vakitKutusu(
          context,
          "Öğle",
          Icons.wb_sunny,
          provider.vakitler?["Öğle"] ?? "--:--",
          provider,
        ),
        _vakitKutusu(
          context,
          "İkindi",
          Icons.wb_twilight,
          provider.vakitler?["İkindi"] ?? "--:--",
          provider,
        ),
        _vakitKutusu(
          context,
          "Akşam",
          Icons.nights_stay,
          provider.vakitler?["Akşam"] ?? "--:--",
          provider,
        ),
        _vakitKutusu(
          context,
          "Yatsı",
          Icons.bedtime,
          provider.vakitler?["Yatsı"] ?? "--:--",
          provider,
        ),
      ],
    ),
  );
}

Widget _buildPrayerButton(BuildContext context, NamazProvider provider) {
  // Güneş doğduktan sonra Öğle'ye kadar kılınacak farz yok
  if (!provider.vakitIsimleri.contains(provider.aktifVakit)) {
    return const _AnimatedPrayerButton(
      isDone: false,
      onTap: null,
      etiket: "ÖĞLE VAKTİ BEKLENİYOR",
    );
  }
  return _AnimatedPrayerButton(
    isDone: provider.kildiMi[provider.aktifVakit] ?? false,
    onTap: () => _vakteDokunuldu(context, provider, provider.aktifVakit),
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

  return GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTap: () => _vakteDokunuldu(context, provider, ad),
    child: AnimatedContainer(
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
        Stack(
          clipBehavior: Clip.none,
          children: [
            _VakitIkonu(
              ikon: ikon,
              size: Responsive.w(24),
              color: kildi ? r.anaRenk : (suan ? r.aktifYesil : r.pasifRenk),
              isActive: suan,
            ),
            if (kildi)
              Positioned(
                right: -Responsive.w(6),
                top: -Responsive.w(4),
                child: Icon(Icons.check_circle_rounded, size: Responsive.w(12), color: r.anaRenk),
              ),
          ],
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
      ],
    ),
    ),
  );
}
}

/// Şu anki vakit işaretlenir/geri alınır; diğer vakitlerde nedenini söyler
void _vakteDokunuldu(BuildContext context, NamazProvider provider, String vakit) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  if (!provider.vakitIsimleri.contains(vakit)) {
    messenger.showSnackBar(const SnackBar(content: Text("Güneş doğuşu bir namaz vakti değil.")));
    return;
  }
  if (!provider.vakitIsaretlenebilirMi(vakit)) {
    final sira = provider.vakitIsimleri.indexOf(vakit);
    final aktifSira = provider.vakitIsimleri.indexOf(provider.aktifVakit);
    final gecti = aktifSira == -1 ? sira == 0 : sira < aktifSira;
    messenger.showSnackBar(SnackBar(
      content: Text(gecti
          ? "$vakit vakti çıktı, artık işaretlenemez."
          : "$vakit vakti henüz girmedi."),
    ));
    return;
  }
  final yeniDurum = !(provider.kildiMi[vakit] ?? false);
  provider.vaktiKildimIsaretle(vakit, yeniDurum);
  messenger.showSnackBar(SnackBar(
    content: Text(yeniDurum ? "$vakit namazı kılındı olarak işaretlendi." : "$vakit namazının işareti kaldırıldı."),
    duration: const Duration(seconds: 3),
    action: SnackBarAction(label: "Geri Al", onPressed: () => provider.vaktiKildimIsaretle(vakit, !yeniDurum)),
  ));
}

class _AnimatedPrayerButton extends StatefulWidget {
  final bool isDone;
  final VoidCallback? onTap; // null: buton pasif (ör. Güneş vakti)
  final String? etiket;
  const _AnimatedPrayerButton({required this.isDone, required this.onTap, this.etiket});
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

    final aktif = widget.onTap != null;
    return GestureDetector(
      onTapDown: aktif ? (_) => _controller.forward() : null,
      onTapUp: aktif ? (_) => _controller.reverse() : null,
      onTapCancel: aktif ? () => _controller.reverse() : null,
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: btnHeight,
          decoration: BoxDecoration(
            color: widget.isDone ? r.anaRenk : r.kartRengi,
            borderRadius: BorderRadius.circular(Responsive.w(25)),
            border: widget.isDone
                ? null
                : Border.all(color: r.anaRenk.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.isDone
                    ? r.anaRenk.withOpacity(0.4)
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
                  color: widget.isDone ? r.anaRenk : r.pasifRenk,
                ),
              ),
              SizedBox(height: Responsive.h(10)),
              Text(
                widget.etiket ?? (widget.isDone ? "ALLAH KABUL ETSİN!" : "VAKTİ KILDIM"),
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
class _VakitIkonu extends StatefulWidget {
  final IconData ikon;
  final double size;
  final Color color;
  final bool isActive;

  const _VakitIkonu({
    required this.ikon,
    required this.size,
    required this.color,
    required this.isActive,
  });

  @override
  State<_VakitIkonu> createState() => _VakitIkonuState();
}

class _VakitIkonuState extends State<_VakitIkonu>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_VakitIkonu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Icon(widget.ikon, size: widget.size, color: widget.color);
    }

    return ScaleTransition(
      scale: _animation,
      child: Icon(
        widget.ikon,
        size: widget.size,
        color: widget.color,
        shadows: [Shadow(color: widget.color.withOpacity(0.5), blurRadius: 10)],
      ),
    );
  }
}

class _GununAyetiCard extends StatelessWidget {
  final NamazProvider provider;
  final bool isFullText;
  const _GununAyetiCard({required this.provider, this.isFullText = false});

  void _ayetOdakModuAc(BuildContext context) {
    if (isFullText) return; // Zaten odak modundaysak tekrar açma

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Ayet Detay",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 500),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: const Alignment(0, -0.2), // Hafif yukarı kaydırıldı (0, 0 tam ortadır)
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(10)),
            child: SingleChildScrollView(
              child: Hero(
                tag: 'gununAyetCard',
                child: Material(
                  color: Colors.transparent,
                  child: _GununAyetiCard(provider: provider, isFullText: true),
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
            child: child,
          ),
        );
      },
    );
  }

  void _sureyiGoster(BuildContext context, int sureNo, int targetAyet, AppThemeColors r) {
  final sureAdi = quran.getSurahNameTurkish(sureNo);
  final ayetSayisi = quran.getVerseCount(sureNo);

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: "Sure Detay",
    barrierColor: Colors.black.withOpacity(0.85), // Arka planı biraz daha koyulaştırdım
    transitionDuration: const Duration(milliseconds: 500),
    pageBuilder: (context, anim1, anim2) {
      // Ayet yükseklikleri çok farklı olduğu için tahmini offset yanlış yere götürür:
      // tüm ayetler çizilir ve hedef ayetin gerçek konumuna kaydırılır.
      final hedefAnahtar = GlobalKey();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final hedef = hedefAnahtar.currentContext;
        if (targetAyet > 1 && hedef != null) {
          Scrollable.ensureVisible(
            hedef,
            alignment: 0.05,
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutExpo,
          );
        }
      });

      return Align(
        alignment: Alignment.center,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: Responsive.w(15), vertical: Responsive.h(40)),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.92,
              height: MediaQuery.of(context).size.height * 0.80,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color.alphaBlend(Colors.black.withOpacity(0.4), r.anaRenk),
                    r.anaRenk,
                    Color.alphaBlend(Colors.white.withOpacity(0.2), r.anaRenk),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(Responsive.w(28)),
                boxShadow: [
                  BoxShadow(
                    color: r.anaRenk.withOpacity(0.4),
                    blurRadius: 25,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Responsive.w(28)),
                child: Column(
                  children: [
                    // --- BAŞLIK ALANI ---
                    _buildModalHeader(context, sureAdi, ayetSayisi, r),

                    // --- AYETLER LİSTESİ ---
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: EdgeInsets.fromLTRB(Responsive.w(20), Responsive.h(10), Responsive.w(20), Responsive.h(30)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: List.generate(ayetSayisi, (index) {
                          // KRİTİK: index her zaman 0'dan başlar, ayetNo 1'den.
                          final int currentAyetNo = index + 1;
                          final bool isTarget = currentAyetNo == targetAyet;

                          return Container(
                            key: isTarget ? hedefAnahtar : ValueKey('ayet_card_${sureNo}_$currentAyetNo'),
                            margin: EdgeInsets.only(bottom: Responsive.h(16)),
                            padding: EdgeInsets.all(Responsive.w(16)),
                            decoration: BoxDecoration(
                              color: isTarget ? Colors.white.withOpacity(0.2) : Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(Responsive.w(20)),
                              border: Border.all(
                                color: isTarget ? Colors.white.withOpacity(0.5) : Colors.white.withOpacity(0.1),
                                width: isTarget ? 1.5 : 0.5,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Ayet Numarası ve Arapça Metin
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildAyetNoBadge(currentAyetNo, isTarget, r),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        quran.getVerse(sureNo, currentAyetNo, verseEndSymbol: true),
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: Responsive.sp(22),
                                          fontFamily: 'Amiri', // Arapça fontu yüklü olmalı
                                          color: Colors.white,
                                          height: 1.8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                // Türkçe Meal (Tekrarlı çevirileri önleme mantığı)
                                Builder(
                                  builder: (context) {
                                    final currentTranslation = quran.getVerseTranslation(
                                      sureNo, 
                                      currentAyetNo, 
                                      translation: quran.Translation.trSaheeh
                                    );
                                    
                                    bool isDuplicate = false;
                                    if (currentAyetNo > 1) {
                                      final previousTranslation = quran.getVerseTranslation(
                                        sureNo, 
                                        currentAyetNo - 1, 
                                        translation: quran.Translation.trSaheeh
                                      );
                                      isDuplicate = currentTranslation == previousTranslation;
                                    }

                                    if (isDuplicate) {
                                      return Text(
                                        "(Önceki ayetin mealine dâhildir)",
                                        style: TextStyle(
                                          fontSize: Responsive.sp(12),
                                          color: Colors.white.withOpacity(0.5),
                                          fontStyle: FontStyle.italic,
                                        ),
                                        textAlign: TextAlign.center,
                                      );
                                    }

                                    return Text(
                                      currentTranslation,
                                      style: TextStyle(
                                        fontSize: Responsive.sp(isTarget ? 15 : 14),
                                        color: Colors.white.withOpacity(isTarget ? 1.0 : 0.85),
                                        fontWeight: isTarget ? FontWeight.bold : FontWeight.normal,
                                        fontStyle: FontStyle.italic,
                                        height: 1.5,
                                      ),
                                    );
                                  }
                                ),
                              ],
                            ),
                          );
                          }),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
    transitionBuilder: (context, anim1, anim2, child) {
      return FadeTransition(
        opacity: anim1,
        child: ScaleTransition(
          scale: CurvedAnimation(parent: anim1, curve: Curves.easeInOut),
          child: child,
        ),
      );
    },
  );
}

// Başlık için yardımcı widget
Widget _buildModalHeader(BuildContext context, String name, int count, AppThemeColors r) {
  return Container(
    padding: EdgeInsets.all(Responsive.w(20)),
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.1),
      border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
    ),
    child: Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          style: IconButton.styleFrom(backgroundColor: Colors.white.withOpacity(0.1)),
        ),
        const Spacer(),
        Column(
          children: [
            Text(
              name.toUpperCase(),
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: Responsive.sp(14),
                letterSpacing: 2,
              ),
            ),
            Text(
              "$count Ayet-i Kerime",
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: Responsive.sp(11)),
            ),
          ],
        ),
        const Spacer(),
        const SizedBox(width: 48), // Simetri dengelemesi
      ],
    ),
  );
}

// Ayet numarası rozeti
Widget _buildAyetNoBadge(int no, bool isTarget, AppThemeColors r) {
  return Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: isTarget ? Colors.white : Colors.white.withOpacity(0.1),
      shape: BoxShape.circle,
      boxShadow: isTarget ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4)] : null,
    ),
    child: Text(
      "$no",
      style: TextStyle(
        color: isTarget ? r.anaRenk : Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;

    return GestureDetector(
      onTap: () => _ayetOdakModuAc(context),
      child: Container(
        padding: EdgeInsets.fromLTRB(
          Responsive.w(20),
          Responsive.w(20),
          Responsive.w(20),
          isFullText ? Responsive.w(10) : Responsive.w(0), // Alt boşluk küçültüldü
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color.alphaBlend(Colors.black.withOpacity(0.3), r.anaRenk),
              r.anaRenk,
              Color.alphaBlend(Colors.white.withOpacity(0.3), r.anaRenk),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.5, 1.0],
          ),
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          boxShadow: [
            BoxShadow(
              color: r.anaRenk.withOpacity(0.3),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: isFullText ? MainAxisSize.min : MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: Responsive.w(16)),
                SizedBox(width: Responsive.w(8)),
                Text(
                  "GÜNÜN AYETİ",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: Responsive.sp(12),
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            if (!isFullText) SizedBox(height: Responsive.h(10)),
            if (isFullText) SizedBox(height: Responsive.h(20)),
            LayoutBuilder(
              builder: (context, constraints) {
                final textStyle = TextStyle(
                  color: Colors.white,
                  fontSize: Responsive.sp(isFullText ? 18 : 15),
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                  height: 1.4,
                  shadows: [Shadow(blurRadius: 8, color: Colors.black45)],
                );

                final text = "\"${provider.gununAyetiMeali}\"";

                final span = TextSpan(text: text, style: textStyle);
                final tp = TextPainter(
                  text: span,
                  maxLines: 4,
                  textDirection: Directionality.of(context),
                );
                tp.layout(maxWidth: constraints.maxWidth);
                final isOverflowing = tp.didExceedMaxLines;

                return Column(
                  children: [
                    Text(
                      text,
                      textAlign: TextAlign.center,
                      maxLines: isFullText ? null : 4,
                      overflow: isFullText ? TextOverflow.visible : TextOverflow.ellipsis,
                      style: textStyle,
                    ),
                    if (isOverflowing && !isFullText)
                      TextButton(
                        onPressed: () => _ayetOdakModuAc(context),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          "...devamını oku",
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            fontSize: Responsive.sp(13),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
            SizedBox(height: Responsive.h(8)), // 12 -> 8
            Text(
              provider.gununAyetiReferans,
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: Responsive.sp(isFullText ? 14 : 12),
                fontWeight: FontWeight.bold,
                shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
              ),
            ),
            if (isFullText) SizedBox(height: Responsive.h(20)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    Share.share(
                      "Günün Ayeti:\n\n\"${provider.gununAyetiMeali}\"\n\n(${provider.gununAyetiReferans})",
                    );
                  },
                  icon: Icon(Icons.share_rounded, size: Responsive.w(16), color: r.anaRenk),
                  label: Text("Paylaş", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
                  ),
                ),
                SizedBox(width: Responsive.w(8)),
                ElevatedButton.icon(
                  onPressed: () {
                    final navigator = Navigator.of(context, rootNavigator: true);
                    if (isFullText) navigator.pop(); // Odak modunu kapat; karartmalar üst üste binmesin
                    _sureyiGoster(navigator.context, provider.gununAyetiSureNo, provider.gununAyetiNo, r);
                  },
                  icon: Icon(Icons.menu_book_rounded, size: Responsive.w(16), color: Colors.white),
                  label: Text("Sureyi İncele", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.2),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(12)),
                  ),
                ),
              ],
            ),
            if (isFullText) ...[
              SizedBox(height: Responsive.h(16)),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  "KAPAT",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
