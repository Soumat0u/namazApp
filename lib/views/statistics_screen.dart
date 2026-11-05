import '../core/utils/bildirim.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import 'widgets/bolum_paneli.dart';
import '../providers/namaz_provider.dart';
import 'package:intl/intl.dart';
import '../models/religious_day.dart';
import '../services/seviye_servisi.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/kuran_hedefi.dart';
import '../services/ansiklopedi_servisi.dart';

class IstatistikSayfasi extends StatefulWidget {
  const IstatistikSayfasi({super.key});

  @override
  State<IstatistikSayfasi> createState() => _IstatistikSayfasiState();
}

class _IstatistikSayfasiState extends State<IstatistikSayfasi> {
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
      final ibadetler = await _haftalikIbadetler(provider);
      final rozetler = provider.rozetler.where((x) => x.kazanildi).toList();
      final toplamRozet = provider.rozetler.length;


      // Haftalık karne: tek bakışta okunan, kompakt paylaşım görseli
      final sanalBugun = DateFormat('yyyy-MM-dd').parse(provider.getSanalGun());
      final pzt = sanalBugun.subtract(Duration(days: sanalBugun.weekday - 1));
      final paz = pzt.add(const Duration(days: 6));
      final aralik = pzt.month == paz.month
          ? "${pzt.day}–${DateFormat('d MMMM y', 'tr_TR').format(paz)}"
          : "${DateFormat('d MMM', 'tr_TR').format(pzt)} – ${DateFormat('d MMM y', 'tr_TR').format(paz)}";
      final oran = toplamVakit / 35;
      final shareWidget = Container(
        width: 400,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: r.arkaPlanRengi,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Başlık
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("HAFTALIK KARNE",
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: r.yaziRengi)),
                      const SizedBox(height: 2),
                      Text(aralik, style: TextStyle(fontSize: 12, color: r.yaziRengi.withOpacity(0.55))),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(color: r.anaRenk, borderRadius: BorderRadius.circular(10)),
                  child: Text(provider.mevcutUnvan,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Namaz: halka + 7 günlük şerit
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  SizedBox(
                    width: 74,
                    height: 74,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: oran.clamp(0.0, 1.0),
                            strokeWidth: 7,
                            strokeCap: StrokeCap.round,
                            backgroundColor: r.anaRenk.withOpacity(0.12),
                            valueColor: AlwaysStoppedAnimation(r.anaRenk),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("$toplamVakit",
                                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: r.yaziRengi, height: 1)),
                            Text("/ 35", style: TextStyle(fontSize: 10, color: r.yaziRengi.withOpacity(0.5))),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Namaz", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: r.yaziRengi)),
                        Text("En sadık vakit: $enSadikVakit",
                            style: TextStyle(fontSize: 11, color: r.yaziRengi.withOpacity(0.55))),
                        const SizedBox(height: 10),
                        Row(
                          children: List.generate(7, (i) {
                            final c = gunlukSayilar[i];
                            return Expanded(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 2),
                                child: Column(
                                  children: [
                                    Container(
                                      height: 24,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: c == 0
                                            ? r.pasifRenk.withOpacity(0.12)
                                            : r.anaRenk.withOpacity(0.25 + 0.75 * c / 5),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(c == 5 ? "✓" : "$c",
                                          style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w900,
                                              color: c >= 3 ? Colors.white : r.yaziRengi.withOpacity(0.7))),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(gunAdlari[i],
                                        style: TextStyle(fontSize: 9, color: r.yaziRengi.withOpacity(0.45))),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Diğer ibadetler: karne satırları (iki sütun)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(16)),
              child: Column(
                children: [
                  for (int i = 0; i < ibadetler.length; i += 2)
                    Container(
                      decoration: BoxDecoration(
                        border: i + 2 < ibadetler.length
                            ? Border(bottom: BorderSide(color: r.pasifRenk.withOpacity(0.15)))
                            : null,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: _karneSatiri(r, ibadetler[i])),
                          Container(width: 1, height: 22, color: r.pasifRenk.withOpacity(0.15)),
                          Expanded(
                            child: i + 1 < ibadetler.length
                                ? Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: _karneSatiri(r, ibadetler[i + 1]),
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Rozetler: yalnızca simgeler, kompakt
            Container(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(16)),
              child: Row(
                children: [
                  Icon(Icons.military_tech_rounded, size: 18, color: Colors.amber.shade700),
                  const SizedBox(width: 6),
                  Text("${rozetler.length}/$toplamRozet",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: r.yaziRengi)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: rozetler.isEmpty
                        ? Text("Henüz rozet yok", style: TextStyle(fontSize: 11, color: r.yaziRengi.withOpacity(0.5)))
                        : Wrap(
                            spacing: 5,
                            runSpacing: 5,
                            children: [
                              for (final rz in rozetler)
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.amber.withOpacity(0.18),
                                    border: Border.all(color: Colors.amber.withOpacity(0.55)),
                                  ),
                                  child: Icon(rz.ikon, size: 13, color: Colors.amber.shade800),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.star_rounded, size: 14, color: r.anaRenk),
                const SizedBox(width: 4),
                Text("Bu hafta $haftalikXp XP",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: r.anaRenk)),
                Text("  ·  🌙 Takva Yolu",
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: r.yaziRengi.withOpacity(0.35))),
              ],
            ),
          ],
        ),
      );

      // 2. KRİTİK DEĞİŞİKLİK: Directionality ekliyoruz.
      // captureFromWidget ekran boyutunda çeker ve taşan kısmı keser (rozetler kayboluyordu);
      // captureFromLongWidget içeriğin gerçek yüksekliğini kullanır
      Future<Uint8List> yakala(double pixelRatio) => _screenshotController.captureFromLongWidget(
            Directionality(
              textDirection: ui.TextDirection.ltr,
              child: Material(
                color: Colors.transparent,
                child: shareWidget,
              ),
            ),
            pixelRatio: pixelRatio,
            delay: const Duration(milliseconds: 200),
            context: context,
            constraints: const BoxConstraints(maxWidth: 400),
          );
      final image = await yakala(3.0);

      // Takva Yolu hikayesi Firestore belgesinde base64 olarak saklanır; belge
      // sınırı 1 MiB. Görsel sığmıyorsa daha düşük çözünürlükte yeniden çekilir.
      Future<Uint8List?> hikayeGorseli() async {
        const sinir = 900 * 1024; // base64 hali + diğer alanlar için pay
        bool sigar(Uint8List b) => (b.length + 2) ~/ 3 * 4 < sinir;
        if (sigar(image)) return image;
        for (final oran in [2.0, 1.5, 1.0]) {
          final b = await yakala(oran);
          if (sigar(b)) return b;
        }
        return null;
      }

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
                    Bildirim.snackBar(
                      SnackBar(content: Text("Hikaye yükleniyor..."), backgroundColor: r.anaRenk),
                    );
                    final gorsel = await hikayeGorseli();
                    if (gorsel == null) {
                      Bildirim.snackBar(
                        const SnackBar(content: Text("Görsel hikaye için çok büyük, paylaşılamadı."), backgroundColor: Colors.red),
                      );
                      return;
                    }
                    await provider.paylasHaftalikStory(gorsel);
                    Bildirim.snackBar(
                      SnackBar(content: Text("Hikayen başarıyla paylaşıldı!"), backgroundColor: Colors.green),
                    );
                  } on StateError {
                    Bildirim.snackBar(
                      SnackBar(content: Text("Hikaye paylaşmak için Takva Yolu hesabına giriş yapmalısın."), backgroundColor: Colors.red),
                    );
                  } catch (e) {
                    Bildirim.snackBar(
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

  /// Bu haftanın (Pzt–Paz) namaz dışı ibadetleri (karnede sıfırlar "—" gösterilir)
  Future<List<({IconData ikon, String deger, String baslik, String? alt})>> _haftalikIbadetler(
      NamazProvider provider) async {
    final sanalBugun = DateFormat('yyyy-MM-dd').parse(provider.getSanalGun());
    final pazartesi = sanalBugun.subtract(Duration(days: sanalBugun.weekday - 1));
    final gunler = [for (int i = 0; i < 7; i++) DateFormat('yyyy-MM-dd').format(pazartesi.add(Duration(days: i)))];
    int topla(Map<String, int> m) => gunler.fold(0, (t, g) => t + (m[g] ?? 0));

    await KuranHedefi.ornek.yukle();
    final kuran = gunler.fold<int>(0, (t, g) => t + (KuranHedefi.ornek.gecmis[g] ?? 0));
    final prefs = await SharedPreferences.getInstance();
    int makale = 0;
    try {
      final tarihler = json.decode(prefs.getString(AnsiklopediServisi.okunmaTarihiAnahtari) ?? '{}') as Map;
      makale = tarihler.values.where((t) => gunler.contains(t)).length;
    } catch (_) {}

    final kazaNamaz = topla(provider.kazaGecmisi);
    final oruc = gunler.where(provider.orucGunleri.contains).length;
    final kazaOruc = gunler.where(provider.kazaOrucGunleri.contains).length;
    final teravih = gunler.where(provider.teravihGunleri.contains).length;
    final zikir = topla(provider.zikirGecmisi);

    return [
      (ikon: Icons.history_rounded, deger: kazaNamaz > 0 ? "$kazaNamaz" : "—", baslik: "Kaza namazı", alt: null),
      (
        ikon: Icons.nightlight_round,
        deger: oruc > 0 ? "$oruc gün" : "—",
        baslik: "Oruç",
        alt: kazaOruc > 0 ? "$kazaOruc kaza" : null,
      ),
      (ikon: Icons.menu_book_rounded, deger: kuran > 0 ? "$kuran sf." : "—", baslik: "Kur'an", alt: null),
      (ikon: Icons.radio_button_checked_rounded, deger: zikir > 0 ? "$zikir" : "—", baslik: "Zikir", alt: null),
      (ikon: Icons.auto_stories_rounded, deger: makale > 0 ? "$makale" : "—", baslik: "Makale", alt: null),
      if (teravih > 0) (ikon: Icons.mosque_outlined, deger: "$teravih gece", baslik: "Teravih", alt: null)
      else (ikon: Icons.star_rounded, deger: "${provider.streakCount}", baslik: "Seri (gün)", alt: null),
    ];
  }

  Widget _karneSatiri(AppThemeColors r, ({IconData ikon, String deger, String baslik, String? alt}) i) {
    final bos = i.deger == "—";
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(
        children: [
          Icon(i.ikon, size: 15, color: bos ? r.pasifRenk.withOpacity(0.5) : r.anaRenk),
          const SizedBox(width: 7),
          Expanded(
            child: Text(i.baslik,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: r.yaziRengi.withOpacity(0.7))),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(i.deger,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: bos ? r.yaziRengi.withOpacity(0.3) : r.yaziRengi)),
              if (i.alt != null)
                Text(i.alt!, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: r.anaRenk)),
            ],
          ),
          const SizedBox(width: 4),
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
          SizedBox(height: Responsive.h(16)),
          // Grafik yüksekliği en uzun sütuna göre: boş haftada kart gereksiz yer kaplamaz
          if (!gunlukSayilar.any((c) => c > 0) && !kazaSayilar.any((k) => k > 0))
            Padding(
              padding: EdgeInsets.only(bottom: Responsive.h(10)),
              child: Text(
                "Bu hafta henüz namaz işaretlenmedi.",
                style: TextStyle(fontSize: Responsive.sp(12), color: r.yaziRengi.withOpacity(0.5)),
              ),
            ),
          SizedBox(
            height: Responsive.h(_grafikYuksekligi(gunlukSayilar, kazaSayilar) + 30),
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

  /// Haftalık grafikte en uzun sütunun yüksekliği (sütunlarla aynı ölçek: 5 vakit = 120)
  double _grafikYuksekligi(List<int> gunluk, List<int> kaza) {
    double enUzun = 6;
    for (int i = 0; i < gunluk.length; i++) {
      final h = (gunluk[i] / 5) * 120.0 + (kaza[i] == 0 ? 0.0 : (kaza[i] / 20) * 120.0 + 2);
      if (h > enUzun) enUzun = h;
    }
    return enUzun.clamp(6.0, 122.0) + 4;
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final r = context.renkler;

    return Scaffold(
      backgroundColor: Colors.transparent, // Zemini ana iskeletteki arka plan çizer
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
        // Alt boşluk: içerik yüzen menünün arkasından geçer, son öğe menünün üstüne kaydırılabilir
        padding: EdgeInsets.all(Responsive.w(16)).copyWith(
          bottom: Responsive.w(16) + MediaQuery.paddingOf(context).bottom,
        ),
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

            // 🌙 Oruç ve Ramazan
            if (provider.ramazanda || provider.orucGunleri.isNotEmpty || provider.kazaOrucBorcu > 0) ...[
              _buildOrucPaneli(context, provider),
              SizedBox(height: Responsive.h(24)),
            ],

            // 🏅 Rozetler
            _buildRozetler(context, provider),

            SizedBox(height: Responsive.h(40)),
          ],
        ),
      ),
    );
  }

  Widget _buildOrucPaneli(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    final simdi = DateTime.now();
    final yil = '${simdi.year}-';
    final ay = DateFormat('yyyy-MM').format(simdi);
    final buYil = provider.orucGunleri.where((g) => g.startsWith(yil)).length;
    final buAy = provider.orucGunleri.where((g) => g.startsWith(ay)).length;
    final gunler = provider.buRamazaninGunleri;
    final bugun = DateFormat('yyyy-MM-dd').format(simdi);
    final ramazanTutulan = gunler.where(provider.orucGunleri.contains).length;
    final ramazanTeravih = gunler.where(provider.teravihGunleri.contains).length;

    Widget metrik(String deger, String ad, IconData ikon) => Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
            decoration: BoxDecoration(color: r.icYuzey, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Icon(ikon, color: r.anaRenk, size: Responsive.w(18)),
                Text(deger, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(18))),
                Text(ad, textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10))),
              ],
            ),
          ),
        );

    return BolumPaneli(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(Responsive.w(16)),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.nightlight_round, color: r.anaRenk, size: Responsive.w(20)),
            SizedBox(width: Responsive.w(8)),
            Text(provider.ramazanda ? "Ramazan" : "Oruç",
                style: TextStyle(fontSize: Responsive.sp(17), fontWeight: FontWeight.w900, color: r.yaziRengi)),
            const Spacer(),
            if (provider.ramazanda)
              Text("${provider.ramazanGunu}. gün",
                  style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(13))),
          ],
        ),
        if (provider.ramazanda) ...[
          SizedBox(height: Responsive.h(12)),
          // Ramazan'ın günleri: tutulan oruçlar dolu, teravih kılınan geceler yıldızlı
          GridView.count(
            crossAxisCount: 10,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 5,
            crossAxisSpacing: 5,
            children: [
              for (int i = 0; i < gunler.length; i++)
                Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: provider.orucGunleri.contains(gunler[i])
                        ? r.anaRenk
                        : gunler[i].compareTo(bugun) < 0
                            ? r.kartUstunde(r.kirmizi, 0.12)
                            : r.icYuzey,
                    borderRadius: BorderRadius.circular(8),
                    border: gunler[i] == bugun ? Border.all(color: r.anaRenk, width: 2) : null,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text("${i + 1}",
                          style: TextStyle(
                            fontSize: Responsive.sp(10),
                            fontWeight: FontWeight.bold,
                            color: provider.orucGunleri.contains(gunler[i]) ? Colors.white : r.yaziRengi.withOpacity(0.6),
                          )),
                      if (provider.teravihGunleri.contains(gunler[i]))
                        Positioned(
                          top: 1,
                          right: 1,
                          child: Icon(Icons.star_rounded, size: Responsive.w(8),
                              color: provider.orucGunleri.contains(gunler[i]) ? Colors.white : r.anaRenk),
                        ),
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: Responsive.h(8)),
          Text("Dolu: oruç tutuldu  •  ★: teravih kılındı  •  kırmızımsı: tutulmadı",
              style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10))),
          SizedBox(height: Responsive.h(12)),
          Row(
            children: [
              metrik("$ramazanTutulan", "Ramazan\norucu", Icons.nightlight_round),
              SizedBox(width: Responsive.w(8)),
              metrik("$ramazanTeravih", "Teravih", Icons.mosque_rounded),
              SizedBox(width: Responsive.w(8)),
              metrik("${provider.kazaOrucBorcu}", "Kaza\nborcu", Icons.event_repeat_rounded),
            ],
          ),
        ] else ...[
          SizedBox(height: Responsive.h(12)),
          Row(
            children: [
              metrik("$buAy", "Bu ay", Icons.calendar_month_rounded),
              SizedBox(width: Responsive.w(8)),
              metrik("$buYil", "Bu yıl", Icons.nightlight_round),
              SizedBox(width: Responsive.w(8)),
              metrik("${provider.kazaOrucBorcu}", "Kaza\nborcu", Icons.event_repeat_rounded),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRozetler(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    final rozetler = provider.rozetler;
    final kazanilan = rozetler.where((x) => x.kazanildi).length;
    return BolumPaneli(
      margin: EdgeInsets.zero,
      padding: EdgeInsets.all(Responsive.w(16)),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text("Rozetler",
                style: TextStyle(fontSize: Responsive.sp(17), fontWeight: FontWeight.w900, color: r.yaziRengi)),
            const Spacer(),
            Text("$kazanilan / ${rozetler.length}",
                style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(13))),
          ],
        ),
        SizedBox(height: Responsive.h(12)),
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Responsive.h(10),
          crossAxisSpacing: Responsive.w(8),
          childAspectRatio: 0.78,
          children: [
            for (final rozet in rozetler)
              Tooltip(
                message: rozet.aciklama,
                triggerMode: TooltipTriggerMode.tap,
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: Responsive.w(52),
                          height: Responsive.w(52),
                          child: CircularProgressIndicator(
                            value: rozet.ilerleme,
                            strokeWidth: 3,
                            backgroundColor: r.pasifRenk.withOpacity(0.15),
                            color: rozet.kazanildi ? Colors.amber : r.anaRenk.withOpacity(0.5),
                          ),
                        ),
                        CircleAvatar(
                          radius: Responsive.w(21),
                          backgroundColor: rozet.kazanildi ? r.kartUstunde(Colors.amber, 0.18) : r.icYuzey,
                          child: Icon(rozet.ikon,
                              color: rozet.kazanildi ? Colors.amber.shade700 : r.pasifRenk.withOpacity(0.5),
                              size: Responsive.w(22)),
                        ),
                      ],
                    ),
                    SizedBox(height: Responsive.h(6)),
                    Text(
                      rozet.ad,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: TextStyle(
                        fontSize: Responsive.sp(10),
                        fontWeight: FontWeight.bold,
                        color: rozet.kazanildi ? r.yaziRengi : r.pasifRenk,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
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
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  // Büyük yazıda sütuna sığsın diye en fazla 1,2 kat büyür
                  textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
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

          // Yükseklik görüntülenen ayın satır sayısına göre (5 ya da 6 hafta): altta boşluk kalmaz
          LayoutBuilder(builder: (context, kisit) {
            final ilk = DateTime(goruntulenen.year, goruntulenen.month, 1);
            final gunSayisi = DateTime(goruntulenen.year, goruntulenen.month + 1, 0).day;
            final satir = ((ilk.weekday - 1 + gunSayisi) / 7).ceil();
            final hucre = (kisit.maxWidth - 2 * Responsive.w(8) - 6 * 8) / 7;
            final yukseklik = satir * hucre + (satir - 1) * 8 + 2;
            return AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: yukseklik,
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
            );
          }),
          // Renk skalası takvim kartının içinde, ızgaranın hemen altında
          SizedBox(height: Responsive.h(14)),
          _buildRenkLejanti(context),
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
              if (provider.orucGunleri.contains(dateKey))
                Positioned(
                  bottom: 2,
                  left: 2,
                  child: Icon(
                    Icons.nightlight_round,
                    color: Colors.white,
                    size: Responsive.w(8),
                  ),
                ),
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
    // Gece yarısı ile sabah arası hâlâ dünkü dini gündeyiz (canlı veri o güne ait)
    String bugunKey = provider.getSanalGun();

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
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(8)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
