import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import 'package:intl/intl.dart';
import '../core/utils/dini_gunler_util.dart';
import '../models/religious_day.dart';
import '../services/seviye_servisi.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;

class IstatistikSayfasi extends StatefulWidget {
  const IstatistikSayfasi({super.key});

  @override
  State<IstatistikSayfasi> createState() => _IstatistikSayfasiState();
}

class _IstatistikSayfasiState extends State<IstatistikSayfasi> {
  DateTime? _goruntulenenTarih;
  late PageController _pageController;
  final int _initialPage = 1000;
  late int _currentPageIndex;
  final ScreenshotController _screenshotController = ScreenshotController();

  @override
  void initState() {
    super.initState();
    _currentPageIndex = _initialPage;
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _sonrakiAy(NamazProvider provider) {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _oncekiAy(NamazProvider provider) {
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  DateTime _indexToDate(int index, DateTime now) {
    final diff = index - _initialPage;
    return DateTime(now.year, now.month + diff, 1);
  }

  /// Haftalık verileri hesaplar
  Map<String, dynamic> _haftalikVeriHesapla(NamazProvider provider) {
    final sanalBugunStr = provider.getSanalGun();
    final sanalBugun = DateFormat('yyyy-MM-dd').parse(sanalBugunStr);
    final pztUzaklik = sanalBugun.weekday - 1;
    final pazartesi = sanalBugun.subtract(Duration(days: pztUzaklik));

    List<int> gunlukSayilar = [];
    List<int> kazaSayilar = [];
    Map<String, int> vakitFrekanslari = {
      "Sabah": 0,
      "Öğle": 0,
      "İkindi": 0,
      "Akşam": 0,
      "Yatsı": 0,
    };
    int toplamVakit = 0;

    for (int i = 0; i < 7; i++) {
      final gun = pazartesi.add(Duration(days: i));
      final dateKey = DateFormat('yyyy-MM-dd').format(gun);

      int count;
      if (dateKey == sanalBugunStr) {
        count = provider.kildiMi.values.where((v) => v).length;
      } else {
        count = provider.aylikGecmis[dateKey] ?? 0;
      }
      gunlukSayilar.add(count);
      
      int kazaCount = provider.kazaGecmisi[dateKey] ?? 0;
      kazaSayilar.add(kazaCount);

      toplamVakit += count;

      // Vakit detaylarını kontrol et
      Map<String, dynamic>? detay;
      if (dateKey == sanalBugunStr) {
        detay = provider.kildiMi.map((k, v) => MapEntry(k, v));
      } else {
        final raw = provider.gunlukDetaylar[dateKey];
        if (raw != null) detay = Map<String, dynamic>.from(raw);
      }
      if (detay != null) {
        for (var vakit in provider.vakitIsimleri) {
          if (detay[vakit] == true) {
            vakitFrekanslari[vakit] = (vakitFrekanslari[vakit] ?? 0) + 1;
          }
        }
      }
    }

    // En sadık vakit
    String enSadikVakit = "Sabah";
    int maxFrekans = 0;
    vakitFrekanslari.forEach((vakit, frekans) {
      if (frekans > maxFrekans) {
        maxFrekans = frekans;
        enSadikVakit = vakit;
      }
    });

    int haftalikXp = toplamVakit * SeviyeServisi.namazXp;
    // Tam gün bonuslarını ekle
    for (var count in gunlukSayilar) {
      if (count == 5) haftalikXp += SeviyeServisi.tamGunBonusu;
    }

    return {
      'gunlukSayilar': gunlukSayilar,
      'kazaSayilar': kazaSayilar,
      'toplamVakit': toplamVakit,
      'enSadikVakit': enSadikVakit,
      'enSadikFrekans': maxFrekans,
      'haftalikXp': haftalikXp,
    };
  }

  Future<void> _haftalikPaylasimYap(NamazProvider provider) async {
    try {
      final r = context.renklerOku; // Kendi yapına göre (renklerOku veya benzeri)
      final veri = _haftalikVeriHesapla(provider);
      final List<int> gunlukSayilar = veri['gunlukSayilar'];
      final int toplamVakit = veri['toplamVakit'];
      final String enSadikVakit = veri['enSadikVakit'];
      final int haftalikXp = veri['haftalikXp'];
      final gunAdlari = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];

      // 1. KRİTİK DEĞİŞİKLİK: Ekran genişliği yerine SABİT bir genişlik veriyoruz.
      // Bu sayede paylaşım görseli her zaman standart bir oranda (örneğin 400px genişlikte) oluşur.
      final double fixedWidth = 400.0; 

      final shareWidget = Container(
        width: fixedWidth,
        padding: const EdgeInsets.all(28), // Kenar boşluklarını biraz artırdım, daha ferah durur
        decoration: BoxDecoration(
          color: r.arkaPlanRengi, // Koyu tema arka planı
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Başlık Alanı
            Row(
              children: [
                Icon(Icons.bar_chart_rounded, color: r.anaRenk, size: 28),
                const SizedBox(width: 8),
                Text(
                  "Haftalık Özet",
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: r.yaziRengi,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: r.anaRenk.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    provider.mevcutUnvan, // Talip, Arif vb.
                    style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            
            // Bar Grafiği Alanı
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: List.generate(7, (i) {
                  final count = gunlukSayilar[i];
                  final barH = count == 0 ? 8.0 : (count / 5) * 120.0; // 120'ye çıkardım daha belirgin olsun
                  final isTam = count == 5;
                  
                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "$count",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: isTam ? r.anaRenk : r.yaziRengi.withOpacity(0.5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            height: barH,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(6),
                              gradient: isTam
                                  ? LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [r.anaRenk, r.anaRenk.withOpacity(0.7)],
                                    )
                                  : LinearGradient(
                                      begin: Alignment.bottomCenter,
                                      end: Alignment.topCenter,
                                      colors: [
                                        r.anaRenk.withOpacity(0.3),
                                        r.anaRenk.withOpacity(0.15),
                                      ],
                                    ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            gunAdlari[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: r.yaziRengi.withOpacity(0.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 24),
            Divider(color: r.pasifRenk.withOpacity(0.2), thickness: 1),
            const SizedBox(height: 16),
            
            // Metrikler Alanı
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _shareMetrik(r, Icons.mosque_rounded, "Toplam", "$toplamVakit vakit"),
                _shareMetrik(r, Icons.favorite_rounded, "En Sadık", enSadikVakit),
                _shareMetrik(r, Icons.star_rounded, "Kazanılan", "$haftalikXp XP"),
              ],
            ),
            const SizedBox(height: 24),
            
            // Alt Marka (Branding)
            Center(
              child: Text(
                "🌙 Takva Yolu ile paylaşıldı",
                style: TextStyle(
                  fontSize: 12,
                  color: r.yaziRengi.withOpacity(0.3),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      );

      // 2. KRİTİK DEĞİŞİKLİK: Directionality ekliyoruz.
      final image = await _screenshotController.captureFromWidget(
        Directionality(
          textDirection: ui.TextDirection.ltr,
          child: Material(
            color: Colors.transparent,
            child: shareWidget,
          ),
        ),
        pixelRatio: 3.0,
        delay: const Duration(milliseconds: 200),
      );

      if (!mounted) return;

      // Kullanıcıya seçenek sun
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: BoxDecoration(
            color: r.kartRengi,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: EdgeInsets.all(Responsive.w(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Yolculuğunu Paylaş",
                style: TextStyle(
                  fontSize: Responsive.sp(18),
                  fontWeight: FontWeight.bold,
                  color: r.yaziRengi,
                ),
              ),
              SizedBox(height: Responsive.h(20)),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: r.anaRenk.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.share_rounded, color: r.anaRenk),
                ),
                title: Text("Sosyal Medyada Paylaş", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w600)),
                subtitle: Text("WhatsApp, Instagram vb. dış mecralar", style: TextStyle(color: r.pasifRenk, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/takva_yolu_haftalik.png');
                  await file.writeAsBytes(image);
                  await Share.shareXFiles(
                    [XFile(file.path)],
                    text: '🌙 Takva Yolu | ${provider.mevcutUnvan} olarak bu hafta huzura durdum!\n#TakvaYolu',
                  );
                },
              ),
              SizedBox(height: 10),
              ListTile(
                leading: Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.history_toggle_off_rounded, color: Colors.purple),
                ),
                title: Text("Takva Yolun'da Paylaş", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w600)),
                subtitle: Text("Takva Yolu arkadaşlarının görebileceği hikaye", style: TextStyle(color: r.pasifRenk, fontSize: 12)),
                onTap: () async {
                  Navigator.pop(context);
                  try {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Hikaye yükleniyor..."), backgroundColor: r.anaRenk),
                    );
                    await provider.paylasHaftalikStory(image);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Hikayen başarıyla paylaşıldı!"), backgroundColor: Colors.green),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Hikaye paylaşılırken bir hata oluştu."), backgroundColor: Colors.red),
                    );
                  }
                },
              ),
              SizedBox(height: Responsive.h(20)),
            ],
          ),
        ),
      );
    } catch (e) {
      debugPrint('Paylaşım hatası: $e');
    }
  }

  Widget _shareMetrik(AppThemeColors r, IconData icon, String baslik, String deger) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: r.anaRenk, size: 20),
          SizedBox(height: 4),
          Text(deger, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, color: r.yaziRengi)),
          Text(baslik, style: TextStyle(fontSize: 10, color: r.yaziRengi.withOpacity(0.5))),
        ],
      ),
    );
  }

  Widget _buildHaftalikGrafik(BuildContext context, NamazProvider provider) {
    final veri = _haftalikVeriHesapla(provider);
    final List<int> gunlukSayilar = veri['gunlukSayilar'];
    final List<int> kazaSayilar = veri['kazaSayilar'];
    final int toplamVakit = veri['toplamVakit'];
    final String enSadikVakit = veri['enSadikVakit'];
    final int enSadikFrekans = veri['enSadikFrekans'];
    final int haftalikXp = veri['haftalikXp'];
    final gunAdlari = ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"];

    final r = context.renkler;

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bar_chart_rounded, color: r.anaRenk, size: Responsive.w(22)),
              SizedBox(width: Responsive.w(8)),
              Text(
                "Haftalık Özet",
                style: TextStyle(
                  fontSize: Responsive.sp(16),
                  fontWeight: FontWeight.w900,
                  color: r.yaziRengi,
                ),
              ),
              const Spacer(),
              Container(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(4)),
                decoration: BoxDecoration(
                  color: r.anaRenk.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(Responsive.w(8)),
                ),
                child: Text(
                  provider.mevcutUnvan,
                  style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(11)),
                ),
              ),
              IconButton(
                onPressed: () => _haftalikPaylasimYap(provider),
                icon: Icon(Icons.share_rounded, color: r.anaRenk, size: Responsive.w(20)),
                constraints: const BoxConstraints(),
                padding: EdgeInsets.only(left: Responsive.w(8)),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(20)),
          SizedBox(
            height: Responsive.h(200),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final count = gunlukSayilar[i];
                final kazaCount = kazaSayilar[i];

                // Toplam yükseklik sınırı: 130h (taşma engellendi)
                const double maxBarH = 120.0;
                final double normalH = count == 0 ? 6.0 : (count / 5) * maxBarH;
                final double kazaRaw = kazaCount == 0 ? 0.0 : (kazaCount / 20) * maxBarH;
                // Toplam max'u geçmesin
                final double kazaH = (normalH + kazaRaw) > Responsive.h(maxBarH)
                    ? Responsive.h(maxBarH) - Responsive.h(normalH)
                    : Responsive.h(kazaRaw);

                final isTam = count == 5;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(4)),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        SizedBox(height: Responsive.h(4)),

                        // Stacked Bar (kaza üstte, normal altta)
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (kazaCount > 0)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 600),
                                height: kazaH,
                                margin: EdgeInsets.only(bottom: Responsive.h(2)), 
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(Responsive.w(6)),
                                  color: r.anaRenk.withOpacity(0.2),
                                ),
                                child: Center(
                                  child: Text(
                                    "$kazaCount",
                                    style: TextStyle(
                                      fontSize: Responsive.sp(8),
                                      fontWeight: FontWeight.bold,
                                      color: r.yaziRengi,
                                    ),
                                  ),
                                ),
                              ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 600),
                              height: Responsive.h(normalH),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(Responsive.w(6)),
                                gradient: isTam
                                    ? LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [r.anaRenk, r.anaRenk.withOpacity(0.7)],
                                      )
                                    : LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          r.anaRenk.withOpacity(0.6),
                                          r.anaRenk.withOpacity(0.4),
                                        ],
                                      ),
                              ),
                              child: count > 0 
                                ? Center(
                                    child: Text(
                                      "$count",
                                      style: TextStyle(
                                        fontSize: Responsive.sp(9),
                                        fontWeight: FontWeight.bold,
                                        color: isTam ? Colors.white : r.yaziRengi,
                                      ),
                                    ),
                                  )
                                : null,
                            ),
                          ],
                        ),

                        SizedBox(height: Responsive.h(6)),
                        Text(
                          gunAdlari[i],
                          style: TextStyle(
                            fontSize: Responsive.sp(10),
                            fontWeight: FontWeight.w600,
                            color: r.yaziRengi.withOpacity(0.4),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
          // Lejant
          if (kazaSayilar.any((k) => k > 0)) ...
            [
              SizedBox(height: Responsive.h(8)),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: r.anaRenk, borderRadius: BorderRadius.circular(3))),
                  SizedBox(width: Responsive.w(4)),
                  Text("Farz", style: TextStyle(color: r.yaziRengi.withOpacity(0.5), fontSize: Responsive.sp(10))),
                  SizedBox(width: Responsive.w(12)),
                  Container(width: 10, height: 10, decoration: BoxDecoration(color: r.anaRenk.withOpacity(0.2), borderRadius: BorderRadius.circular(3))),
                  SizedBox(width: Responsive.w(4)),
                  Text("Kaza", style: TextStyle(color: r.yaziRengi.withOpacity(0.5), fontSize: Responsive.sp(10))),
                ],
              ),
            ],
          SizedBox(height: Responsive.h(20)),
          Divider(color: r.pasifRenk.withOpacity(0.1)),
          SizedBox(height: Responsive.h(12)),
          Row(
            children: [
              _buildMetrikKarti(
                r,
                icon: Icons.mosque_rounded,
                baslik: "Toplam Vakit",
                deger: "$toplamVakit",
                altMetin: "bu hafta",
              ),
              SizedBox(width: Responsive.w(8)),
              _buildMetrikKarti(
                r,
                icon: Icons.favorite_rounded,
                baslik: "En Sadık",
                deger: enSadikVakit,
                altMetin: "$enSadikFrekans/7 gün",
              ),
              SizedBox(width: Responsive.w(8)),
              _buildMetrikKarti(
                r,
                icon: Icons.star_rounded,
                baslik: "Takva Puanı",
                deger: "$haftalikXp",
                altMetin: "XP kazanıldı",
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final r = context.renkler;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        title: Text(
          "Vakit Analizi",
          style: TextStyle(
            color: r.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(18),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(Responsive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üstteki sayaçlar
            _buildKucukOzetKartlari(context, provider),

            SizedBox(height: Responsive.h(24)),

            // 🔥 Haftalık İstatistik Grafiği
            _buildHaftalikGrafik(context, provider),

            SizedBox(height: Responsive.h(24)),

            // Aylık Takvim Bölümü
            _buildAylikTakvim(context, provider),

            SizedBox(height: Responsive.h(24)),

            // Renk Skalası Bilgilendirmesi
            _buildRenkLejanti(context),

            SizedBox(height: Responsive.h(40)),
          ],
        ),
      ),
    );
  }

  // Üstteki seri ve toplam sayaçlarının küçültülmüş hali
  Widget _buildKucukOzetKartlari(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    return Row(
      children: [
        _kucukIstatistikKutusu(
          context,
          baslik: "Seri",
          deger: "${provider.streakCount}",
          ikon: Icons.local_fire_department,
          renk: r.anaRenk,
          customIcon: ColorFiltered(
            colorFilter: ColorFilter.mode(r.anaRenk, BlendMode.srcIn),
            child: Image.asset(
              'assets/images/streak_icon.png',
              width: Responsive.w(25),
              height: Responsive.w(25),
              fit: BoxFit.contain,
            ),
          ),
        ),
        SizedBox(width: Responsive.w(12)),
        _kucukIstatistikKutusu(
          context,
          baslik: "Toplam Vakit",
          deger: "${provider.toplamTamamlanan}",
          ikon: Icons.check_circle_rounded,
          renk: r.aktifYesil,
        ),
      ],
    );
  }

  Widget _kucukIstatistikKutusu(
    BuildContext context, {
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
    Widget? customIcon,
  }) {
    final r = context.renkler;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(Responsive.w(12)),
        decoration: BoxDecoration(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            customIcon ?? Icon(ikon, color: renk, size: Responsive.w(18)),
            SizedBox(width: Responsive.w(8)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    deger,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.sp(15),
                      fontWeight: FontWeight.bold,
                      color: r.yaziRengi,
                    ),
                  ),
                  Text(
                    baslik,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: Responsive.sp(10),
                      color: r.yaziRengi.withOpacity(0.5),
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

  Widget _buildMetrikKarti(
    AppThemeColors r, {
    required IconData icon,
    required String baslik,
    required String deger,
    required String altMetin,
  }) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(Responsive.w(10)),
        decoration: BoxDecoration(
          color: r.anaRenk.withOpacity(0.06),
          borderRadius: BorderRadius.circular(Responsive.w(12)),
        ),
        child: Column(
          children: [
            Icon(icon, color: r.anaRenk, size: Responsive.w(20)),
            SizedBox(height: Responsive.h(4)),
            Text(
              deger,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: Responsive.sp(14),
                color: r.yaziRengi,
              ),
            ),
            Text(
              baslik,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: Responsive.sp(9),
                color: r.yaziRengi.withOpacity(0.6),
              ),
            ),
            Text(
              altMetin,
              style: TextStyle(fontSize: Responsive.sp(8), color: r.pasifRenk),
            ),
          ],
        ),
      ),
    );
  }

  // Ana Takvim Widget'ı
  Widget _buildAylikTakvim(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    final sanalSimdi = provider.getSanalSimdi();
    final goruntulenen = _indexToDate(_currentPageIndex, sanalSimdi);
    final ayAdi = DateFormat('MMMM yyyy', 'tr_TR').format(goruntulenen);

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(Icons.chevron_left, color: r.anaRenk),
                onPressed: () => _oncekiAy(provider),
              ),
              Text(
                ayAdi.toUpperCase(),
                style: TextStyle(
                  fontSize: Responsive.sp(16),
                  fontWeight: FontWeight.w900,
                  color: r.anaRenk,
                  letterSpacing: 1.2,
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, color: r.anaRenk),
                onPressed: () => _sonrakiAy(provider),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(4)),
          Divider(color: r.anaRenk.withOpacity(0.1), thickness: 1),
          SizedBox(height: Responsive.h(12)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"].map((
              g,
            ) {
              return SizedBox(
                width: Responsive.w(35),
                child: Text(
                  g,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.sp(11),
                    fontWeight: FontWeight.bold,
                    color: r.yaziRengi.withOpacity(0.4),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: Responsive.h(10)),

          SizedBox(
            height: Responsive.h(
              300,
            ), // Takvim için sabit yükseklik (PageView gereği)
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentPageIndex = index;
                  final yeniTarih = _indexToDate(index, sanalSimdi);
                  provider.seciliAyDiniGunleriGetir(
                    yeniTarih.year,
                    yeniTarih.month,
                  );
                });
              },
              itemBuilder: (context, pageIndex) {
                final sayfaTarihi = _indexToDate(pageIndex, sanalSimdi);
                final ayinIlkGunu = DateTime(
                  sayfaTarihi.year,
                  sayfaTarihi.month,
                  1,
                );
                final ayinSonGunu = DateTime(
                  sayfaTarihi.year,
                  sayfaTarihi.month + 1,
                  0,
                ).day;
                final baslangicBoslugu = ayinIlkGunu.weekday - 1;

                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                    itemCount: ayinSonGunu + baslangicBoslugu,
                    itemBuilder: (context, index) {
                      if (index < baslangicBoslugu) return const SizedBox();

                      final gun = index - baslangicBoslugu + 1;
                      final hucreTarihi = DateTime(
                        sayfaTarihi.year,
                        sayfaTarihi.month,
                        gun,
                      );

                      final sanalBugunStr = provider.getSanalGun();
                      final sanalBugunObj = DateFormat(
                        'yyyy-MM-dd',
                      ).parse(sanalBugunStr);

                      int vakitSayisi;

                      if (hucreTarihi.isAfter(sanalBugunObj)) {
                        vakitSayisi = -1; // Gelecek günler
                      } else if (provider.ilkAcilisTarihi != null &&
                          hucreTarihi.isBefore(provider.ilkAcilisTarihi!)) {
                        vakitSayisi = -1; // Uygulama açılışından öncesi
                      } else {
                        String dateKey = DateFormat(
                          'yyyy-MM-dd',
                        ).format(hucreTarihi);
                        vakitSayisi = provider.aylikGecmis[dateKey] ?? 0;
                      }

                      bool isSanalBugun =
                          DateFormat('yyyy-MM-dd').format(hucreTarihi) ==
                          sanalBugunStr;

                      return _buildTakvimGunu(
                        context,
                        gun,
                        vakitSayisi,
                        hucreTarihi,
                        provider,
                        isSanalBugun: isSanalBugun,
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTakvimGunu(
    BuildContext context,
    int gun,
    int vakitSayisi,
    DateTime hucreTarihi,
    NamazProvider provider, {
    bool isSanalBugun = false,
  }) {
    final r = context.renkler;
    final String dateKey = DateFormat('yyyy-MM-dd').format(hucreTarihi);
    final ReligiousDay? religiousDay = provider.tumDiniGunler[dateKey];
    final String? diniGun = religiousDay?.turkishName;
    final bool isDiniGun = diniGun != null;

    final Map<int, Color> renkSkalasi = {
      -1: r.pasifRenk.withOpacity(0.15),
      0: const Color(0xFFFF6961),
      1: const Color(0xFFFCA364),
      2: const Color(0xFFF8D66D),
      3: const Color(0xFFD0D473),
      4: const Color(0xFFB0D476),
      5: const Color(0xFF8CD47E),
    };

    Color hucreRengi;
    if (isSanalBugun) {
      hucreRengi = r.pasifRenk.withOpacity(0.15);
    } else {
      hucreRengi = renkSkalasi[vakitSayisi] ?? r.pasifRenk.withOpacity(0.15);
    }

    bool tiklanabilir = (vakitSayisi != -1 && !isSanalBugun) || isDiniGun;

    BoxBorder? hucreCercevesi;
    List<BoxShadow>? hucreGolgeleri;

    if (isSanalBugun) {
      hucreCercevesi = Border.all(color: r.anaRenk, width: 2);
    } else if (isDiniGun) {
      hucreCercevesi = Border.all(
        color: const Color(0xFFFFD700),
        width: 2,
      ); // Altın sarısı çerçeve
      hucreGolgeleri = [
        BoxShadow(
          color: const Color(0xFFFFD700).withOpacity(0.4),
          blurRadius: 8,
          spreadRadius: 1,
        ),
      ];
    } else if (tiklanabilir) {
      hucreCercevesi = Border.all(color: Colors.black.withOpacity(0.05));
    }

    return GestureDetector(
      onTap: tiklanabilir
          ? () => _gunDetayiGoster(context, hucreTarihi, provider, vakitSayisi)
          : null,
      child: Tooltip(
        message: isDiniGun ? diniGun : "",
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: hucreRengi,
            borderRadius: BorderRadius.circular(Responsive.w(8)),
            border: hucreCercevesi,
            boxShadow: hucreGolgeleri,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (isDiniGun) ...[
                Positioned(
                  top: 2,
                  right: 2,
                  child: Icon(
                    Icons.star,
                    color: const Color(0xFFFFD700),
                    size: Responsive.w(8),
                  ),
                ),
              ],
              Center(
                child: Text(
                  "$gun",
                  style: TextStyle(
                    color: isSanalBugun
                        ? r.yaziRengi
                        : (tiklanabilir
                              ? Colors.white
                              : r.yaziRengi.withOpacity(0.4)),
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.sp(12),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _gunDetayiGoster(
    BuildContext context,
    DateTime tarih,
    NamazProvider provider,
    int toplamVakit,
  ) {
    // 🔥 HATA BURADAYDI: watch kullanan 'renkler' yerine 'renklerOku' kullanmalısın
    final r = context.renklerOku;

    String dateKey = DateFormat('yyyy-MM-dd').format(tarih);
    String displayDate = DateFormat(
      'dd MMMM yyyy, EEEE',
      'tr_TR',
    ).format(tarih);
    String bugunKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final ReligiousDay? religiousDay = provider.tumDiniGunler[dateKey];
    final String? diniGun = religiousDay?.turkishName;
    final String? diniGunAciklama = religiousDay?.description;

    // Veriyi güvenli çekme
    Map<String, dynamic> detaylar;
    if (dateKey == bugunKey) {
      detaylar = provider.kildiMi;
    } else {
      var data = provider.gunlukDetaylar[dateKey];
      detaylar = data != null ? Map<String, dynamic>.from(data) : {};
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(Responsive.w(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: r.pasifRenk.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              SizedBox(height: 20),
              Text(
                displayDate,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: r.yaziRengi,
                ),
              ),
              if (toplamVakit != -1)
                Text(
                  "$toplamVakit / 5 Vakit Kılındı",
                  style: TextStyle(
                    color: r.anaRenk,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 20),

              if (diniGun != null) ...[
                Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(Responsive.w(15)),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD700).withOpacity(0.1),
                    border: Border.all(color: const Color(0xFFFFD700)),
                    borderRadius: BorderRadius.circular(Responsive.w(12)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.star,
                            color: const Color(0xFFFFD700),
                            size: Responsive.w(20),
                          ),
                          SizedBox(width: Responsive.w(8)),
                          Text(
                            diniGun,
                            style: TextStyle(
                              fontSize: Responsive.sp(16),
                              fontWeight: FontWeight.bold,
                              color: r.yaziRengi,
                            ),
                          ),
                        ],
                      ),
                      if (diniGunAciklama != null) ...[
                        SizedBox(height: Responsive.h(8)),
                        Text(
                          diniGunAciklama,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: Responsive.sp(13),
                            color: r.yaziRengi.withOpacity(0.8),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              if (toplamVakit == -1)
                const SizedBox.shrink()
              else if (detaylar.isEmpty && toplamVakit > 0)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    "Bu güne ait detaylı veri bulunamadı.",
                    textAlign: TextAlign.center,
                  ),
                )
              else
                ...provider.vakitIsimleri.map((vakit) {
                  bool kilindiMi = detaylar[vakit] == true;
                  return ListTile(
                    leading: Icon(
                      kilindiMi
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: kilindiMi ? r.aktifYesil : r.pasifRenk,
                    ),
                    title: Text(
                      vakit,
                      style: TextStyle(
                        color: r.yaziRengi,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }),
              SizedBox(height: Responsive.h(20)),
            ],
          ),
        );
      },
    );
  }

  // Renklerin ne anlama geldiğini gösteren alt kısım
  Widget _buildRenkLejanti(BuildContext context) {
    final r = context.renkler;
    return Container(
      padding: EdgeInsets.all(Responsive.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Vakit Takibi Renk Skalası",
            style: TextStyle(
              fontSize: Responsive.sp(12),
              fontWeight: FontWeight.bold,
              color: r.yaziRengi.withOpacity(0.6),
            ),
          ),
          SizedBox(height: Responsive.h(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final Map<int, Color> renkler = {
                0: const Color(0xFFFF6961),
                1: const Color(0xFFFCA364),
                2: const Color(0xFFF8D66D),
                3: const Color(0xFFD0D473),
                4: const Color(0xFFB0D476),
                5: const Color(0xFF8CD47E),
              };
              return Column(
                children: [
                  Container(
                    width: Responsive.w(25),
                    height: Responsive.h(10),
                    decoration: BoxDecoration(
                      color: renkler[i],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: Responsive.h(4)),
                  Text(
                    "$i Vakit",
                    style: TextStyle(
                      fontSize: Responsive.sp(9),
                      color: r.yaziRengi.withOpacity(0.5),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
