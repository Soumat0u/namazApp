import 'dart:math';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Namaz duruşunu profilden (kıbleye, sağa bakarak) gösteren sade figür.
/// Her duruş eklem açılarıyla tanımlanır; duruşlar arasında açılar yumuşakça
/// değiştirilerek figür bir duruştan ötekine "hareket eder".
///
/// Açılar derece: uzuvlar için dikey-aşağıdan, ileri (sağa) doğru pozitif;
/// gövde için dikey-yukarıdan, öne eğilme pozitif.
class Poz {
  final double govde; // gövde (kalça → omuz)
  final double bas; // boyun ve baş
  final double kol; // üst kol
  final double onKol; // ön kol
  final double kolBoy; // kolun profilde görünen uzunluk oranı (öne uzanan kol kısa görünür)
  final double onKolBoy;
  final double uyluk;
  final double baldir;
  final double ayak;
  /// Selamda başın döndüğü yön: -1 sol, 0 karşı, 1 sağ (yalnızca işaret çizilir)
  final double selam;

  const Poz({
    required this.govde,
    required this.bas,
    required this.kol,
    required this.onKol,
    this.kolBoy = 1,
    this.onKolBoy = 1,
    required this.uyluk,
    required this.baldir,
    this.ayak = 90,
    this.selam = 0,
  });

  static Poz lerp(Poz a, Poz b, double t) => Poz(
        govde: lerpDouble(a.govde, b.govde, t)!,
        bas: lerpDouble(a.bas, b.bas, t)!,
        kol: lerpDouble(a.kol, b.kol, t)!,
        onKol: lerpDouble(a.onKol, b.onKol, t)!,
        kolBoy: lerpDouble(a.kolBoy, b.kolBoy, t)!,
        onKolBoy: lerpDouble(a.onKolBoy, b.onKolBoy, t)!,
        uyluk: lerpDouble(a.uyluk, b.uyluk, t)!,
        baldir: lerpDouble(a.baldir, b.baldir, t)!,
        ayak: lerpDouble(a.ayak, b.ayak, t)!,
        selam: lerpDouble(a.selam, b.selam, t)!,
      );
}

/// Namazdaki duruşlar
enum Durus { ayakta, tekbir, kiyam, ruku, secde, oturus, selamSag, selamSol }

Poz durusPozu(Durus d, {bool kadin = false}) => switch (d) {
      // Kollar yanda
      Durus.ayakta => const Poz(govde: 0, bas: 0, kol: 4, onKol: 6, uyluk: 0, baldir: 0),
      // Eller kulak (kadınlarda omuz) hizasında
      Durus.tekbir => kadin
          ? const Poz(govde: 0, bas: 0, kol: 32, onKol: 178, onKolBoy: 0.85, uyluk: 0, baldir: 0)
          : const Poz(govde: 0, bas: 0, kol: 48, onKol: 182, uyluk: 0, baldir: 0),
      // Eller bağlı: erkekte göbek altında, kadında göğüs üzerinde
      Durus.kiyam => kadin
          ? const Poz(govde: 0, bas: 6, kol: 28, onKol: 150, onKolBoy: 0.42, uyluk: 0, baldir: 0)
          : const Poz(govde: 0, bas: 6, kol: 14, onKol: 82, onKolBoy: 0.45, uyluk: 0, baldir: 0),
      // Sırt düz, eller dizlerde
      Durus.ruku => const Poz(govde: 86, bas: 90, kol: -50, onKol: -55, uyluk: 0, baldir: 0),
      // Alın, burun, eller, dizler ve ayak parmakları yerde
      Durus.secde => const Poz(
          govde: 117, bas: 140, kol: -47, onKol: 66, kolBoy: 0.55, onKolBoy: 0.81, uyluk: 20, baldir: -105, ayak: 20),
      // Topukların üzerine oturuş, eller uyluklarda
      Durus.oturus => const Poz(govde: 0, bas: 4, kol: 20, onKol: 50, uyluk: 80, baldir: -95, ayak: -90),
      Durus.selamSag => const Poz(govde: 0, bas: 4, kol: 20, onKol: 50, uyluk: 80, baldir: -95, ayak: -90, selam: 1),
      Durus.selamSol => const Poz(govde: 0, bas: 4, kol: 20, onKol: 50, uyluk: 80, baldir: -95, ayak: -90, selam: -1),
    };

class _FiguruCiz extends CustomPainter {
  final Poz poz;
  final Color renk;
  final Color seccade;
  final Color zemin; // uzuvların çevresindeki kontur: üst üste binen parçalar ayrılsın
  _FiguruCiz(this.poz, this.renk, this.seccade, this.zemin);

