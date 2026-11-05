import '../core/utils/bildirim.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/dualar.dart';
import '../core/utils/responsive.dart';
import '../services/dua_oynatici.dart';
import '../services/ezber_servisi.dart';
import 'dua_ezber_screen.dart';
import 'widgets/ayet_metni.dart';

/// Namaz ve sabah-akşam duaları: Arapça, okunuş ve meal. Her duanın sağındaki düğmeyle dinlenir.
class DuaKitapligiScreen extends StatefulWidget {
  const DuaKitapligiScreen({super.key});

  @override
  State<DuaKitapligiScreen> createState() => _DuaKitapligiScreenState();
}

class _DuaKitapligiScreenState extends State<DuaKitapligiScreen> {
  // Aynı anda tek dua çalar; başka birine basılınca önceki durur
  DuaOynatici? _oynatici;

  Future<void> _oynat(Dua dua) async {
    if (_oynatici?.dua != dua) {
      final eski = _oynatici;
      _oynatici = DuaOynatici(dua)..addListener(_hataGoster);
      setState(() {});
      await eski?.durdur();
      eski?.dispose();
    }
    await _oynatici!.calDuraklat();
  }

  void _hataGoster() {
    final h = _oynatici?.hata;
    if (h != null && mounted) {
      _oynatici!.hata = null;
      Bildirim.snackBar(SnackBar(content: Text(h)));
    }
  }

  @override
  void initState() {
    super.initState();
    EzberServisi.ornek.yukle();
  }

  @override
  void dispose() {
    _oynatici?.dispose();
    super.dispose();
  }

