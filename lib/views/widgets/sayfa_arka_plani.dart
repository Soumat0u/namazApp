import 'dart:math';

import 'package:flutter/material.dart';

/// Kullanıcının seçtiği arka plan modu
enum ArkaPlanModu {
  sade('Sade', 'Düz tema rengi'),
  vakit('Vakte Göre', 'Vakte göre değişen hafif renk geçişi'),
  canli('Canlı', 'Çok yavaş hareketli yıldızlar ve ışık');

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

  @override
  Widget build(BuildContext context) {
    if (widget.mod == ArkaPlanModu.sade) return ColoredBox(color: widget.zemin);

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