  // Uzuv boyları (figür yüksekliği yaklaşık 175 birim)
  static const govdeBoy = 48.0, boyun = 7.0, basR = 11.0;
  static const ustKol = 32.0, onKol = 30.0, uyluk = 44.0, baldir = 44.0, ayakBoy = 14.0;

  static Offset _uzuv(double aci) => Offset(sin(aci * pi / 180), cos(aci * pi / 180));
  static Offset _yukari(double aci) => Offset(sin(aci * pi / 180), -cos(aci * pi / 180));

  @override
  void paint(Canvas canvas, Size size) {
    // Noktalar: kalça (0,0) kökünde hesaplanır, sonra yere oturtulur
    const kalca = Offset.zero;
    final omuz = kalca + _yukari(poz.govde) * govdeBoy;
    final boyunUcu = omuz + _yukari(poz.bas) * boyun;
    final basMerkez = boyunUcu + _yukari(poz.bas) * basR;
    final dirsek = omuz + _uzuv(poz.kol) * ustKol * poz.kolBoy;
    final el = dirsek + _uzuv(poz.onKol) * onKol * poz.onKolBoy;
    final diz = kalca + _uzuv(poz.uyluk) * uyluk;
    final bilek = diz + _uzuv(poz.baldir) * baldir;
    final parmak = bilek + _uzuv(poz.ayak) * ayakBoy;

    const kalin = 12.0;
    final noktalar = [kalca, omuz, boyunUcu, dirsek, el, diz, bilek, parmak];
    var enAlt = basMerkez.dy + basR;
    var sol = basMerkez.dx - basR, sag = basMerkez.dx + basR;
    for (final n in noktalar) {
      enAlt = max(enAlt, n.dy + kalin / 2);
      sol = min(sol, n.dx - kalin / 2);
      sag = max(sag, n.dx + kalin / 2);
    }

    // Ölçek: figürün tam boyu (ayakta ~185 birim) alanın yüksekliğine sığar,
    // böylece duruşlar arasında figür büyüyüp küçülmez
    final olcek = size.height / 200;
    final yer = size.height * 0.94;
    canvas.save();
    canvas.translate(size.width / 2, yer);
    canvas.scale(olcek);

    // Seccade
    final hali = RRect.fromRectAndRadius(const Rect.fromLTWH(-80, 0, 175, 7), const Radius.circular(3));
    canvas.drawRRect(hali, Paint()..color = seccade);

    // Figür: en alttaki nokta yere değsin, yatayda seccadeye ortalansın
    final kayma = Offset(-(sol + sag) / 2 + 5, -enAlt);
    canvas.translate(kayma.dx, kayma.dy);

    final kalem = Paint()
      ..color = renk
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final kontur = Paint()
      ..color = zemin
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    void cizgi(Offset a, Offset b, double k, {bool ayir = false}) {
      if (ayir) canvas.drawLine(a, b, kontur..strokeWidth = k + 5);
      canvas.drawLine(a, b, kalem..strokeWidth = k);
    }

    // Arkadaki bacak ve kol (hafif soluk), öndekiler tam renk
    final soluk = Paint()
      ..color = Color.lerp(renk, seccade, 0.45)!
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(kalca, diz + const Offset(-3, 0), soluk..strokeWidth = kalin);
    canvas.drawLine(diz + const Offset(-3, 0), bilek + const Offset(-3, 0), soluk);
    canvas.drawLine(bilek + const Offset(-3, 0), parmak + const Offset(-3, 0), soluk..strokeWidth = 8);

    cizgi(kalca, diz, kalin, ayir: true);
    cizgi(diz, bilek, kalin, ayir: true);
    cizgi(bilek, parmak, 8);
    cizgi(kalca, omuz, 18, ayir: true); // gövde
    cizgi(omuz, boyunUcu, 8);
    canvas.drawCircle(basMerkez, basR + 2.5, Paint()..color = zemin);
    canvas.drawCircle(basMerkez, basR, Paint()..color = renk);
    cizgi(omuz, dirsek, 10, ayir: true);
    cizgi(dirsek, el, 9, ayir: true);

    // Selam: başın döndüğü yönü gösteren küçük yay ve ok
    if (poz.selam.abs() > 0.05) {
      final ok = Paint()
        ..color = renk.withOpacity(poz.selam.abs())
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      final m = basMerkez + const Offset(0, -2);
      final r = Rect.fromCircle(center: m, radius: basR + 9);
      final yon = poz.selam.sign;
      canvas.drawArc(r, -pi / 2, yon * pi / 3, false, ok);
      final uc = m + Offset(sin(yon * pi / 3), -cos(yon * pi / 3)) * (basR + 9);
      canvas.drawLine(uc, uc + Offset(-yon * 6, -2), ok);
      canvas.drawLine(uc, uc + Offset(-yon * 1, -7), ok);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_FiguruCiz e) => e.poz != poz || e.renk != renk || e.seccade != seccade || e.zemin != zemin;
}

/// Tek bir duruş; [durus] değişince figür yeni duruşa geçer
class NamazFiguru extends StatelessWidget {
  final Durus durus;
  final bool kadin;
  final Color renk;
  final Color hali;
  final Color zemin;
  final Duration sure;
  const NamazFiguru({
    super.key,
    required this.durus,
    required this.renk,
    required this.hali,
    required this.zemin,
    this.kadin = false,
    this.sure = const Duration(milliseconds: 900),
  });

