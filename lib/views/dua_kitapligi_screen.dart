import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/dualar.dart';
import '../core/utils/responsive.dart';

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

class DuaDetayScreen extends StatelessWidget {
  final Dua dua;
  const DuaDetayScreen({super.key, required this.dua});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;

    Widget bolum(String baslik, String metin, {TextStyle? stil, TextDirection? yon}) => Container(
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
              SizedBox(
                width: double.infinity,
                child: Text(metin, textDirection: yon, style: stil),
              ),
            ],
          ),
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
          bolum("Arapça", dua.arapca,
              yon: TextDirection.rtl,
              stil: TextStyle(fontSize: Responsive.sp(24), height: 1.9, color: r.yaziRengi)),
          bolum("Okunuşu", dua.okunus,
              stil: TextStyle(fontSize: Responsive.sp(15), height: 1.6, fontStyle: FontStyle.italic, color: r.yaziRengi)),
          bolum("Anlamı", dua.meal, stil: TextStyle(fontSize: Responsive.sp(14), height: 1.6, color: r.yaziRengi)),
          if (dua.kaynak != null)
            Text("Kaynak: ${dua.kaynak}", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
        ],
      ),
    );
  }
}
