import 'dart:math';

import 'package:flutter/material.dart';

/// Kullanıcının seçtiği arka plan modu
enum ArkaPlanModu {
  sade('Sade', 'Düz tema rengi'),
  vakit('Vakte Göre', 'Vakte göre değişen hafif renk geçişi'),
  canli('Canlı', 'Çok yavaş hareketli yıldızlar ve ışık'),
  desen('Desen', 'Soluk geometrik yıldız deseni, rengi vakte göre'),
  gokyuzu('Gökyüzü', 'Vakte göre gökyüzü, ufukta cami silueti'),
  minimal('Minimal', 'Tek tonlu derin zemin, sade ve sakin'),
  mushaf('Mushaf', 'Kâğıt dokusu ve köşelerde ince tezhip');

  final String ad;
  final String aciklama;
  const ArkaPlanModu(this.ad, this.aciklama);

  static ArkaPlanModu bul(String? ad) =>
      ArkaPlanModu.values.firstWhere((m) => m.name == ad, orElse: () => ArkaPlanModu.sade);
}

/// Sekmelerin arkasındaki sayfa zemini. Kartlar düz zeminde kaldığı için yazılar okunaklı kalır;
/// efekt yalnızca boşluklarda görünür. "Animasyonları azalt" açıksa Canlı mod hareketsiz çizilir.
class SayfaArkaPlani extends StatefulWidget {
  final ArkaPlanModu mod;
  /// NamazProvider.vaktinTemasi: dawn | morning | day | afternoon | sunset | night
  final String vakitTemasi;
  final Color zemin;
  final bool koyuTema;

  const SayfaArkaPlani({
    super.key,
    required this.mod,
    required this.vakitTemasi,
    required this.zemin,
    required this.koyuTema,
  });

  @override
  State<SayfaArkaPlani> createState() => _SayfaArkaPlaniState();
}

