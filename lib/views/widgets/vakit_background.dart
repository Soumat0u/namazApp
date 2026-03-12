import 'dart:math' as math;
import 'package:flutter/material.dart';

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
          decoration: BoxDecoration(
            gradient: _getGradient(widget.tema),
          ),
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
  _VakitPainter({required this.tema, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    if (tema == 'night') {
      _drawStars(canvas, size, paint);
    } else if (tema == 'dawn' || tema == 'afternoon') {
      _drawClouds(canvas, size, paint, Colors.white.withOpacity(0.1));
      _drawSun(canvas, size, paint, tema == 'dawn' ? 0.8 : 0.2);
    } else if (tema == 'sunset') {
      _drawStars(canvas, size, paint, density: 10);
      _drawClouds(canvas, size, paint, Colors.white.withOpacity(0.05));
    } else {
      _drawSun(canvas, size, paint, 0.1);
      _drawClouds(canvas, size, paint, Colors.white.withOpacity(0.2));
    }
  }

  void _drawStars(Canvas canvas, Size size, Paint paint, {int density = 40}) {
    final random = math.Random(42);
    for (int i = 0; i < density; i++) {
      double x = random.nextDouble() * size.width;
      double y = random.nextDouble() * size.height;
      double r = random.nextDouble() * 1.5;
      double opacity = 0.3 + 0.4 * math.sin(progress * 2 * math.pi + i);
      paint.color = Colors.white.withOpacity(opacity.clamp(0.0, 1.0));
      canvas.drawCircle(Offset(x, y), r, paint);
    }
  }

  void _drawSun(Canvas canvas, Size size, Paint paint, double yOffsetFactor) {
    final center = Offset(size.width * 0.8, size.height * yOffsetFactor);
    final radius = size.width * 0.15;
    
    // Glow
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.yellow.withOpacity(0.3),
          Colors.yellow.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 3));
    canvas.drawCircle(center, radius * 3, glowPaint);

    paint.color = Colors.yellow.shade200;
    canvas.drawCircle(center, radius, paint);
  }

  void _drawMoon(Canvas canvas, Size size, Paint paint) {
    final center = Offset(size.width * 0.75, size.height * 0.2);
    final radius = size.width * 0.12;

    // Gradienli Ay (Beyazdan hafif sarıya/şeffafa)
    paint.shader = RadialGradient(
      colors: [
        Colors.white.withOpacity(0.95),
        Colors.white.withOpacity(0.6),
      ],
    ).createShader(Rect.fromCircle(center: center, radius: radius));
    canvas.drawCircle(center, radius, paint);

    // Gradienli Kapatıcı (Arkaplan geçişine uyumlu)
    final shadowCenter = center.translate(-radius * 0.4, -radius * 0.2);
    paint.shader = RadialGradient(
      colors: [
        const Color(0xFF0F2027), // Karanlık gökyüzünün üst rengi
        const Color(0xFF203A43).withOpacity(0.8), // Orta rengi
      ],
      center: Alignment.center,
    ).createShader(Rect.fromCircle(center: shadowCenter, radius: radius));
    
    canvas.drawCircle(shadowCenter, radius, paint);
    paint.shader = null; // Diğer çizimler için shader'ı temizle
  }

  void _drawClouds(Canvas canvas, Size size, Paint paint, Color color) {
    paint.color = color;
    final random = math.Random(123);
    for (int i = 0; i < 4; i++) {
      double speed = 0.5 + (i * 0.2);
      double xBase = random.nextDouble() * size.width;
      double yBase = 20.0 + random.nextDouble() * size.height * 0.4;
      double x = (xBase + (progress * size.width * speed)) % (size.width + 200) - 100;

      _drawSingleCloud(canvas, Offset(x, yBase), 60 + random.nextDouble() * 40, paint);
    }
  }

  void _drawSingleCloud(Canvas canvas, Offset center, double width, Paint paint) {
    final height = width * 0.4;
    canvas.drawOval(Rect.fromCenter(center: center, width: width, height: height), paint);
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(width * 0.2, -height * 0.3), width: width * 0.8, height: height * 0.9),
      paint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: center.translate(-width * 0.2, -height * 0.2), width: width * 0.7, height: height * 0.8),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant _VakitPainter oldDelegate) => true;
}
