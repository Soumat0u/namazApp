import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../services/ansiklopedi_servisi.dart';
import 'esma_screen.dart';
import 'ilmihal_screen.dart';

String _normal(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[âá]'), 'a')
    .replaceAll(RegExp('[îí]'), 'i')
    .replaceAll(RegExp('[ûú]'), 'u')
    .replaceAll('ı', 'i')
    .replaceAll(RegExp("['’-]"), '');

void maddeyiAc(BuildContext context, String id) {
  final m = AnsiklopediServisi.ornek.bul(id);
  if (m == null) return;
  Navigator.push(context, MaterialPageRoute(builder: (_) => MaddeScreen(madde: m)));
}

/// İslam Ansiklopedisi: günün bilgisi, kategoriler ve arama
class AnsiklopediScreen extends StatefulWidget {
  const AnsiklopediScreen({super.key});

  @override
  State<AnsiklopediScreen> createState() => _AnsiklopediScreenState();
}

class _AnsiklopediScreenState extends State<AnsiklopediScreen> {
  final s = AnsiklopediServisi.ornek;
  String _arama = '';

  @override
  void initState() {
    super.initState();
    s.yukle();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("İslam Ansiklopedisi", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: s,
        builder: (context, _) {
          final p = context.read<NamazProvider>();
          final bugun = DateTime.now();
          final hicri = p.hicriGunler['${bugun.year}-${bugun.month.toString().padLeft(2, '0')}-${bugun.day.toString().padLeft(2, '0')}'];
          final gunun = s.gununMaddesi(hicri: hicri);
          final sonuc = _arama.isEmpty
              ? const <Madde>[]
              : s.maddeler
                  .where((m) =>
                      _normal(m.baslik).contains(_normal(_arama)) ||
                      _normal(m.ozet).contains(_normal(_arama)) ||
                      _normal(m.govde).contains(_normal(_arama)))
                  .toList();

          return RefreshIndicator(
            color: r.anaRenk,
            onRefresh: () => s.yukle(zorla: true),
            child: ListView(
              padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.h(4), Responsive.w(16), Responsive.h(30)),
              children: [
                TextField(
                  onChanged: (v) => setState(() => _arama = v.trim()),
                  style: TextStyle(color: r.yaziRengi),
                  decoration: InputDecoration(
                    hintText: "Ara: Bedir, Hz. Ömer, tevekkül…",
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: r.kartRengi,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  ),
                ),
                SizedBox(height: Responsive.h(14)),
                if (_arama.isNotEmpty) ...[
                  if (sonuc.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(Responsive.w(24)),
                      child: Text("Sonuç bulunamadı.", textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk)),
                    ),
                  for (final m in sonuc) MaddeSatiri(madde: m),
                ] else ...[
                  if (s.editorMu && s.maddeler.any((m) => !m.yayinda))
                    _editorBilgisi(r),
                  if (s.hata != null)
                    Padding(
                      padding: EdgeInsets.only(bottom: Responsive.h(12)),
                      child: Text(s.hata!, textAlign: TextAlign.center, style: TextStyle(color: r.kirmizi)),
                    ),
                  if (s.maddeler.isEmpty && s.yukleniyor)
                    Padding(
                      padding: EdgeInsets.all(Responsive.w(30)),
                      child: Center(child: CircularProgressIndicator(color: r.anaRenk)),
                    ),
                  // Uygulamadaki ilgili bölümler: sayfanın başında, hemen görünür
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _kisayolKarti(r, Icons.school_rounded, "İlmihal", "Abdest, gusül, namaz",
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const IlmihalScreen()))),
                        ),
                        SizedBox(width: Responsive.w(10)),
                        Expanded(
                          child: _kisayolKarti(r, Icons.auto_awesome_rounded, "Esmâ-ül Hüsnâ", "99 güzel isim",
                              () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EsmaScreen()))),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: Responsive.h(16)),
                  if (gunun != null) GununBilgisiKarti(madde: gunun),
                  SizedBox(height: Responsive.h(16)),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: Responsive.h(10),
                    crossAxisSpacing: Responsive.w(10),
                    childAspectRatio: 1.25,
                    children: [
                      for (final k in kategoriler) _kategoriKarti(r, k),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _editorBilgisi(AppThemeColors r) {
    final taslak = s.maddeler.where((m) => !m.yayinda).length;
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(12)),
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(color: Colors.amber.withOpacity(0.15), borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          const Icon(Icons.edit_note_rounded, color: Colors.amber),
          SizedBox(width: Responsive.w(10)),
          Expanded(
            child: Text(
              "Editör görünümü: $taslak taslak madde yalnızca sana görünüyor. Okuyup düzeltmelerini ilet; onaylananlar herkese açılır.",
              style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(12), height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kategoriKarti(AppThemeColors r, Kategori k) {
    final liste = s.kategoridekiler(k.id);
    final okunan = liste.where((m) => s.okunanlar.contains(m.id)).length;
    return Material(
      color: r.kartRengi,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: liste.isEmpty ? null : () => Navigator.push(context, MaterialPageRoute(builder: (_) => KategoriScreen(kategori: k))),
        child: Padding(
          padding: EdgeInsets.all(Responsive.w(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(8)),
                decoration: BoxDecoration(color: k.renk.withOpacity(0.14), borderRadius: BorderRadius.circular(12)),
                child: Icon(k.ikon, color: k.renk, size: Responsive.w(22)),
              ),
              const Spacer(),
              Text(k.ad,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(14))),
              Text(liste.isEmpty ? "Yakında" : "$okunan / ${liste.length} okundu",
                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
              SizedBox(height: Responsive.h(6)),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: liste.isEmpty ? 0 : okunan / liste.length,
                  minHeight: 4,
                  color: k.renk,
                  backgroundColor: k.renk.withOpacity(0.12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// İlmihal / Esma kısayolu: temanın renginde, yan yana duran belirgin kart
  Widget _kisayolKarti(AppThemeColors r, IconData ikon, String baslik, String alt, VoidCallback onTap) {
    final koyuTema = r.kartRengi.computeLuminance() < 0.2;
    final zemin = koyuTema
        ? Color.alphaBlend(r.anaRenk.withOpacity(0.16), r.kartRengi)
        : Color.alphaBlend(r.anaRenk.withOpacity(0.10), r.kartRengi);
    return Material(
      color: zemin,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(Responsive.w(14)),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: r.anaRenk.withOpacity(0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(Responsive.w(8)),
                    decoration: BoxDecoration(color: r.anaRenk, borderRadius: BorderRadius.circular(12)),
                    child: Icon(ikon, color: Colors.white, size: Responsive.w(20)),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_rounded, color: r.anaRenk, size: Responsive.w(18)),
                ],
              ),
              SizedBox(height: Responsive.h(10)),
              Text(baslik,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(15))),
              SizedBox(height: Responsive.h(2)),
              Text(alt,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
            ],
          ),
        ),
      ),
    );
  }
}

/// Günün bilgisi kartı (ansiklopedi ve ana sayfa)
class GununBilgisiKarti extends StatelessWidget {
  final Madde madde;
  /// Ana sayfadaki kaydırılabilir alanda: sabit yükseklik, metin kısaltılır
  final bool kompakt;
  const GununBilgisiKarti({super.key, required this.madde, this.kompakt = false});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final k = kategoriBul(madde.kategori);
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaddeScreen(madde: madde))),
      child: Container(
        padding: EdgeInsets.all(Responsive.w(18)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color.alphaBlend(Colors.black.withOpacity(0.3), r.anaRenk), r.anaRenk],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          boxShadow: [BoxShadow(color: r.anaRenk.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))],
        ),
        child: Column(
          mainAxisSize: kompakt ? MainAxisSize.max : MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.menu_book_rounded, color: Colors.white, size: 16),
                SizedBox(width: Responsive.w(8)),
                Text("GÜNÜN BİLGİSİ",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: Responsive.sp(12), letterSpacing: 2)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                  child: Text(k.ad, style: TextStyle(color: Colors.white, fontSize: Responsive.sp(10), fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(10)),
            Text(madde.baslik,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: Responsive.sp(19))),
            SizedBox(height: Responsive.h(4)),
            Text(madde.ozet,
                maxLines: kompakt ? 2 : 4,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.92), fontSize: Responsive.sp(13), height: 1.35)),
            SizedBox(height: Responsive.h(8)),
            Text("Devamını oku →",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: Responsive.sp(12))),
          ],
        ),
      ),
    );
  }
}