class _SayfaArkaPlaniState extends State<SayfaArkaPlani> with SingleTickerProviderStateMixin {
  // Tam tur 60 sn: hareket bilerek çok yavaş (göz yormasın)
  late final AnimationController _kontrol =
      AnimationController(vsync: this, duration: const Duration(seconds: 60));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animasyonuAyarla();
  }

  @override
  void didUpdateWidget(SayfaArkaPlani eski) {
    super.didUpdateWidget(eski);
    _animasyonuAyarla();
  }

  bool get _hareketli => widget.mod == ArkaPlanModu.canli && !MediaQuery.of(context).disableAnimations;

  void _animasyonuAyarla() {
    if (_hareketli) {
      if (!_kontrol.isAnimating) _kontrol.repeat();
    } else {
      _kontrol.stop();
    }
  }

  @override
  void dispose() {
    _kontrol.dispose();
    super.dispose();
  }

  /// Vaktin renkleri (üst, alt); zemin rengiyle hafifçe karıştırılır
  (Color, Color) _vakitRenkleri() {
    const renkler = {
      'dawn': (Color(0xFFB39DDB), Color(0xFFFFCCBC)),
      'morning': (Color(0xFF81D4FA), Color(0xFFFFF59D)),
      'day': (Color(0xFF64B5F6), Color(0xFFB3E5FC)),
      'afternoon': (Color(0xFFFFCC80), Color(0xFFFFF3E0)),
      'sunset': (Color(0xFFFF8A65), Color(0xFF9575CD)),
      'night': (Color(0xFF1A237E), Color(0xFF4A148C)),
    };
    final (ust, alt) = renkler[widget.vakitTemasi] ?? renkler['night']!;
    final oran = widget.koyuTema ? 0.55 : 0.45;
    return (
      Color.lerp(widget.zemin, ust, oran)!,
      Color.lerp(widget.zemin, alt, oran * 0.85)!,
    );
  }

  /// Vaktin vurgu rengi (desen ve tezhipte)
  Color get _vurgu => const {
        'dawn': Color(0xFF80CBC4),
        'morning': Color(0xFF4DD0E1),
        'day': Color(0xFF4FC3F7),
        'afternoon': Color(0xFFFFD54F),
        'sunset': Color(0xFFFFB74D),
        'night': Color(0xFFFFD54F),
      }[widget.vakitTemasi] ??
      const Color(0xFFFFD54F);

  @override
  Widget build(BuildContext context) {
    switch (widget.mod) {
      case ArkaPlanModu.sade:
        return ColoredBox(color: widget.zemin);
      case ArkaPlanModu.desen:
        return RepaintBoundary(
          child: CustomPaint(
            painter: _DesenPainter(
              zemin: widget.zemin,
              renk: Color.lerp(widget.koyuTema ? Colors.white : Colors.black, _vurgu, 0.6)!,
              guc: widget.koyuTema ? 0.07 : 0.08,
            ),
          ),
        );
      case ArkaPlanModu.gokyuzu:
        return _gokyuzu();
      case ArkaPlanModu.minimal:
        // Koyu temada derin zümrüt, açık temada kırık beyaz; hafif köşe gölgesi derinlik verir
        final ana = widget.koyuTema ? const Color(0xFF0C1F1A) : const Color(0xFFF4F6F3);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              center: const Alignment(0, -0.4),
              radius: 1.3,
              colors: [ana, Color.lerp(ana, Colors.black, widget.koyuTema ? 0.35 : 0.06)!],
            ),
          ),
        );
      case ArkaPlanModu.mushaf:
        return RepaintBoundary(
          child: CustomPaint(
            painter: _MushafPainter(
              zemin: widget.koyuTema ? const Color(0xFF221C14) : const Color(0xFFF5ECD7),
              murekkep: widget.koyuTema ? const Color(0xFFE8D5A8) : const Color(0xFF6D4C1F),
              altin: const Color(0xFFC9A54A),
            ),
          ),
        );
      default:
        break;
    }

    final (ust, alt) = _vakitRenkleri();
    final gradyan = AnimatedContainer(
      duration: const Duration(seconds: 3), // Vakit değişince yumuşak geçiş
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [ust, alt, widget.zemin],
          stops: const [0, 0.65, 1],
        ),
      ),
    );
    if (widget.mod == ArkaPlanModu.vakit) return gradyan;

    final gece = widget.vakitTemasi == 'night' || widget.vakitTemasi == 'dawn';
    return Stack(
      fit: StackFit.expand,
      children: [
        gradyan,
        RepaintBoundary(
          child: CustomPaint(
            painter: _CanliPainter(
              animasyon: _kontrol,
              gece: gece,
              renk: Colors.white,
              guc: widget.koyuTema ? 1.0 : 0.7,
            ),
          ),
        ),
      ],
    );
  }

  /// Vakte göre gökyüzü + ufukta cami silueti (+ gece yıldızlar)
  Widget _gokyuzu() {
    const gok = {
      'dawn': [Color(0xFF2C2A4A), Color(0xFF8E6C9E), Color(0xFFF4A989)],
      'morning': [Color(0xFF3A7BD5), Color(0xFF8EC5FC), Color(0xFFFCE38A)],
      'day': [Color(0xFF2F80ED), Color(0xFF56CCF2), Color(0xFFBDE8F7)],
      'afternoon': [Color(0xFF4B79A1), Color(0xFFE0B36A), Color(0xFFF8D9A0)],
      'sunset': [Color(0xFF2B1B4A), Color(0xFFB44C6A), Color(0xFFF7945E)],
      'night': [Color(0xFF070B1F), Color(0xFF141E46), Color(0xFF2A2F5E)],
    };
    final renkler = gok[widget.vakitTemasi] ?? gok['night']!;
    // Kartlar okunaklı kalsın diye gökyüzü zemine doğru koyulaşır/açılır
    final oran = widget.koyuTema ? 0.7 : 0.55;
    final karisik = [for (final c in renkler) Color.lerp(widget.zemin, c, oran)!];
    final gece = widget.vakitTemasi == 'night' || widget.vakitTemasi == 'dawn';
    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedContainer(
          duration: const Duration(seconds: 3),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: karisik,
              stops: const [0, 0.6, 1],
            ),
          ),
        ),
        RepaintBoundary(
          child: CustomPaint(
            painter: _SiluetPainter(
              gece: gece,
              renk: Color.lerp(widget.zemin, Colors.black, widget.koyuTema ? 0.35 : 0.0)!
                  .withOpacity(widget.koyuTema ? 0.85 : 0.35),
            ),
          ),
        ),
      ],
    );
  }
}