  void _ezberAc(Dua dua) async {
    await _oynatici?.durdur();
    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(builder: (_) => DuaEzberScreen(dua: dua)));
  }

  /// Satırdaki ezber durumu
  Widget? _ezberEtiketi(AppThemeColors r, Dua dua) {
    final d = EzberServisi.ornek.durum(dua.baslik);
    if (d == null) return null;
    final (String yazi, Color renk) = d.tekrarZamani
        ? ("Tekrar zamanı", r.anaRenk)
        : d.ezberlendi
            ? ("Ezberlendi", const Color(0xFF2E9D57))
            : ("Ezber ${d.kutu}/${EzberDurumu.enUstKutu}", r.pasifRenk);
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: renk.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text(yazi, style: TextStyle(color: renk, fontSize: Responsive.sp(10), fontWeight: FontWeight.bold)),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    const kategoriler = [namazDualari, sabahAksam];
    return ListenableBuilder(
      listenable: EzberServisi.ornek,
      builder: (context, _) => _govde(context, r, kategoriler),
    );
  }

  Widget _govde(BuildContext context, AppThemeColors r, List<String> kategoriler) {
    final bekleyen = [
      for (final b in EzberServisi.ornek.tekrarBekleyenler)
        if (dualar.where((d) => d.baslik == b).firstOrNull case final d?) d,
    ];

    return DefaultTabController(
      length: kategoriler.length,
      child: Scaffold(
        backgroundColor: r.arkaPlanRengi,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text("Dua Kitaplığı", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: r.anaRenk,
            unselectedLabelColor: r.pasifRenk,
            indicatorColor: r.anaRenk,
            tabs: [for (final k in kategoriler) Tab(text: k)],
          ),
        ),
        body: TabBarView(
          children: [
            for (final k in kategoriler)
              ListView(
                padding: EdgeInsets.all(Responsive.w(16)),
                children: [
                  if (bekleyen.isNotEmpty)
                    Card(
                      color: r.anaRenk,
                      elevation: 0,
                      margin: EdgeInsets.only(bottom: Responsive.h(12)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        leading: const Icon(Icons.school_rounded, color: Colors.white),
                        title: Text("Bugün tekrar: ${bekleyen.length} dua",
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        subtitle: Text(bekleyen.map((d) => d.baslik).join(", "),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.white.withOpacity(0.85))),
                        trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        onTap: () => _ezberAc(bekleyen.first),
                      ),
                    ),
                  for (final dua in dualar.where((d) => d.kategori == k))
                    Card(
                      color: r.kartRengi,
                      elevation: 0,
                      margin: EdgeInsets.only(bottom: Responsive.h(10)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: Text(dua.baslik, style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dua.kaynak ?? "Okuyan: telefonun Arapça sesi",
                              style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11)),
                            ),
                            ?_ezberEtiketi(r, dua),
                          ],
                        ),
                        trailing: _OynatDugmesi(
                          oynatici: _oynatici?.dua == dua ? _oynatici : null,
                          onPressed: () => _oynat(dua),
                        ),
                        onTap: () async {
                          await _oynatici?.durdur(); // Detayda kendi oynatıcısı var
                          if (!context.mounted) return;
                          Navigator.push(context, MaterialPageRoute(builder: (_) => DuaDetayScreen(dua: dua)));
                        },
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// Satırın sağındaki oynat/duraklat düğmesi
class _OynatDugmesi extends StatelessWidget {
  final DuaOynatici? oynatici;
  final VoidCallback onPressed;
  const _OynatDugmesi({required this.oynatici, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    Widget dugme(bool caliyor, bool yukleniyor) => IconButton.filledTonal(
          tooltip: caliyor ? "Duraklat" : "Dinle",
          onPressed: onPressed,
          icon: yukleniyor
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: r.anaRenk))
              : Icon(caliyor ? Icons.pause_rounded : Icons.play_arrow_rounded, color: r.anaRenk),
        );
    if (oynatici == null) return dugme(false, false);
    return ListenableBuilder(
      listenable: oynatici!,
      builder: (_, __) => dugme(oynatici!.caliyor, oynatici!.yukleniyor),
    );
  }
}

class DuaDetayScreen extends StatefulWidget {
  final Dua dua;
  const DuaDetayScreen({super.key, required this.dua});

  @override
  State<DuaDetayScreen> createState() => _DuaDetayScreenState();
}

class _DuaDetayScreenState extends State<DuaDetayScreen> {
  late final DuaOynatici _oynatici = DuaOynatici(widget.dua)..addListener(_hataGoster);

  void _hataGoster() {
    final h = _oynatici.hata;
    if (h != null && mounted) {
      _oynatici.hata = null;
      Bildirim.snackBar(SnackBar(content: Text(h)));
    }
  }

  @override
  void dispose() {
    _oynatici.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dua = widget.dua;
    final r = context.renkler;

    Widget bolum(String baslik, Widget icerik, {Widget? sag}) => Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: Responsive.h(12)),
          padding: EdgeInsets.all(Responsive.w(16)),
          decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(baslik,
                        style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
                  ),
                  if (sag != null) sag,
                ],
              ),
              SizedBox(height: Responsive.h(8)),
              SizedBox(width: double.infinity, child: icerik),
            ],
          ),
        );

    final arapcaStil = TextStyle(fontSize: Responsive.sp(24), height: 1.9, color: r.yaziRengi);

    Widget arapca() => ListenableBuilder(
          listenable: _oynatici,
          builder: (context, _) {
            final kuran = _oynatici.kuran;
            if (kuran != null) {
              // Kur'an'dan: ayet ayet, okunan kelime aydınlatılır
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (int i = 0; i < dua.ayetler.length; i++)
                    GestureDetector(
                      onTap: () => kuran.baslat(i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(bottom: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: AyetMetni(okuyucu: kuran, sure: dua.sure!, ayet: dua.ayetler[i], stil: arapcaStil),
                      ),
                    ),
                ],
              );
            }
            // Kur'an dışı: okunan kelime aydınlatılır
            // Motor yalnızca kelime sınırını bildirir: ışık kelime boyunca tahmini sürede sağdan sola kayar
            final kelimeler = [for (final k in _oynatici.kelimeler) k.$1];
            final aktif = _oynatici.aktifKelime;
            // Kayıtlı ses: ışık, ayetlerdeki gibi sesin gerçek konumuyla harf harf ilerler
            final ilerleme = _oynatici.ilerleme;
            if (ilerleme != null) {
              return IsikliKelimeler(kelimeler: kelimeler, aktif: aktif, ilerleme: ilerleme, stil: arapcaStil);
            }
            return TweenAnimationBuilder<double>(
              key: ValueKey(aktif),
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: aktif == null ? 1 : 140 * kelimeler[aktif].length),
              builder: (context, t, _) => IsikliKelimeler(
                kelimeler: kelimeler,
                aktif: aktif,
                ilerleme: t,
                stil: arapcaStil,
              ),
            );
          },
        );

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(dua.baslik, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: "Ezberle",
            icon: Icon(Icons.school_rounded, color: r.anaRenk),
            onPressed: () async {
              await _oynatici.durdur();
              if (!context.mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => DuaEzberScreen(dua: dua)));
            },
          ),
          IconButton(
            icon: Icon(Icons.share_rounded, color: r.anaRenk),
            onPressed: () => Share.share(
              "${dua.baslik}${dua.kaynak != null ? ' (${dua.kaynak})' : ''}\n\n${dua.arapca}\n\n${dua.okunus}\n\n${dua.meal}",
            ),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(Responsive.w(16)),
        children: [
          bolum("Arapça", arapca(), sag: _OynatDugmesi(oynatici: _oynatici, onPressed: _oynatici.calDuraklat)),
          bolum(
              "Okunuşu",
              Text(dua.okunus,
                  style: TextStyle(
                      fontSize: Responsive.sp(15), height: 1.6, fontStyle: FontStyle.italic, color: r.yaziRengi))),
          bolum("Anlamı", Text(dua.meal, style: TextStyle(fontSize: Responsive.sp(14), height: 1.6, color: r.yaziRengi))),
          Text(
            dua.kurandan
                ? "Kaynak: ${dua.kaynak} • Okuyan: Mişârî Râşid el-Afâsî"
                : "Bu dua telefonun Arapça yazıdan-sese motoruyla okunur; telaffuz bir hafızın okuyuşu kadar doğru olmayabilir.",
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11)),
          ),
        ],
      ),
    );
  }
}