/// Listede bir madde
class MaddeSatiri extends StatelessWidget {
  final Madde madde;
  const MaddeSatiri({super.key, required this.madde});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final k = kategoriBul(madde.kategori);
    final okundu = AnsiklopediServisi.ornek.okunanlar.contains(madde.id);
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(8)),
      child: Material(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MaddeScreen(madde: madde))),
          child: Padding(
            padding: EdgeInsets.all(Responsive.w(14)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(okundu ? Icons.check_circle_rounded : k.ikon, color: okundu ? const Color(0xFF2E9D57) : k.renk, size: 22),
                SizedBox(width: Responsive.w(12)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(madde.baslik,
                                style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(15))),
                          ),
                          if (!madde.yayinda) ...[
                            SizedBox(width: Responsive.w(6)),
                            const _TaslakEtiketi(),
                          ],
                        ],
                      ),
                      SizedBox(height: Responsive.h(2)),
                      Text(madde.ozet,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12), height: 1.3)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TaslakEtiketi extends StatelessWidget {
  const _TaslakEtiketi();
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: Colors.amber.withOpacity(0.25), borderRadius: BorderRadius.circular(6)),
        child: const Text("TASLAK", style: TextStyle(color: Color(0xFF8D6E00), fontSize: 9, fontWeight: FontWeight.w900)),
      );
}