/// Selçuklu/Osmanlı tarzı sekiz köşeli yıldız ızgarası (kodla çizilir, her boyutta keskin)
class _DesenPainter extends CustomPainter {
  final Color zemin;
  final Color renk;
  final double guc;
  _DesenPainter({required this.zemin, required this.renk, required this.guc});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = zemin);
    final cizgi = Paint()
      ..color = renk.withOpacity(guc)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    const a = 72.0; // Hücre boyu
    for (double y = -a / 2; y < size.height + a; y += a) {
      for (double x = -a / 2; x < size.width + a; x += a) {
        final m = Offset(x, y);
        // Sekiz köşeli yıldız: iç içe döndürülmüş iki kare
        for (final aci in [0.0, pi / 4]) {
          final yol = Path();
          for (int i = 0; i < 4; i++) {
            final t = aci + i * pi / 2 + pi / 4;
            final n = m + Offset(cos(t), sin(t)) * (a * 0.32);
            i == 0 ? yol.moveTo(n.dx, n.dy) : yol.lineTo(n.dx, n.dy);
          }
          yol.close();
          canvas.drawPath(yol, cizgi);
        }
        // Yıldızları birbirine bağlayan çapraz kollar (girih hissi)
        final k = a * 0.5;
        canvas.drawLine(m + Offset(a * 0.32, 0), m + Offset(k, 0), cizgi);
        canvas.drawLine(m + Offset(0, a * 0.32), m + Offset(0, k), cizgi);
        canvas.drawCircle(m + Offset(k, k), a * 0.12, cizgi);
      }
    }
  }

  @override
  bool shouldRepaint(_DesenPainter e) => e.zemin != zemin || e.renk != renk || e.guc != guc;
}

/// Ufukta kubbe ve minareler; gece gökyüzünde yıldızlar
class _SiluetPainter extends CustomPainter {
  final bool gece;
  final Color renk;
  _SiluetPainter({required this.gece, required this.renk});

  static final List<(double, double, double)> _yildizlar = () {
    final r = Random(11);
    return List.generate(60, (_) => (r.nextDouble(), r.nextDouble() * 0.6, 0.5 + r.nextDouble() * 1.2));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (gece) {
      final p = Paint();
      for (final (x, y, boy) in _yildizlar) {
        p.color = Colors.white.withOpacity(0.25 + 0.4 * (boy / 1.7));
        canvas.drawCircle(Offset(x * w, y * h), boy, p);
      }
    }
    final p = Paint()..color = renk;
    final taban = h * 0.885; // Alt menünün üstünde kalsın
    final yol = Path()..moveTo(0, taban);
    // Alçak tepeler
    yol.quadraticBezierTo(w * 0.15, taban - 14, w * 0.3, taban - 6);
    yol.lineTo(w * 0.3, taban);
    canvas.drawPath(yol..lineTo(0, taban)..close(), p);

    // Cami gövdesi ve kubbe
    final cx = w * 0.62;
    final govde = w * 0.46;
    final ust = taban - 46;
    canvas.drawRect(Rect.fromLTRB(cx - govde / 2, ust, cx + govde / 2, h), p);
    canvas.drawArc(Rect.fromCenter(center: Offset(cx, ust), width: govde * 0.62, height: govde * 0.56), pi, pi, true, p);
    // Yan yarım kubbeler
    for (final s in [-1, 1]) {
      canvas.drawArc(
          Rect.fromCenter(center: Offset(cx + s * govde * 0.3, ust + 4), width: govde * 0.3, height: govde * 0.24),
          pi, pi, true, p);
    }
    // Alem
    canvas.drawRect(Rect.fromLTWH(cx - 1, ust - govde * 0.28 - 10, 2, 10), p);
    // İki minare
    for (final mx in [cx - govde / 2 - 16, cx + govde / 2 + 8]) {
      canvas.drawRect(Rect.fromLTWH(mx, taban - 150, 8, h), p);
      canvas.drawRect(Rect.fromLTWH(mx - 2, taban - 108, 12, 4), p); // şerefe
      final kulah = Path()
        ..moveTo(mx - 1, taban - 150)
        ..lineTo(mx + 4, taban - 178)
        ..lineTo(mx + 9, taban - 150)
        ..close();
      canvas.drawPath(kulah, p);
    }
    // Zemin şeridi
    canvas.drawRect(Rect.fromLTRB(0, taban, w, h), p);
  }

  @override
  bool shouldRepaint(_SiluetPainter e) => e.gece != gece || e.renk != renk;
}

/// Krem kâğıt, ince doku ve köşelerde tezhip
class _MushafPainter extends CustomPainter {
  final Color zemin;
  final Color murekkep;
  final Color altin;
  _MushafPainter({required this.zemin, required this.murekkep, required this.altin});

