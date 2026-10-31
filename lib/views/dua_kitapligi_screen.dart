import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/dualar.dart';
import '../core/utils/responsive.dart';
import '../services/dua_oynatici.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(h)));
    }
  }

  @override
  void dispose() {
    _oynatici?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    const kategoriler = [namazDualari, sabahAksam];

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
                  for (final dua in dualar.where((d) => d.kategori == k))
                    Card(
                      color: r.kartRengi,
                      elevation: 0,
                      margin: EdgeInsets.only(bottom: Responsive.h(10)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      child: ListTile(
                        title: Text(dua.baslik, style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
                        subtitle: Text(
                          dua.kaynak ?? "Okuyan: telefonun Arapça sesi",
                          style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11)),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(h)));
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
                          color: kuran.aktifIndex == i ? Colors.amber.withOpacity(0.10) : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: AyetMetni(okuyucu: kuran, sure: dua.sure!, ayet: dua.ayetler[i], stil: arapcaStil),
                      ),
                    ),
                ],
              );
            }
            // Kur'an dışı: yazıdan-sese motorunun okuduğu kelime aydınlatılır
            final aktif = _oynatici.aktifKelime;
            final k = _oynatici.kelimeler;
            return Text.rich(
              TextSpan(children: [
                for (int i = 0; i < k.length; i++) ...[
                  TextSpan(
                    text: k[i].$1,
                    style: i == aktif
                        ? arapcaStil.copyWith(backgroundColor: Colors.amber.withOpacity(0.45), fontWeight: FontWeight.bold)
                        : (aktif != null && i < aktif)
                            ? arapcaStil.copyWith(color: r.yaziRengi.withOpacity(0.55))
                            : arapcaStil,
                  ),
                  if (i < k.length - 1) TextSpan(text: ' ', style: arapcaStil),
                ],
              ]),
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
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
