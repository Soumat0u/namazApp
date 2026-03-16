import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

// 1. ADIM: Sınıfı en dışa (top-level) taşıdık.
class ShootingStar {
  final double startX;
  final double startY;
  final double angle;
  final double speed;
  final double tailLength;
  final double startProgress;
  final double duration;

  const ShootingStar({
    required this.startX,
    required this.startY,
    required this.angle,
    required this.speed,
    required this.tailLength,
    required this.startProgress,
    required this.duration,
  });
}

class VakitBackground extends StatefulWidget {
  final String tema;
  final Widget? child;
  final BorderRadius? borderRadius;

  const VakitBackground({
    super.key,
    required this.tema,
    this.child,
    this.borderRadius,
  });

  @override
  State<VakitBackground> createState() => _VakitBackgroundState();
}

class _VakitBackgroundState extends State<VakitBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(seconds: 1),
      child: ClipRRect(
        key: ValueKey(widget.tema),
        borderRadius: widget.borderRadius ?? BorderRadius.zero,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(gradient: _getGradient(widget.tema)),
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return CustomPaint(
                      painter: _VakitPainter(
                        tema: widget.tema,
                        progress: _controller.value,
                      ),
                    );
                  },
                ),
              ),
              if (widget.child != null) Center(child: widget.child!),
            ],
          ),
        ),
      ),
    );
  }

  LinearGradient _getGradient(String tema) {
    switch (tema) {
      case 'dawn':
        return const LinearGradient(
          colors: [Color(0xFF2C3E50), Color(0xFFFD746C)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'morning':
        return const LinearGradient(
          colors: [Color(0xFF4facfe), Color(0xFF00f2fe)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
      case 'day':
        return const LinearGradient(
          colors: [Color(0xFF2980B9), Color(0xFF6DD5FA)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'afternoon':
        return const LinearGradient(
          colors: [Color(0xFFf093fb), Color(0xFFf5576c)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        );
      case 'sunset':
        return const LinearGradient(
          colors: [Color(0xFF434343), Color(0xFF000000)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
      case 'night':
      default:
        return const LinearGradient(
          colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
    }
  }
}

class _VakitPainter extends CustomPainter {
  final String tema;
  final double progress;

  late final List<ShootingStar> _shootingStars;

  _VakitPainter({required this.tema, required this.progress}) {
    _shootingStars = _generateStars();
  }

  // Yıldız üreten yardımcı fonksiyon
  List<ShootingStar> _generateStars() {
    // Sabit seed (titremeyi önler) ama yıldız sayısını ve alanını artırarak rastgeleliği sağlıyoruz
    final rng = math.Random(42);
    return List.generate(
      5, // Ekranda döngü boyunca ara sıra çıkacak 5 farklı meteor
      (_) => ShootingStar(
        // Ekranın daha geniş bir alanından (dışarıdan da) çıkabilmeleri için -%20 ile +%120 arası:
        startX: -0.2 + rng.nextDouble() * 1.4,
        startY: -0.2 + rng.nextDouble() * 0.7,
        // Meteor yağmuru hissi için belirli bir radyan etrafında ufak sapmalar (~45 derece):
        angle: math.pi / 4 + (rng.nextDouble() - 0.5) * 0.3,
        // Kat edilecek toplam mesafe çarpanı (hız ve menzil):
        speed: 0.5 + rng.nextDouble() * 0.7,
        // ARTIK kuyruk uzunluğu değil, "kuyruğun kafayı ne kadar geriden takip edeceği" gecikme payı:
        tailLength: 0.05 + rng.nextDouble() * 0.1,
        // Döngünün neresinde başlayacağı:
        startProgress: rng.nextDouble(),
        // Ekranda kalma süresi:
        duration: 0.1 + rng.nextDouble() * 0.15,
      ),
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    if (tema == 'night') {
      _drawShootingStar(canvas, size, paint);
      _drawStars(canvas, size, paint);
      _drawMoon(canvas, size, paint);
    } else if (tema == 'sunset') {
      _drawStars(canvas, size, paint, density: 10);
      _drawClouds(canvas, size, paint, Colors.white.withValues(alpha: 0.05));
    } else if (tema == 'dawn' || tema == 'afternoon') {
      _drawClouds(canvas, size, paint, Colors.white.withValues(alpha: 0.1));
      _drawSun(canvas, size, paint, tema == 'dawn' ? 0.8 : 0.2);
    } else {
      _drawSun(canvas, size, paint, 0.1);
      _drawClouds(canvas, size, paint, Colors.white.withValues(alpha: 0.2));
    }
  }

  void _drawShootingStar(Canvas canvas, Size size, Paint paint) {
    for (final star in _shootingStars) {
      _drawSingleShootingStar(canvas, size, paint, star);
    }
  }

  void _drawSingleShootingStar(
    Canvas canvas,
    Size size,
    Paint paint,
    ShootingStar star,
  ) {
    // Progress sarmasını (wrap around) pürüzsüz hale getiriyoruz
    double raw = progress - star.startProgress;
    if (raw < 0) raw += 1.0;

    // Yıldızın yaşam süresi bittiyse çizme
    if (raw > star.duration) return;

    // Yıldızın kendi 0.0 ile 1.0 arası yaşam döngüsü
    final double normalizedTime = raw / star.duration;

    // 🌟 YENİ MANTIK: Kuyruk artık kafayı gerçek zamanlı izliyor
    // Kafanın (head) zamanı
    final double tHead = _easeOut(normalizedTime);
    // Kuyruğun (tail) zamanı - kuyruk belirlenen pay kadar geriden gelir
    final double tTail = _easeOut(
      math.max(0.0, normalizedTime - star.tailLength),
    );

    final double originX = size.width * star.startX;
    final double originY = size.height * star.startY;

    // Hedef rotanın uzunluğu
    final double travelX = math.cos(star.angle) * size.width * star.speed;
    final double travelY = math.sin(star.angle) * size.height * star.speed;

    // Kafanın ekrandaki anlık konumu
    final double headX = originX + travelX * tHead;
    final double headY = originY + travelY * tHead;

    // Kuyruğun ekrandaki anlık konumu (Tam olarak aynı rotayı geriden izler)
    final double tailX = originX + travelX * tTail;
    final double tailY = originY + travelY * tTail;

    final double alpha = _starAlpha(normalizedTime);

    // 1. Dış Kuyruk
    final tailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(headX, headY),
        Offset(tailX, tailY),
        [
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: 0.0),
        ],
      );

    canvas.drawLine(Offset(headX, headY), Offset(tailX, tailY), tailPaint);

    // 2. İç (Parlak) Kuyruk
    final innerTailPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..strokeCap = StrokeCap.round
      ..shader = ui.Gradient.linear(
        Offset(headX, headY),
        Offset(headX + (tailX - headX) * 0.4, headY + (tailY - headY) * 0.4),
        [
          Colors.white.withValues(alpha: alpha),
          Colors.white.withValues(alpha: 0.0),
        ],
      );

    canvas.drawLine(
      Offset(headX, headY),
      Offset(headX + (tailX - headX) * 0.4, headY + (tailY - headY) * 0.4),
      innerTailPaint,
    );

    // 3. Yıldız Çekirdeği Palaması (Glow)
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.0)
      ..color = Colors.white.withValues(alpha: alpha * 0.7);
    canvas.drawCircle(Offset(headX, headY), 3.0, glowPaint);

    // 4. Yıldız Çekirdeği
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.white.withValues(alpha: alpha);
    canvas.drawCircle(Offset(headX, headY), 1.5, paint);
  }

  double _easeOut(double t) => 1.0 - math.pow(1.0 - t, 2.5).toDouble();

  double _starAlpha(double t) {
    const fadeZone = 0.2;
    if (t < fadeZone) return t / fadeZone;
    if (t > 1.0 - fadeZone) return (1.0 - t) / fadeZone;
    return 1.0;
  }

  void _drawMoon(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.83, size.height * 0.25);
    final radius = size.width * 0.12;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: 0.15),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 3));
    canvas.drawCircle(center, radius * 3, glowPaint);

    paint.color = Colors.white;

    final moonPath = Path.combine(
      PathOperation.difference,
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Path()..addOval(
        Rect.fromCircle(
          center: center.translate(-radius * 0.6, -radius * 0.3),
          radius: radius,
        ),
      ),
    );
    canvas.drawPath(moonPath, paint);
  }

  void _drawStars(Canvas canvas, Size size, Paint paint, {int density = 40}) {
    final random = math.Random(42);
    for (int i = 0; i < density; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double r = random.nextDouble() * 1.5;
      double opacity = 0.3 + 0.4 * math.sin(progress * 2 * math.pi + i);
      paint.color = Colors.white.withValues(alpha: opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _drawSun(Canvas canvas, Size size, Paint paint, double yOffsetFactor) {
    final center = Offset(size.width * 0.8, size.height * yOffsetFactor);
    final radius = size.width * 0.15;

    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.yellow.withValues(alpha: 0.3),
          Colors.yellow.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 3));
    canvas.drawCircle(center, radius * 3, glowPaint);

    paint.color = Colors.yellow.shade200;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawClouds(Canvas canvas, Size size, Paint paint, Color color) {
    paint.color = color;
    final random = math.Random(123);
    for (int i = 0; i < 4; i++) {
      double speed = 0.5 + (i * 0.2);
      double xBase = random.nextDouble() * size.width;
      double yBase = 20.0 + random.nextDouble() * size.height * 0.4;
      double x =
          (xBase + (progress * size.width * speed)) % (size.width + 200) - 100;
      _drawSingleCloud(
        canvas,
        Offset(x, yBase),
        60 + random.nextDouble() * 40,
        paint,
      );
    }
  }

  void _drawSingleCloud(
    Canvas canvas,
    Offset center,
    double width,
    Paint paint,
  ) {
    final height = width * 0.4;
    canvas.drawOval(
      Rect.fromCenter(center: center, width: width, height: height),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(width * 0.2, -height * 0.3),
        width: width * 0.8,
        height: height * 0.9,
      ),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-width * 0.2, -height * 0.2),
        width: width * 0.7,
        height: height * 0.8,
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VakitPainter oldDelegate) {
    return oldDelegate.tema != tema || oldDelegate.progress != progress;
  }
}