  static final List<(double, double, double)> _lif = () {
    final r = Random(3);
    return List.generate(900, (_) => (r.nextDouble(), r.nextDouble(), r.nextDouble()));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = zemin);
    // Kâğıt lifi: çok soluk minik noktalar
    final p = Paint();
    for (final (x, y, t) in _lif) {
      p.color = murekkep.withOpacity(0.025 + 0.03 * t);
      canvas.drawCircle(Offset(x * w, y * h), 0.6 + t, p);
    }
    // Kenarlarda hafif kararma (eski sayfa)
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          radius: 1.0,
          colors: [Colors.transparent, murekkep.withOpacity(0.08)],
        ).createShader(Offset.zero & size),
    );
    // Çift çizgili altın çerçeve
    final cerceve = Paint()
      ..style = PaintingStyle.stroke
      ..color = altin.withOpacity(0.35);
    const k = 10.0;
    canvas.drawRect(Rect.fromLTRB(k, k, w - k, h - k), cerceve..strokeWidth = 1.4);
    canvas.drawRect(Rect.fromLTRB(k + 5, k + 5, w - k - 5, h - k - 5), cerceve..strokeWidth = 0.7);
    // Köşe tezhipleri: küçük gül motifleri
    for (final c in [Offset(k + 5, k + 5), Offset(w - k - 5, k + 5), Offset(k + 5, h - k - 5), Offset(w - k - 5, h - k - 5)]) {
      _gul(canvas, c, 22);
    }
  }

  void _gul(Canvas canvas, Offset m, double r) {
    final yaprak = Paint()..color = altin.withOpacity(0.4);
    for (int i = 0; i < 8; i++) {
      final t = i * pi / 4;
      canvas.drawOval(
        Rect.fromCenter(center: m + Offset(cos(t), sin(t)) * (r * 0.5), width: r * 0.45, height: r * 0.45),
        yaprak,
      );
    }
    canvas.drawCircle(m, r * 0.32, Paint()..color = zemin);
    canvas.drawCircle(m, r * 0.18, Paint()..color = altin.withOpacity(0.55));
  }

  @override
  bool shouldRepaint(_MushafPainter e) => e.zemin != zemin || e.murekkep != murekkep || e.altin != altin;
}

class _CanliPainter extends CustomPainter {
  final Animation<double> animasyon;
  final bool gece;
  final Color renk;
  final double guc;

  _CanliPainter({required this.animasyon, required this.gece, required this.renk, required this.guc})
      : super(repaint: animasyon);

  // Sabit tohum: her çizimde aynı yerleşim, sadece parıltı/kayma değişir
  static final List<(double, double, double, double)> _yildizlar = () {
    final r = Random(7);
    return List.generate(45, (_) => (r.nextDouble(), r.nextDouble() * 0.7, r.nextDouble(), 0.6 + r.nextDouble() * 1.4));
  }();

  @override
  void paint(Canvas canvas, Size size) {
    final t = animasyon.value * 2 * pi;
    if (gece) {
      // Yavaşça parlayıp sönen yıldızlar
      final p = Paint();
      for (final (x, y, faz, boy) in _yildizlar) {
        final parlaklik = 0.3 + 0.5 * (0.5 + 0.5 * sin(t * 3 + faz * 2 * pi));
        p.color = renk.withOpacity(parlaklik * guc);
        canvas.drawCircle(Offset(x * size.width, y * size.height), boy, p);
      }
    } else {
      // Gündüz: süzülen üç soluk ışık hüzmesi
      for (int i = 0; i < 3; i++) {
        final merkez = Offset(
          size.width * (0.2 + 0.3 * i + 0.08 * sin(t + i * 2.1)),
          size.height * (0.15 + 0.2 * i + 0.05 * cos(t + i)),
        );
        final yaricap = size.width * (0.35 + 0.05 * i);
        final p = Paint()
          ..shader = RadialGradient(
            colors: [renk.withOpacity(0.32 * guc), renk.withOpacity(0)],
          ).createShader(Rect.fromCircle(center: merkez, radius: yaricap));
        canvas.drawCircle(merkez, yaricap, p);
      }
    }
  }

  @override
  bool shouldRepaint(_CanliPainter eski) => eski.gece != gece || eski.guc != guc || eski.renk != renk;
}
