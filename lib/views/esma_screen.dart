import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vibration/vibration.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/esmaul_husna.dart';
import '../core/utils/responsive.dart';

/// Her isim için toplam zikir sayısı (telefonda saklanır)
class EsmaZikirleri {
  static const _anahtar = 'esma_zikirleri';

  static Future<Map<int, int>> oku() async {
    final p = await SharedPreferences.getInstance();
    try {
      final m = json.decode(p.getString(_anahtar) ?? '{}') as Map<String, dynamic>;
      return {for (final e in m.entries) int.parse(e.key): (e.value as num).toInt()};
    } catch (_) {
      return {};
    }
  }

  static Future<void> ekle(int no, int adet) async {
    if (adet <= 0) return;
    final m = await oku();
    m[no] = (m[no] ?? 0) + adet;
    final p = await SharedPreferences.getInstance();
    await p.setString(_anahtar, json.encode({for (final e in m.entries) '${e.key}': e.value}));
  }
}

/// Esmâ-ül Hüsnâ: günün ismi, 99 ismin listesi, anlamları ve zikir sayacı
class EsmaScreen extends StatefulWidget {
  /// Doğrudan bir ismin sayfasıyla açmak için (ana sayfadaki "Günün İsmi")
  final Esma? acilacak;
  const EsmaScreen({super.key, this.acilacak});

  @override
  State<EsmaScreen> createState() => _EsmaScreenState();
}

class _EsmaScreenState extends State<EsmaScreen> {
  String _arama = '';
  Map<int, int> _zikirler = {};

