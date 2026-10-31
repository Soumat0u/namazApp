import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../services/kuran_okuyucu.dart';
import 'widgets/ayet_metni.dart';

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
  late final List<GlobalKey> _anahtarlar = List.generate(_ayetSayisi, (_) => GlobalKey());
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _ayeteGit(widget.baslangicAyet, animasyonlu: false));
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
  }

  void _ayeteGit(int ayet, {bool animasyonlu = true}) {
    if (ayet <= 1) return;
    final ctx = _anahtarlar[ayet - 1].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(ctx,
        alignment: 0.05,
        duration: animasyonlu ? const Duration(milliseconds: 600) : Duration.zero,
        curve: Curves.easeInOut);
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
    _okuyucu.removeListener(_okunaniTakipEt);
    _okuyucu.dispose();
    super.dispose();
  }

  Future<void> _ayetSecenekleri(int ayet) async {
    final r = context.renkler;
    final messenger = ScaffoldMessenger.of(context);
    await showModalBottomSheet(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      builder: (sheet) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.bookmark_add_rounded, color: r.anaRenk),
              title: const Text("Kaldığım yer olarak işaretle"),
              onTap: () async {
                Navigator.pop(sheet);
                await KuranAyarlari.kaldigimYeriKaydet(widget.sure, ayet);
                setState(() => _kaldigimAyet = ayet);
                messenger.showSnackBar(const SnackBar(content: Text("Kaldığın yer kaydedildi.")));
              },
            ),
            ListTile(
              leading: Icon(Icons.play_circle_rounded, color: r.anaRenk),
              title: const Text("Buradan dinle"),
              onTap: () {
                Navigator.pop(sheet);
                _okuyucu.baslat(ayet - 1);
              },
            ),
            ListTile(
              leading: Icon(Icons.share_rounded, color: r.anaRenk),
              title: const Text("Paylaş"),
              onTap: () {
                Navigator.pop(sheet);
                Share.share(
                  "${quran.getVerse(widget.sure, ayet)}\n\n"
                  "${quran.getVerseTranslation(widget.sure, ayet, translation: quran.Translation.trSaheeh)}\n\n"
                  "(${quran.getSurahNameTurkish(widget.sure)} Suresi, $ayet. Ayet)",
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _indirmeIslemi() async {
    final messenger = ScaffoldMessenger.of(context);
    if (_indirildi) {
      await KuranSesDeposu.sil(widget.sure);
      setState(() => _indirildi = false);
      messenger.showSnackBar(const SnackBar(content: Text("İndirilen ses silindi.")));
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
    messenger.showSnackBar(SnackBar(content: Text(hata ?? "İndirildi. Bu sure artık internetsiz dinlenebilir.")));
  }

  Future<void> _ayarlar() async {
    final r = context.renkler;
    await showModalBottomSheet(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, yenile) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  value: _mealGoster,
                  activeColor: r.anaRenk,
                  title: const Text("Meali göster"),
                  onChanged: (v) {
                    setState(() => _mealGoster = v);
                    yenile(() {});
                    SharedPreferences.getInstance().then((p) => p.setBool('kuran_meal_goster', v));
                  },
                ),
                ListTile(
                  title: const Text("Yazı boyutu"),
                  subtitle: Slider(
                    value: _yaziBoyutu,
                    min: 18,
                    max: 40,
                    divisions: 11,
                    activeColor: r.anaRenk,
                    label: _yaziBoyutu.round().toString(),
                    onChanged: (v) {
                      setState(() => _yaziBoyutu = v);
                      yenile(() {});
                    },
                    onChangeEnd: (v) => SharedPreferences.getInstance().then((p) => p.setDouble('kuran_yazi_boyutu', v)),
                  ),
                ),
              ],
            ),
          ),
        ),
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
            WidgetsBinding.instance.addPostFrameCallback((_) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                content: Text(_indirildi ? h : "$h İnternetsiz dinlemek için sağ üstten sureyi indirebilirsin."))));
          }
          return FloatingActionButton(
            backgroundColor: r.anaRenk,
            onPressed: _okuyucu.calDuraklat,
            child: _okuyucu.yukleniyor
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : Icon(_okuyucu.caliyor ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(Responsive.w(16), 0, Responsive.w(16), 100),
        child: ListenableBuilder(
          listenable: _okuyucu,
          builder: (context, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (besmele)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: Responsive.h(16)),
                  child: Text(quran.basmala,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: _yaziBoyutu, color: r.anaRenk, height: 1.8)),
                ),
              for (int a = 1; a <= _ayetSayisi; a++) _ayet(r, a),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ayet(AppThemeColors r, int a) {
    final s = widget.sure;
    final okunuyor = _okuyucu.aktifIndex == a - 1;
    final kaldigim = _kaldigimAyet == a;
    final cuzBasi = a == 1 ? quran.getJuzNumber(s, 1) != (s > 1 ? quran.getJuzNumber(s - 1, quran.getVerseCount(s - 1)) : 0)
        : quran.getJuzNumber(s, a) != quran.getJuzNumber(s, a - 1);

    return Column(
      key: _anahtarlar[a - 1],
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
          onTap: () => _ayetSecenekleri(a),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 350),
            margin: EdgeInsets.only(bottom: Responsive.h(10)),
            padding: EdgeInsets.all(Responsive.w(14)),
            decoration: BoxDecoration(
              color: okunuyor ? Colors.amber.withOpacity(0.18) : r.kartRengi,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: okunuyor
                    ? Colors.amber.withOpacity(0.9)
                    : kaldigim ? r.anaRenk.withOpacity(0.6) : Colors.transparent,
                width: 1.5,
              ),
              boxShadow: okunuyor ? [BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 16)] : null,
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
