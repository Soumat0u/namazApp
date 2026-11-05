import '../core/utils/bildirim.dart';
import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../services/kuran_okuyucu.dart';
import 'dart:async';

import '../services/kuran_hedefi.dart';
import 'widgets/ayet_metni.dart';
import 'widgets/kuran_hedef_karti.dart';

/// "Kaldığın yer" ve okuma ayarları (telefonda saklanır)
class KuranAyarlari {
  static Future<({int sure, int ayet})?> kaldigimYer() async {
    final p = await SharedPreferences.getInstance();
    final s = p.getInt('kuran_son_sure');
    final a = p.getInt('kuran_son_ayet');
    return s == null || a == null ? null : (sure: s, ayet: a);
  }

  static Future<void> kaldigimYeriKaydet(int sure, int ayet) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('kuran_son_sure', sure);
    await p.setInt('kuran_son_ayet', ayet);
  }
}

String _yer(String ham) => ham == 'Makkah' ? 'Mekkî' : 'Medenî';

/// Kur'an-ı Kerim: sure ve cüz listesi. Metin ve meal uygulamanın içindedir, internetsiz okunur.
class KuranScreen extends StatefulWidget {
  const KuranScreen({super.key});

  @override
  State<KuranScreen> createState() => _KuranScreenState();
}

class _KuranScreenState extends State<KuranScreen> {
  String _arama = '';
  ({int sure, int ayet})? _kaldigim;

  @override
  void initState() {
    super.initState();
    _kaldigimiYukle();
  }

  Future<void> _kaldigimiYukle() async {
    final k = await KuranAyarlari.kaldigimYer();
    if (mounted) setState(() => _kaldigim = k);
  }