  @override
  void initState() {
    super.initState();
    _yukle();
    if (widget.acilacak != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ac(widget.acilacak!));
    }
  }

  Future<void> _yukle() async {
    final z = await EsmaZikirleri.oku();
    if (mounted) setState(() => _zikirler = z);
  }

  Future<void> _ac(Esma e) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EsmaDetay(esma: e, toplam: _zikirler[e.no] ?? 0),
    );
    _yukle();
  }

  String _normal(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[âá]'), 'a')
      .replaceAll(RegExp('[îí]'), 'i')
      .replaceAll(RegExp('[ûú]'), 'u')
      .replaceAll('ı', 'i')
      .replaceAll(RegExp("['’-]"), '');

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    final gunun = Esma.gunun();
    final liste = esmaulHusna
        .where((e) =>
            _arama.isEmpty ||
            _normal(e.okunus).contains(_normal(_arama)) ||
            _normal(e.anlam).contains(_normal(_arama)) ||
            '${e.no}' == _arama)
        .toList();

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Esmâ-ül Hüsnâ", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.h(4), Responsive.w(16), Responsive.h(24)),
        children: [
          // Günün ismi
          GestureDetector(
            onTap: () => _ac(gunun),
            child: Container(
              padding: EdgeInsets.all(Responsive.w(20)),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color.alphaBlend(Colors.black.withOpacity(0.25), r.anaRenk), r.anaRenk],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [BoxShadow(color: r.anaRenk.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 8))],
              ),
              child: Column(
                children: [
                  Text("GÜNÜN İSMİ",
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.85),
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2,
                          fontSize: Responsive.sp(11))),
                  SizedBox(height: Responsive.h(8)),
                  Text(gunun.arapca,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(color: Colors.white, fontSize: Responsive.sp(34), height: 1.4)),
                  Text(gunun.okunus,
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: Responsive.sp(18))),
                  SizedBox(height: Responsive.h(6)),
                  Text(gunun.anlam,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: Responsive.sp(13), height: 1.35)),
                  SizedBox(height: Responsive.h(10)),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(6)),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20)),
                    child: Text("Zikret: ${gunun.zikir}",
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.h(16)),
          TextField(
            onChanged: (v) => setState(() => _arama = v.trim()),
            style: TextStyle(color: r.yaziRengi),
            decoration: InputDecoration(
              hintText: "İsim veya anlam ara (ör. Rahmân, affeden)",
              prefixIcon: const Icon(Icons.search_rounded),
              filled: true,
              fillColor: r.kartRengi,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
          SizedBox(height: Responsive.h(12)),
          for (final e in liste)
            Padding(
              padding: EdgeInsets.only(bottom: Responsive.h(8)),
              child: Material(
                color: r.kartRengi,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _ac(e),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(14), vertical: Responsive.h(12)),
                    child: Row(
                      children: [
                        Container(
                          width: Responsive.w(34),
                          height: Responsive.w(34),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(color: r.anaRenk.withOpacity(0.12), shape: BoxShape.circle),
                          child: Text("${e.no}",
                              style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(12))),
                        ),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.okunus,
                                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(15))),
                              Text(e.anlam,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12), height: 1.3)),
                              if ((_zikirler[e.no] ?? 0) > 0)
                                Text("${_zikirler[e.no]} kez zikredildi",
                                    style: TextStyle(color: r.anaRenk, fontSize: Responsive.sp(11), fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        SizedBox(width: Responsive.w(8)),
                        Text(e.arapca,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(color: r.anaRenk, fontSize: Responsive.sp(20))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bir ismin sayfası: Arapça, okunuş, anlam ve zikir sayacı
class EsmaDetay extends StatefulWidget {
  final Esma esma;
  final int toplam;
  const EsmaDetay({super.key, required this.esma, required this.toplam});

  @override
  State<EsmaDetay> createState() => _EsmaDetayState();
}

class _EsmaDetayState extends State<EsmaDetay> {
  int _sayac = 0;
  int _hedef = 33;
  int _eklenen = 0; // Bu açılışta sıfırlanıp kaydedilen tur toplamı

  @override
  void dispose() {
    EsmaZikirleri.ekle(widget.esma.no, _sayac);
    super.dispose();
  }

  void _say() {
    setState(() => _sayac++);
    if (_sayac % _hedef == 0) {
      Vibration.vibrate(duration: 250);
    } else {
      Vibration.vibrate(duration: 15);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final e = widget.esma;
    final tur = _sayac % _hedef;
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, kaydirma) => Container(
        decoration: BoxDecoration(
          color: r.arkaPlanRengi,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        ),
        child: ListView(
          controller: kaydirma,
          padding: EdgeInsets.fromLTRB(Responsive.w(20), Responsive.h(10), Responsive.w(20), Responsive.h(24)),
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: r.pasifRenk.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            SizedBox(height: Responsive.h(14)),
            Text("${e.no}. isim", textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk)),
            Text(e.arapca,
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: r.anaRenk, fontSize: Responsive.sp(44), height: 1.5)),
            Text(e.okunus,
                textAlign: TextAlign.center,
                style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(22))),
            SizedBox(height: Responsive.h(10)),
            Container(
              padding: EdgeInsets.all(Responsive.w(14)),
              decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(16)),
              child: Text(e.anlam,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(15), height: 1.45)),
            ),
            SizedBox(height: Responsive.h(22)),
            // Zikir sayacı
            Center(
              child: GestureDetector(
                onTap: _say,
                child: SizedBox(
                  width: Responsive.w(190),
                  height: Responsive.w(190),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(end: _sayac > 0 && tur == 0 ? 1.0 : tur / _hedef),
                          duration: const Duration(milliseconds: 250),
                          builder: (_, v, _) => CircularProgressIndicator(
                            value: v,
                            strokeWidth: 8,
                            color: r.anaRenk,
                            backgroundColor: r.anaRenk.withOpacity(0.12),
                          ),
                        ),
                      ),
                      Container(
                        width: Responsive.w(160),
                        height: Responsive.w(160),
                        decoration: BoxDecoration(
                          color: r.kartRengi,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: r.anaRenk.withOpacity(0.18), blurRadius: 18)],
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("$_sayac",
                                style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(44))),
                            Text(e.zikir,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12), fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: Responsive.h(14)),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (final h in const [33, 99, 100])
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(4)),
                    child: ChoiceChip(
                      label: Text("$h"),
                      selected: _hedef == h,
                      onSelected: (_) => setState(() => _hedef = h),
                      selectedColor: r.anaRenk.withOpacity(0.18),
                      showCheckmark: false,
                      labelStyle: TextStyle(
                          color: _hedef == h ? r.anaRenk : r.yaziRengi.withOpacity(0.7), fontWeight: FontWeight.bold),
                    ),
                  ),
                IconButton(
                  tooltip: "Sıfırla",
                  onPressed: _sayac == 0
                      ? null
                      : () {
                          EsmaZikirleri.ekle(e.no, _sayac);
                          setState(() {
                            _eklenen += _sayac;
                            _sayac = 0;
                          });
                        },
                  icon: Icon(Icons.restart_alt_rounded, color: r.pasifRenk),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(6)),
            Text(
              "Sayaca dokunarak zikredin. Toplam: ${widget.toplam + _eklenen + _sayac} kez",
              textAlign: TextAlign.center,
              style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12)),
            ),
          ],
        ),
      ),
    );
  }
}
