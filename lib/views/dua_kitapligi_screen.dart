import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/dualar.dart';
import '../core/utils/responsive.dart';
import '../services/kuran_okuyucu.dart';
import 'package:quran/quran.dart' as quran;

/// Namaz ve sabah-akşam duaları: Arapça, okunuş ve meal
class DuaKitapligiScreen extends StatelessWidget {
  const DuaKitapligiScreen({super.key});

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
                        title: Text(dua.baslik,
                            style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
                        subtitle: dua.kaynak != null
                            ? Text(dua.kaynak!, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11)))
                            : null,
                        trailing: Icon(Icons.chevron_right_rounded, color: r.pasifRenk),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => DuaDetayScreen(dua: dua)),
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
}

class DuaDetayScreen extends StatefulWidget {
  final Dua dua;
  const DuaDetayScreen({super.key, required this.dua});

  @override
  State<DuaDetayScreen> createState() => _DuaDetayScreenState();
}

class _DuaDetayScreenState extends State<DuaDetayScreen> {
  // Kur'an'dan olan dualar ayet ayet dinlenebilir; okunan ayet vurgulanır
  late final KuranOkuyucu? _okuyucu = widget.dua.kurandan
      ? KuranOkuyucu([for (final a in widget.dua.ayetler) (sure: widget.dua.sure!, ayet: a)])
      : null;

  @override
  void dispose() {
    _okuyucu?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dua = widget.dua;
    final r = context.renkler;
    final okuyucu = _okuyucu;

    Widget bolum(String baslik, Widget icerik) => Container(
          width: double.infinity,
          margin: EdgeInsets.only(bottom: Responsive.h(12)),
          padding: EdgeInsets.all(Responsive.w(16)),
          decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(16)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(baslik,
                  style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
              SizedBox(height: Responsive.h(8)),
              SizedBox(width: double.infinity, child: icerik),
            ],
          ),
        );

    final arapcaStil = TextStyle(fontSize: Responsive.sp(24), height: 1.9, color: r.yaziRengi);

    Widget arapca() {
      if (okuyucu == null) {
        return Text(dua.arapca, textDirection: TextDirection.rtl, style: arapcaStil);
      }
      return ListenableBuilder(
        listenable: okuyucu,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int i = 0; i < dua.ayetler.length; i++)
              GestureDetector(
                onTap: () => okuyucu.baslat(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: okuyucu.aktifIndex == i ? Colors.amber.withOpacity(0.22) : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: okuyucu.aktifIndex == i ? Colors.amber.withOpacity(0.8) : Colors.transparent),
                  ),
                  child: Text(
                    quran.getVerse(dua.sure!, dua.ayetler[i], verseEndSymbol: true),
                    textDirection: TextDirection.rtl,
                    style: arapcaStil,
                  ),
                ),
              ),
          ],
        ),
      );
    }

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
      floatingActionButton: okuyucu == null
          ? null
          : ListenableBuilder(
              listenable: okuyucu,
              builder: (context, _) {
                if (okuyucu.hata != null) {
                  final h = okuyucu.hata!;
                  okuyucu.hata = null;
                  WidgetsBinding.instance.addPostFrameCallback(
                      (_) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(h))));
                }
                return FloatingActionButton.extended(
                  backgroundColor: r.anaRenk,
                  onPressed: okuyucu.calDuraklat,
                  icon: okuyucu.yukleniyor
                      ? const SizedBox(
                          width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Icon(okuyucu.caliyor ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white),
                  label: Text(okuyucu.caliyor ? "Duraklat" : "Dinle",
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                );
              },
            ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.w(16), Responsive.w(16), 90),
        children: [
          bolum("Arapça", arapca()),
          bolum(
              "Okunuşu",
              Text(dua.okunus,
                  style: TextStyle(
                      fontSize: Responsive.sp(15), height: 1.6, fontStyle: FontStyle.italic, color: r.yaziRengi))),
          bolum("Anlamı", Text(dua.meal, style: TextStyle(fontSize: Responsive.sp(14), height: 1.6, color: r.yaziRengi))),
          if (dua.kaynak != null)
            Text("Kaynak: ${dua.kaynak} • Okuyan: Mişârî Râşid el-Afâsî",
                style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
        ],
      ),
    );
  }
}