class KategoriScreen extends StatelessWidget {
  final Kategori kategori;
  const KategoriScreen({super.key, required this.kategori});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(kategori.ad, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListenableBuilder(
        listenable: AnsiklopediServisi.ornek,
        builder: (context, _) => ListView(
          padding: EdgeInsets.all(Responsive.w(16)),
          children: [
            Text(kategori.aciklama, style: TextStyle(color: r.pasifRenk)),
            SizedBox(height: Responsive.h(12)),
            for (final m in AnsiklopediServisi.ornek.kategoridekiler(kategori.id)) MaddeSatiri(madde: m),
          ],
        ),
      ),
    );
  }
}

/// Bir maddenin sayfası: künye, metin, kaynak ve ilgili maddeler
class MaddeScreen extends StatefulWidget {
  final Madde madde;
  const MaddeScreen({super.key, required this.madde});

  @override
  State<MaddeScreen> createState() => _MaddeScreenState();
}

class _MaddeScreenState extends State<MaddeScreen> {
  @override
  void initState() {
    super.initState();
    // Sayfa açılıp bir süre okununca okunmuş sayılır
    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) AnsiklopediServisi.ornek.okundu(widget.madde.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final m = widget.madde;
    final k = kategoriBul(m.kategori);
    final ilgili = [for (final id in m.baglantilar) ?AnsiklopediServisi.ornek.bul(id)];

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.share_rounded, color: r.anaRenk),
            onPressed: () => Share.share("${m.baslik}\n\n${m.ozet}\n\n— Takva Yolum, İslam Ansiklopedisi"),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Responsive.w(20), 0, Responsive.w(20), Responsive.h(40)),
        children: [
          Row(
            children: [
              Icon(k.ikon, color: k.renk, size: 16),
              SizedBox(width: Responsive.w(6)),
              Text(k.ad.toUpperCase(),
                  style: TextStyle(color: k.renk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(11), letterSpacing: 1.5)),
              if (!m.yayinda) ...[SizedBox(width: Responsive.w(8)), const _TaslakEtiketi()],
            ],
          ),
          SizedBox(height: Responsive.h(6)),
          Text(m.baslik, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(26), height: 1.2)),
          SizedBox(height: Responsive.h(10)),
          Text(m.ozet,
              style: TextStyle(color: r.yaziRengi.withOpacity(0.75), fontSize: Responsive.sp(15), height: 1.45, fontStyle: FontStyle.italic)),
          if (m.kunye.isNotEmpty) ...[
            SizedBox(height: Responsive.h(16)),
            Container(
              padding: EdgeInsets.all(Responsive.w(14)),
              decoration: BoxDecoration(
                color: r.kartRengi,
                borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: k.renk, width: 4)),
              ),
              child: Column(
                children: [
                  for (final (ad, deger) in m.kunye)
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: Responsive.h(3)),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: Responsive.w(105),
                            child: Text(ad, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12), fontWeight: FontWeight.w600)),
                          ),
                          Expanded(
                            child: Text(deger, style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(13), fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          SizedBox(height: Responsive.h(18)),
          MaddeMetni(metin: m.govde, vurgu: k.renk),
          if (m.kaynak.isNotEmpty) ...[
            SizedBox(height: Responsive.h(18)),
            Text("Kaynak: ${m.kaynak}", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11), height: 1.4)),
          ],
          if (ilgili.isNotEmpty) ...[
            SizedBox(height: Responsive.h(22)),
            Text("İlgili maddeler", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(15))),
            SizedBox(height: Responsive.h(8)),
            for (final i in ilgili) MaddeSatiri(madde: i),
          ],
        ],
      ),
    );
  }
}

