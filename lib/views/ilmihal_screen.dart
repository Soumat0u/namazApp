import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/dualar.dart';
import '../core/constants/ilmihal.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import 'dua_kitapligi_screen.dart';
import 'widgets/namaz_figuru.dart';

/// Kısa ilmihal: abdest, gusül, teyemmüm ve namaz bilgileri, adım adım
class IlmihalScreen extends StatelessWidget {
  const IlmihalScreen({super.key});

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
        title: Text("İlmihal", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.all(Responsive.w(16)),
        children: [
          for (final k in ilmihalKonulari)
            Padding(
              padding: EdgeInsets.only(bottom: Responsive.h(10)),
              child: Material(
                color: r.kartRengi,
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IlmihalKonuScreen(konu: k))),
                  child: Padding(
                    padding: EdgeInsets.all(Responsive.w(14)),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(Responsive.w(12)),
                          decoration: BoxDecoration(color: k.renk.withOpacity(0.14), borderRadius: BorderRadius.circular(14)),
                          child: Icon(k.ikon, color: k.renk, size: Responsive.w(26)),
                        ),
                        SizedBox(width: Responsive.w(14)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(k.baslik,
                                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(16))),
                              SizedBox(height: Responsive.h(2)),
                              Text(k.ozet, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: r.pasifRenk),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          SizedBox(height: Responsive.h(6)),
          Text(
            "Bilgiler Hanefî mezhebine göredir. Ayrıntılı bilgi ve özel durumlar için Diyanet İşleri Başkanlığı'nın kaynaklarına başvurabilirsiniz.",
            textAlign: TextAlign.center,
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class IlmihalKonuScreen extends StatelessWidget {
  final IlmihalKonusu konu;
  const IlmihalKonuScreen({super.key, required this.konu});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(konu.baslik, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.h(4), Responsive.w(16), Responsive.h(30)),
        children: [
          if (konu.namazAnimasyonu) _animasyonKarti(context, r),
          for (final b in konu.bolumler) _bolum(context, r, b),
        ],
      ),
    );
  }

  /// Namazı baştan sona gösteren animasyon (dokununca durur)
  Widget _animasyonKarti(BuildContext context, AppThemeColors r) {
    final kadin = context.watch<NamazProvider>().kadinMi;
    return Container(
      height: Responsive.h(300),
      margin: EdgeInsets.only(bottom: Responsive.h(14)),
      padding: EdgeInsets.fromLTRB(Responsive.w(12), Responsive.h(12), Responsive.w(12), Responsive.h(12)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: NamazAnimasyonu(
        kadin: kadin,
        renk: konu.renk,
        hali: Color.alphaBlend(konu.renk.withOpacity(0.18), r.kartRengi),
        zemin: r.kartRengi,
        yazi: r.yaziRengi,
      ),
    );
  }

  Widget _bolum(BuildContext context, AppThemeColors r, IlmihalBolumu b) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(14)),
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(b.baslik, style: TextStyle(color: konu.renk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(15))),
          SizedBox(height: Responsive.h(12)),
          for (int i = 0; i < b.maddeler.length; i++)
            b.adimli
                ? _adim(context, r, i + 1, b.maddeler[i], son: i == b.maddeler.length - 1)
                : _madde(context, r, b.maddeler[i]),
          if (b.not != null) ...[
            SizedBox(height: Responsive.h(6)),
            Container(
              padding: EdgeInsets.all(Responsive.w(10)),
              decoration: BoxDecoration(color: konu.renk.withOpacity(0.08), borderRadius: BorderRadius.circular(12)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded, color: konu.renk, size: 18),
                  SizedBox(width: Responsive.w(8)),
                  Expanded(
                    child: Text(b.not!, style: TextStyle(color: r.yaziRengi.withOpacity(0.8), fontSize: Responsive.sp(12), height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Numaralı adım: solda numara ve aşağı inen çizgi
  Widget _adim(BuildContext context, AppThemeColors r, int no, Madde m, {required bool son}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: Responsive.w(30),
                height: Responsive.w(30),
                alignment: Alignment.center,
                decoration: BoxDecoration(color: konu.renk, shape: BoxShape.circle),
                child: m.ikon != null
                    ? Icon(m.ikon, color: Colors.white, size: Responsive.w(16))
                    : Text("$no", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: Responsive.sp(12))),
              ),
              if (!son) Expanded(child: Container(width: 2, color: konu.renk.withOpacity(0.25))),
            ],
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: Responsive.h(son ? 0 : 16), top: Responsive.h(4)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(m.ikon != null ? "$no. ${m.metin}" : m.metin,
                      style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(14))),
                  if (m.aciklama != null) ...[
                    SizedBox(height: Responsive.h(3)),
                    Text(m.aciklama!, style: TextStyle(color: r.yaziRengi.withOpacity(0.75), fontSize: Responsive.sp(13), height: 1.45)),
                  ],
                  if (m.dua.isNotEmpty) _duaCipleri(context, r, m.dua),
                ],
              ),
            ),
          ),
          // Adımın duruşu
          if (m.durus != null)
            Padding(
              padding: EdgeInsets.only(left: Responsive.w(8)),
              child: SizedBox(
                width: Responsive.w(58),
                height: Responsive.w(66),
                child: NamazFiguru(
                  durus: m.durus!,
                  kadin: context.watch<NamazProvider>().kadinMi,
                  renk: konu.renk,
                  hali: Color.alphaBlend(konu.renk.withOpacity(0.18), r.kartRengi),
                  zemin: r.kartRengi,
                  sure: Duration.zero,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _madde(BuildContext context, AppThemeColors r, Madde m) {
    return Padding(
      padding: EdgeInsets.only(bottom: Responsive.h(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(top: Responsive.h(5)),
            child: Icon(Icons.circle, size: 8, color: konu.renk),
          ),
          SizedBox(width: Responsive.w(10)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(m.metin,
                    style: TextStyle(
                        color: r.yaziRengi,
                        fontWeight: m.aciklama != null ? FontWeight.w800 : FontWeight.w500,
                        fontSize: Responsive.sp(14),
                        height: 1.35)),
                if (m.aciklama != null)
                  Text(m.aciklama!, style: TextStyle(color: r.yaziRengi.withOpacity(0.75), fontSize: Responsive.sp(13), height: 1.4)),
                if (m.dua.isNotEmpty) _duaCipleri(context, r, m.dua),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Okunan dualar: dokununca Dua Kitaplığı'ndaki sayfası açılır
  Widget _duaCipleri(BuildContext context, AppThemeColors r, List<String> basliklar) {
    return Padding(
      padding: EdgeInsets.only(top: Responsive.h(8)),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final b in basliklar)
            if (dualar.where((d) => d.baslik == b).firstOrNull case final dua?)
              ActionChip(
                avatar: Icon(Icons.menu_book_rounded, size: 16, color: konu.renk),
                label: Text(dua.baslik),
                labelStyle: TextStyle(color: konu.renk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12)),
                backgroundColor: konu.renk.withOpacity(0.08),
                side: BorderSide(color: konu.renk.withOpacity(0.25)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => DuaDetayScreen(dua: dua))),
              ),
        ],
      ),
    );
  }
}
