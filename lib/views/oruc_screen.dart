import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';

/// Oruç takibi: sahur/iftar geri sayımı, bugünün orucu, kaza orucu borcu ve sahur/iftar bildirimleri
class OrucScreen extends StatefulWidget {
  const OrucScreen({super.key});

  @override
  State<OrucScreen> createState() => _OrucScreenState();
}

class _OrucScreenState extends State<OrucScreen> {
  late final Timer _zamanlayici;

  @override
  void initState() {
    super.initState();
    _zamanlayici = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _zamanlayici.cancel();
    super.dispose();
  }

  /// Sıradaki hedef: imsaktan önceyse sahur bitişi, gün içindeyse iftar, iftardan sonra yarının imsakı
  ({String etiket, DateTime zaman})? _siradaki(NamazProvider p) {
    final simdi = DateTime.now();
    final bugun = p.orucVakitleri(simdi);
    if (bugun == null) return null;
    if (simdi.isBefore(bugun.imsak)) return (etiket: "İmsaka (sahurun bitişine)", zaman: bugun.imsak);
    if (simdi.isBefore(bugun.iftar)) return (etiket: "İftara", zaman: bugun.iftar);
    final yarin = p.orucVakitleri(DateTime(simdi.year, simdi.month, simdi.day + 1));
    return yarin == null ? null : (etiket: "Yarın imsaka", zaman: yarin.imsak);
  }

  String _sure(Duration d) =>
      "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    final p = context.watch<NamazProvider>();
    final hedef = _siradaki(p);
    final bugun = p.orucVakitleri(DateTime.now());
    final buAy = DateFormat('yyyy-MM').format(DateTime.now());
    final buAyTutulan = p.orucGunleri.where((g) => g.startsWith(buAy)).length;

    Widget kart(Widget child) => Container(
          margin: EdgeInsets.only(bottom: Responsive.h(12)),
          padding: EdgeInsets.all(Responsive.w(16)),
          decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(18)),
          child: child,
        );

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Oruç Takibi", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.all(Responsive.w(16)),
        children: [
          // Geri sayım
          kart(Column(
            children: [
              Text(hedef?.etiket ?? "Vakitler yükleniyor", style: TextStyle(color: r.pasifRenk)),
              SizedBox(height: Responsive.h(6)),
              Text(
                hedef == null ? "--:--:--" : _sure(hedef.zaman.difference(DateTime.now())),
                style: TextStyle(fontSize: Responsive.sp(40), fontWeight: FontWeight.w900, color: r.anaRenk),
              ),
              if (bugun != null) ...[
                SizedBox(height: Responsive.h(10)),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _vakit(r, Icons.nights_stay_rounded, "İmsak", DateFormat('HH:mm').format(bugun.imsak)),
                    _vakit(r, Icons.wb_twilight_rounded, "İftar", DateFormat('HH:mm').format(bugun.iftar)),
                  ],
                ),
              ],
            ],
          )),

          // Bugünün orucu
          kart(SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: r.anaRenk,
            title: Text("Bugün oruç tuttum", style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
            subtitle: Text("Bu ay $buAyTutulan gün • toplam ${p.orucGunleri.length} gün (+${NamazProvider.orucXp} XP)",
                style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
            value: p.bugunOrucTutuldu,
            onChanged: p.bugunOrucDegistir,
          )),

          // Bildirimler
          kart(SwitchListTile(
            contentPadding: EdgeInsets.zero,
            activeColor: r.anaRenk,
            title: Text("Sahur ve iftar bildirimleri", style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
            subtitle: Text(
              "İmsaktan 45 dk önce ve iftar vaktinde bildirim (Ramazan'da veya oruç tutacağın günlerde aç).",
              style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12)),
            ),
            value: p.orucModu,
            onChanged: p.bildirimlerAcik ? p.orucModuDegistir : null,
          )),

          // Kaza orucu
          kart(Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("Kaza Orucu", style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi, fontSize: Responsive.sp(15))),
              SizedBox(height: Responsive.h(4)),
              Text("Kalan borç: ${p.kazaOrucBorcu} gün • tutulan: ${p.kilinanKazaOrucu} gün",
                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
              SizedBox(height: Responsive.h(10)),
              Row(
                children: [
                  IconButton.outlined(
                    onPressed: p.kazaOrucBorcu > 0 ? () => p.kazaOrucBorcuAyarla(p.kazaOrucBorcu - 1) : null,
                    icon: const Icon(Icons.remove_rounded),
                  ),
                  Expanded(
                    child: Text("${p.kazaOrucBorcu}",
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: Responsive.sp(24), fontWeight: FontWeight.w900, color: r.yaziRengi)),
                  ),
                  IconButton.outlined(
                    onPressed: () => p.kazaOrucBorcuAyarla(p.kazaOrucBorcu + 1),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
              SizedBox(height: Responsive.h(8)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: p.kazaOrucBorcu > 0 && !p.bugunOrucTutuldu ? p.kazaOrucuTuttum : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: r.anaRenk,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Bugün kaza orucu tuttum",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )),
          Text(
            "İmsak ve iftar saatleri, namaz vakitlerindeki Sabah (imsak) ve Akşam vakitlerinden alınır.",
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11)),
          ),
        ],
      ),
    );
  }

  Widget _vakit(AppThemeColors r, IconData ikon, String ad, String saat) => Column(
        children: [
          Icon(ikon, color: r.anaRenk),
          Text(ad, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
          Text(saat, style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi, fontSize: Responsive.sp(16))),
        ],
      );
}