  Future<void> _ac(int sure, [int ayet = 1]) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => KuranSureScreen(sure: sure, baslangicAyet: ayet)));
    _kaldigimiYukle();
  }

  String _normal(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[âáà]'), 'a')
      .replaceAll(RegExp('[îí]'), 'i')
      .replaceAll(RegExp('[ûú]'), 'u')
      .replaceAll('ı', 'i')
      .replaceAll("'", '')
      .replaceAll('-', ' ');

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    final sureler = [
      for (int s = 1; s <= 114; s++)
        if (_arama.isEmpty || _normal(quran.getSurahNameTurkish(s)).contains(_normal(_arama)) || '$s' == _arama) s,
    ];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: r.arkaPlanRengi,
        appBar: AppBar(
          leading: IconButton(
            tooltip: "Geri",
            icon: Icon(Icons.arrow_back_rounded, color: r.yaziRengi),
            onPressed: () => Navigator.maybePop(context),
          ),
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text("Kur'an-ı Kerim", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: r.anaRenk,
            unselectedLabelColor: r.pasifRenk,
            indicatorColor: r.anaRenk,
            tabs: const [Tab(text: "Sureler"), Tab(text: "Cüzler")],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.h(12), Responsive.w(16), 0),
              child: const KuranHedefKarti(),
            ),
            if (_kaldigim != null)
              Padding(
                padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.h(12), Responsive.w(16), 0),
                child: Material(
                  color: r.anaRenk.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(16),
                  child: ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    leading: Icon(Icons.bookmark_rounded, color: r.anaRenk),
                    title: Text("Kaldığın yer", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
                    subtitle: Text(
                      "${quran.getSurahNameTurkish(_kaldigim!.sure)} Suresi, ${_kaldigim!.ayet}. ayet",
                      style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold),
                    ),
                    trailing: Text("Devam et", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
                    onTap: () => _ac(_kaldigim!.sure, _kaldigim!.ayet),
                  ),
                ),
              ),
            Expanded(
              child: TabBarView(
                children: [
                  // Sureler
                  Column(
                    children: [
                      Padding(
                        padding: EdgeInsets.all(Responsive.w(16)),
                        child: TextField(
                          onChanged: (v) => setState(() => _arama = v.trim()),
                          style: TextStyle(color: r.yaziRengi),
                          decoration: InputDecoration(
                            hintText: "Sure ara (ör. Yasin, Mülk, 67)",
                            prefixIcon: const Icon(Icons.search_rounded),
                            filled: true,
                            fillColor: r.kartRengi,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: sureler.length,
                          itemBuilder: (_, i) {
                            final s = sureler[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: r.anaRenk.withOpacity(0.12),
                                child: Text("$s",
                                    style: TextStyle(
                                        color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
                              ),
                              title: Text(quran.getSurahNameTurkish(s),
                                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w600)),
                              subtitle: Text(
                                "${_yer(quran.getPlaceOfRevelation(s))} • ${quran.getVerseCount(s)} ayet",
                                style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11)),
                              ),
                              trailing: Text(quran.getSurahNameArabic(s),
                                  style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(18))),
                              onTap: () => _ac(s),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                  // Cüzler
                  GridView.count(
                    padding: EdgeInsets.all(Responsive.w(16)),
                    crossAxisCount: 3,
                    mainAxisSpacing: Responsive.w(10),
                    crossAxisSpacing: Responsive.w(10),
                    childAspectRatio: 1.3,
                    children: [
                      for (int c = 1; c <= 30; c++)
                        Builder(builder: (_) {
                          final bas = quran.getSurahAndVersesFromJuz(c).entries.first;
                          return InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _ac(bas.key, bas.value.first),
                            child: Container(
                              decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(14)),
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text("$c. Cüz",
                                      style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
                                  Text("${quran.getSurahNameTurkish(bas.key)} ${bas.value.first}",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10))),
                                ],
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bir sureyi okuma sayfası: Arapça + isteğe bağlı meal, yazı boyutu, kaldığın yer, sesli dinleme ve indirme
class KuranSureScreen extends StatefulWidget {
  final int sure;
  final int baslangicAyet;
  const KuranSureScreen({super.key, required this.sure, this.baslangicAyet = 1});

  @override
  State<KuranSureScreen> createState() => _KuranSureScreenState();
}

class _KuranSureScreenState extends State<KuranSureScreen> {
  late final KuranOkuyucu _okuyucu = KuranOkuyucu.sure(widget.sure);
  late final int _ayetSayisi = quran.getVerseCount(widget.sure);
  // Tembel liste: yalnızca ekrandaki ayetler çizilir (Bakara gibi uzun surelerde donmayı önler);
  // ayete numarasıyla atlanabilir.
  final ItemScrollController _kaydirma = ItemScrollController();
  // Günlük hedef: bir sayfa ekranda toplam 20 sn kalınca okunmuş sayılır
  // (hızla kaydırılıp geçilen sayfalar sayılmaz)
  final ItemPositionsListener _konumlar = ItemPositionsListener.create();
  final Map<int, int> _sayfaSuresi = {};
  Timer? _sayfaSayaci;
  static const _okunduEsigi = 20;
  bool get _besmele => widget.sure != 1 && widget.sure != 9; // Fâtiha'da 1. ayet, Tevbe besmelesiz
  int _ayetIndeksi(int ayet) => ayet - 1 + (_besmele ? 1 : 0);
  bool _mealGoster = true;
  double _yaziBoyutu = 26;
  int? _kaldigimAyet;
  bool _indirildi = false;
  double? _indirmeIlerlemesi;
  int? _sonTakip;

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
    _okuyucu.addListener(_okunaniTakipEt);
    KuranHedefi.ornek.yukle();
    _sayfaSayaci = Timer.periodic(const Duration(seconds: 1), (_) => _sayfalariSay());
  }

  void _sayfalariSay() {
    if (!mounted || WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) return;
    final sayfalar = <int>{};
    for (final k in _konumlar.itemPositions.value) {
      if (k.itemTrailingEdge <= 0 || k.itemLeadingEdge >= 1) continue; // ekranda değil
      final ayet = k.index + 1 - (_besmele ? 1 : 0);
      if (ayet < 1 || ayet > _ayetSayisi) continue;
      sayfalar.add(quran.getPageNumber(widget.sure, ayet));
    }
    for (final s in sayfalar) {
      final sure = (_sayfaSuresi[s] ?? 0) + 1;
      _sayfaSuresi[s] = sure;
      if (sure == _okunduEsigi) KuranHedefi.ornek.sayfaOkundu(s);
    }
  }

  Future<void> _ayarlariYukle() async {
    final p = await SharedPreferences.getInstance();
    final k = await KuranAyarlari.kaldigimYer();
    final indirildi = await KuranSesDeposu.indirildiMi(widget.sure);
    if (!mounted) return;
    setState(() {
      _mealGoster = p.getBool('kuran_meal_goster') ?? true;
      _yaziBoyutu = p.getDouble('kuran_yazi_boyutu') ?? 26;
      _kaldigimAyet = k?.sure == widget.sure ? k!.ayet : null;
      _indirildi = indirildi;
    });
    await _okuyucu.hizAyarla(p.getDouble('kuran_hiz') ?? 1.0);
  }

  void _ayeteGit(int ayet) {
    if (!_kaydirma.isAttached) return;
    _kaydirma.scrollTo(
      index: ayet <= 1 ? 0 : _ayetIndeksi(ayet),
      alignment: 0.05,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _okunaniTakipEt() {
    final i = _okuyucu.aktifIndex;
    if (i == null || i == _sonTakip) return;
    _sonTakip = i;
    _ayeteGit(i + 1);
    KuranAyarlari.kaldigimYeriKaydet(widget.sure, i + 1); // Dinlenen yer de kaldığın yer sayılır
    _kaldigimAyet = i + 1;
  }

  @override
  void dispose() {
    _sayfaSayaci?.cancel();
    _okuyucu.removeListener(_okunaniTakipEt);
    _okuyucu.dispose();
    super.dispose();
  }

  Future<void> _ayetSecenekleri(int ayet) async {
    final r = context.renklerOku; // Düğme olayında: dinlemeden oku
    final s = widget.sure;

    Widget secenek(BuildContext sheet, IconData ikon, String baslik, String aciklama, VoidCallback onTap) => Material(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              Navigator.pop(sheet);
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration:
                        BoxDecoration(color: r.anaRenk.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                    child: Icon(ikon, color: r.anaRenk, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(baslik, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: 15)),
                        Text(aciklama, style: TextStyle(color: r.pasifRenk, fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

    await showModalBottomSheet(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration:
                      BoxDecoration(color: r.pasifRenk.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 14),
              Text("${quran.getSurahNameTurkish(s)} Suresi, $ayet. Ayet",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 16),
              secenek(sheet, Icons.play_circle_rounded, "Buradan dinle", "Tilavet bu ayetten başlar",
                  () => _okuyucu.baslat(ayet - 1)),
              const SizedBox(height: 10),
              secenek(sheet, Icons.bookmark_add_rounded, "Kaldığım yer olarak işaretle",
                  "Kur'an'ı açınca buradan devam edersin", () async {
                await KuranAyarlari.kaldigimYeriKaydet(s, ayet);
                if (mounted) setState(() => _kaldigimAyet = ayet);
                Bildirim.snackBar(const SnackBar(content: Text("Kaldığın yer kaydedildi.")));
              }),
              const SizedBox(height: 10),
              secenek(sheet, Icons.share_rounded, "Paylaş", "Arapça metin ve meal", () {
                Share.share(
                  "${quran.getVerse(s, ayet)}\n\n"
                  "${quran.getVerseTranslation(s, ayet, translation: quran.Translation.trSaheeh)}\n\n"
                  "(${quran.getSurahNameTurkish(s)} Suresi, $ayet. Ayet)",
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }


  Future<void> _indirmeIslemi() async {
    if (_indirildi) {
      await KuranSesDeposu.sil(widget.sure);
      setState(() => _indirildi = false);
      Bildirim.snackBar(const SnackBar(content: Text("İndirilen ses silindi.")));
      return;
    }
    setState(() => _indirmeIlerlemesi = 0);
    final hata = await KuranSesDeposu.indir(widget.sure, ilerleme: (x) {
      if (mounted) setState(() => _indirmeIlerlemesi = x);
    });
    if (!mounted) return;
    setState(() {
      _indirmeIlerlemesi = null;
      _indirildi = hata == null;
    });
    Bildirim.snackBar(SnackBar(content: Text(hata ?? "İndirildi. Bu sure artık internetsiz dinlenebilir.")));
  }

  Future<void> _ayarlar() async {
    final r = context.renklerOku; // Düğme olayında: dinlemeden oku
    await showModalBottomSheet(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, yenile) {
          void guncelle(VoidCallback f) {
            setState(f);
            yenile(() {});
          }

          Widget kart({required IconData ikon, required String baslik, Widget? sag, Widget? alt}) => Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                              color: r.anaRenk.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: Icon(ikon, color: r.anaRenk, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(baslik,
                              style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                        if (sag != null) sag,
                      ],
                    ),
                    if (alt != null) ...[const SizedBox(height: 14), alt],
                  ],
                ),
              );

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: r.pasifRenk.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text("Okuma Ayarları",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: 18)),
                  const SizedBox(height: 16),

                  // Meal
                  kart(
                    ikon: Icons.translate_rounded,
                    baslik: "Meali göster",
                    sag: Switch(
                      value: _mealGoster,
                      activeColor: r.anaRenk,
                      onChanged: (v) {
                        guncelle(() => _mealGoster = v);
                        SharedPreferences.getInstance().then((p) => p.setBool('kuran_meal_goster', v));
                      },
                    ),
                  ),

                  // Okuma hızı: tek satırda eşit genişlikte seçenekler
                  kart(
                    ikon: Icons.speed_rounded,
                    baslik: "Okuma hızı",
                    alt: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                          color: r.arkaPlanRengi, borderRadius: BorderRadius.circular(14)),
                      child: Row(
                        children: [
                          for (final h in const [0.5, 0.75, 1.0, 1.25, 1.5])
                            Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  _okuyucu.hizAyarla(h);
                                  yenile(() {});
                                  SharedPreferences.getInstance().then((p) => p.setDouble('kuran_hiz', h));
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  decoration: BoxDecoration(
                                    color: _okuyucu.hiz == h ? r.anaRenk : Colors.transparent,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    h == 1.0 ? "1x" : "${h}x",
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                      color: _okuyucu.hiz == h ? Colors.white : r.yaziRengi.withOpacity(0.7),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Yazı boyutu: canlı Arapça önizleme
                  kart(
                    ikon: Icons.format_size_rounded,
                    baslik: "Yazı boyutu",
                    sag: Text("${_yaziBoyutu.round()}",
                        style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
                    alt: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                              color: r.arkaPlanRengi, borderRadius: BorderRadius.circular(12)),
                          child: Text(
                            quran.basmala,
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl,
                            maxLines: 1,
                            overflow: TextOverflow.fade,
                            softWrap: false,
                            style: TextStyle(fontSize: _yaziBoyutu, color: r.yaziRengi, height: 1.6),
                          ),
                        ),
                        Row(
                          children: [
                            Text("A", style: TextStyle(color: r.pasifRenk, fontSize: 13)),
                            Expanded(
                              child: Slider(
                                value: _yaziBoyutu,
                                min: 18,
                                max: 40,
                                divisions: 11,
                                activeColor: r.anaRenk,
                                inactiveColor: r.pasifRenk.withOpacity(0.2),
                                onChanged: (v) => guncelle(() => _yaziBoyutu = v),
                                onChangeEnd: (v) =>
                                    SharedPreferences.getInstance().then((p) => p.setDouble('kuran_yazi_boyutu', v)),
                              ),
                            ),
                            Text("A", style: TextStyle(color: r.pasifRenk, fontSize: 22, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    final s = widget.sure;
    final besmele = s != 1 && s != 9; // Fâtiha'da besmele 1. ayettir, Tevbe besmelesizdir

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        leading: IconButton(
          tooltip: "Geri",
          icon: Icon(Icons.arrow_back_rounded, color: r.yaziRengi),
          onPressed: () => Navigator.maybePop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Column(
          children: [
            Text(quran.getSurahNameTurkish(s),
                style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(17))),
            Text("${_yer(quran.getPlaceOfRevelation(s))} • $_ayetSayisi ayet",
                style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
          ],
        ),
        actions: [
          _indirmeIlerlemesi != null
              ? Padding(
                  padding: const EdgeInsets.all(14),
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(value: _indirmeIlerlemesi, strokeWidth: 2.5, color: r.anaRenk),
                  ),
                )
              : IconButton(
                  tooltip: _indirildi ? "İndirilen sesi sil" : "Sesi indir (internetsiz dinle)",
                  icon: Icon(_indirildi ? Icons.download_done_rounded : Icons.download_rounded, color: r.anaRenk),
                  onPressed: _indirmeIslemi,
                ),
          IconButton(icon: Icon(Icons.tune_rounded, color: r.anaRenk), onPressed: _ayarlar),
        ],
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _okuyucu,
        builder: (context, _) {
          if (_okuyucu.hata != null) {
            final h = _okuyucu.hata!;
            _okuyucu.hata = null;
            WidgetsBinding.instance.addPostFrameCallback((_) => Bildirim.snackBar(SnackBar(
                content: Text(_indirildi ? h : "$h İnternetsiz dinlemek için sağ üstten sureyi indirebilirsin."))));
          }
          return FloatingActionButton(
            backgroundColor: r.anaRenk,
            // Okuma başlamamışsa kaldığın ayetten başla
            onPressed: () => _okuyucu.aktifIndex == null
                ? _okuyucu.baslat((_kaldigimAyet ?? widget.baslangicAyet) - 1)
                : _okuyucu.calDuraklat(),
            child: _okuyucu.yukleniyor
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Icon(_okuyucu.caliyor ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
          );
        },
      ),
      // Kaldığın ayet doğrudan açılır (listede konum indeksle sabitlenir; ayarlar yüklenince kaymaz)
      body: ScrollablePositionedList.builder(
        itemScrollController: _kaydirma,
        itemPositionsListener: _konumlar,
        initialScrollIndex: widget.baslangicAyet <= 1 ? 0 : _ayetIndeksi(widget.baslangicAyet),
        initialAlignment: widget.baslangicAyet <= 1 ? 0 : 0.05,
        padding: EdgeInsets.fromLTRB(Responsive.w(16), 0, Responsive.w(16), 100),
        itemCount: _ayetSayisi + (besmele ? 1 : 0),
        itemBuilder: (context, i) {
          if (besmele && i == 0) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: Responsive.h(16)),
              child: Text(quran.basmala,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: _yaziBoyutu, color: r.anaRenk, height: 1.8)),
            );
          }
          return _ayet(r, i + 1 - (besmele ? 1 : 0));
        },
      ),
    );
  }

  Widget _ayet(AppThemeColors r, int a) {
    final s = widget.sure;
    final kaldigim = _kaldigimAyet == a;
    final cuzBasi = a == 1 ? quran.getJuzNumber(s, 1) != (s > 1 ? quran.getJuzNumber(s - 1, quran.getVerseCount(s - 1)) : 0)
        : quran.getJuzNumber(s, a) != quran.getJuzNumber(s, a - 1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cuzBasi)
          Padding(
            padding: EdgeInsets.symmetric(vertical: Responsive.h(8)),
            child: Text("— ${quran.getJuzNumber(s, a)}. Cüz —",
                textAlign: TextAlign.center,
                style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
          ),
        GestureDetector(
          // Dokun: buradan oku • Basılı tut: kaldığım yer / paylaş
          onTap: () => _okuyucu.baslat(a - 1),
          onLongPress: () => _ayetSecenekleri(a),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            margin: EdgeInsets.only(bottom: Responsive.h(10)),
            padding: EdgeInsets.all(Responsive.w(14)),
            decoration: BoxDecoration(
              color: r.kartRengi,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: kaldigim ? r.anaRenk.withOpacity(0.6) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: r.anaRenk.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                      child: Text("$a",
                          style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(11))),
                    ),
                    if (kaldigim) ...[
                      const SizedBox(width: 6),
                      Icon(Icons.bookmark_rounded, size: 16, color: r.anaRenk),
                    ],
                    if (quran.isSajdahVerse(s, a)) ...[
                      const SizedBox(width: 6),
                      Text("۩ Secde ayeti", style: TextStyle(color: r.anaRenk, fontSize: Responsive.sp(11))),
                    ],
                  ],
                ),
                SizedBox(height: Responsive.h(6)),
                AyetMetni(
                  okuyucu: _okuyucu,
                  sure: s,
                  ayet: a,
                  stil: TextStyle(fontSize: _yaziBoyutu, height: 1.9, color: r.yaziRengi),
                ),
                if (_mealGoster) ...[
                  SizedBox(height: Responsive.h(8)),
                  Text(
                    quran.getVerseTranslation(s, a, translation: quran.Translation.trSaheeh),
                    style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(13), height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