  @override
  Widget build(BuildContext context) {
    final hedef = durusPozu(durus, kadin: kadin);
    return TweenAnimationBuilder<Poz>(
      tween: _PozTween(end: hedef),
      duration: sure,
      curve: Curves.easeInOutCubic,
      builder: (_, p, _) => CustomPaint(painter: _FiguruCiz(p, renk, hali, zemin), size: Size.infinite),
    );
  }
}

class _PozTween extends Tween<Poz> {
  _PozTween({super.end});
  @override
  Poz lerp(double t) => Poz.lerp(begin ?? end!, end!, t);
}

/// Namazın kılınışını baştan sona oynatan animasyon (GIF gibi döner).
/// Adımın adı altta yazar; dokununca durur/devam eder.
class NamazAnimasyonu extends StatefulWidget {
  final bool kadin;
  final Color renk;
  final Color hali;
  final Color zemin;
  final Color yazi;
  const NamazAnimasyonu(
      {super.key, required this.renk, required this.hali, required this.zemin, required this.yazi, this.kadin = false});

  /// İki rekâtlı namazın adımları: (duruş, ad, ekranda kalma süresi)
  static const adimlar = <(Durus, String, int)>[
    (Durus.ayakta, 'Niyet', 1600),
    (Durus.tekbir, 'İftitah tekbiri', 1600),
    (Durus.kiyam, 'Kıyam', 2200),
    (Durus.ruku, 'Rükû', 2000),
    (Durus.ayakta, 'Kavme', 1400),
    (Durus.secde, 'Secde', 2000),
    (Durus.oturus, 'Celse', 1400),
    (Durus.secde, 'İkinci secde', 2000),
    (Durus.kiyam, 'İkinci rekât', 2000),
    (Durus.ruku, 'Rükû', 1600),
    (Durus.secde, 'Secdeler', 1800),
    (Durus.oturus, 'Son oturuş', 2200),
    (Durus.selamSag, 'Selam (sağa)', 1500),
    (Durus.selamSol, 'Selam (sola)', 1500),
  ];

  @override
  State<NamazAnimasyonu> createState() => _NamazAnimasyonuState();
}

class _NamazAnimasyonuState extends State<NamazAnimasyonu> {
  int _i = 0;
  bool _duraklat = false;

  @override
  void initState() {
    super.initState();
    _sonraki();
  }

  Future<void> _sonraki() async {
    while (mounted) {
      await Future.delayed(Duration(milliseconds: NamazAnimasyonu.adimlar[_i].$3));
      if (!mounted) return;
      if (!_duraklat) setState(() => _i = (_i + 1) % NamazAnimasyonu.adimlar.length);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (durus, ad, _) = NamazAnimasyonu.adimlar[_i];
    return GestureDetector(
      onTap: () => setState(() => _duraklat = !_duraklat),
      child: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: NamazFiguru(durus: durus, kadin: widget.kadin, renk: widget.renk, hali: widget.hali, zemin: widget.zemin),
                ),
                if (_duraklat)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Icon(Icons.pause_circle_filled_rounded, color: widget.renk.withOpacity(0.6)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Text(
              "${_i + 1}. $ad",
              key: ValueKey(_i),
              style: TextStyle(color: widget.yazi, fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ),
          const SizedBox(height: 4),
          // Adım noktaları
          Wrap(
            spacing: 4,
            children: [
              for (int j = 0; j < NamazAnimasyonu.adimlar.length; j++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  width: j == _i ? 14 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: j == _i ? widget.renk : widget.renk.withOpacity(0.25),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