/// Madde metni: "## başlık", "- madde", "1. sıralı", "> alıntı", **kalın**,
/// [[madde-id]] / [[madde-id|ad]] bağlantıları
class MaddeMetni extends StatelessWidget {
  final String metin;
  final Color vurgu;
  const MaddeMetni({super.key, required this.metin, required this.vurgu});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final govde = TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(15), height: 1.6);
    final bloklar = <Widget>[];

    for (final parca in metin.split(RegExp(r'\n\s*\n'))) {
      final satirlar = parca.trim().split('\n');
      if (satirlar.first.isEmpty) continue;
      if (satirlar.first.startsWith('## ')) {
        bloklar.add(Padding(
          padding: EdgeInsets.only(top: Responsive.h(10), bottom: Responsive.h(6)),
          child: Text(satirlar.first.substring(3),
              style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(18))),
        ));
        satirlar.removeAt(0);
        if (satirlar.isEmpty) continue;
      }
      final liste = satirlar.every((l) => l.startsWith('- ') || RegExp(r'^\d+\. ').hasMatch(l));
      if (liste) {
        for (final l in satirlar) {
          final sirali = RegExp(r'^(\d+)\. ').firstMatch(l);
          bloklar.add(Padding(
            padding: EdgeInsets.only(bottom: Responsive.h(6)),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: Responsive.w(24),
                  child: sirali != null
                      ? Text("${sirali.group(1)}.", style: govde.copyWith(color: vurgu, fontWeight: FontWeight.w800))
                      : Padding(
                          padding: EdgeInsets.only(top: Responsive.h(9)),
                          child: Icon(Icons.circle, size: 7, color: vurgu),
                        ),
                ),
                Expanded(child: _zenginMetin(context, l.substring(sirali?.group(0)!.length ?? 2), govde)),
              ],
            ),
          ));
        }
      } else if (satirlar.first.startsWith('> ')) {
        bloklar.add(Container(
          margin: EdgeInsets.symmetric(vertical: Responsive.h(6)),
          padding: EdgeInsets.all(Responsive.w(14)),
          decoration: BoxDecoration(
            color: vurgu.withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
            border: Border(left: BorderSide(color: vurgu, width: 3)),
          ),
          child: _zenginMetin(context, satirlar.map((l) => l.replaceFirst(RegExp(r'^>\s?'), '')).join(' '),
              govde.copyWith(fontStyle: FontStyle.italic)),
        ));
      } else {
        bloklar.add(Padding(
          padding: EdgeInsets.only(bottom: Responsive.h(10)),
          child: _zenginMetin(context, satirlar.join(' '), govde),
        ));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: bloklar);
  }

  /// **kalın** ve [[bağlantı]] içeren satır
  Widget _zenginMetin(BuildContext context, String s, TextStyle stil) {
    final parcalar = <InlineSpan>[];
    final desen = RegExp(r'\*\*(.+?)\*\*|\[\[([^\]|]+)(?:\|([^\]]+))?\]\]');
    var i = 0;
    for (final m in desen.allMatches(s)) {
      if (m.start > i) parcalar.add(TextSpan(text: s.substring(i, m.start)));
      if (m.group(1) != null) {
        parcalar.add(TextSpan(text: m.group(1), style: const TextStyle(fontWeight: FontWeight.w800)));
      } else {
        final id = m.group(2)!;
        final ad = m.group(3) ?? AnsiklopediServisi.ornek.bul(id)?.baslik ?? id;
        parcalar.add(TextSpan(
          text: ad,
          style: TextStyle(color: vurgu, fontWeight: FontWeight.w700, decoration: TextDecoration.underline, decorationColor: vurgu),
          recognizer: TapGestureRecognizer()..onTap = () => maddeyiAc(context, id),
        ));
      }
      i = m.end;
    }
    if (i < s.length) parcalar.add(TextSpan(text: s.substring(i)));
    return Text.rich(TextSpan(style: stil, children: parcalar));
  }
}
