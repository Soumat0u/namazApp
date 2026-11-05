import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/theme_provider.dart';

/// Uygulama içi bildirimler: ekranın üstünden kayarak inen, temanın
/// renginde bir kart. Alttan çıkan SnackBar'ın yerine geçer; çağıranlar
/// yine bir SnackBar verir (içerik, eylem, süre ve renk ondan okunur).
///
///   Bildirim.snackBar(SnackBar(content: Text('Kaydedildi')));
///
/// Aynı anda tek bildirim görünür; yenisi gelince eskisi kapanır.
class Bildirim {
  /// MaterialApp'e verilir: bildirim, context olmadan da (await sonrası vb.)
  /// en üstteki katmana çizilebilsin
  static final navigatorKey = GlobalKey<NavigatorState>();

  static OverlayEntry? _aktif;
  static GlobalKey<_BildirimKartiState>? _aktifKart;

  static void snackBar(SnackBar s) {
    final overlay = navigatorKey.currentState?.overlay;
    final ctx = navigatorKey.currentContext;
    if (overlay == null || ctx == null) return;
    kapat(animasyonlu: false);

    final tur = _turu(s);
    final tema = ctx.read<ThemeProvider>().aktifTema;
    final key = GlobalKey<_BildirimKartiState>();
    final sure = s.action != null && s.duration == const Duration(milliseconds: 4000)
        ? const Duration(seconds: 5) // geri al gibi eylemler için biraz daha uzun
        : s.duration;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _BildirimKarti(
        key: key,
        icerik: s.content,
        eylem: s.action,
        tur: tur,
        renk: tur == _Tur.bilgi ? (s.backgroundColor ?? tema.anaRenk) : null,
        kart: tema.kartRengi,
        yazi: tema.yaziRengi,
        sure: sure,
        kapandi: () {
          if (_aktif == entry) {
            _aktif = null;
            _aktifKart = null;
          }
          if (entry.mounted) entry.remove();
        },
      ),
    );
    _aktif = entry;
    _aktifKart = key;
    overlay.insert(entry);
  }

  /// Açık bildirimi kapatır (SnackBar'daki hideCurrentSnackBar/clearSnackBars)
  static void kapat({bool animasyonlu = true}) {
    final kart = _aktifKart?.currentState;
    if (animasyonlu && kart != null) {
      kart.kapat();
      return;
    }
    final e = _aktif;
    _aktif = null;
    _aktifKart = null;
    if (e != null && e.mounted) e.remove();
  }

  /// SnackBar'ın rengi ve metninden türü tahmin eder
  static _Tur _turu(SnackBar s) {
    final c = s.backgroundColor;
    if (c != null) {
      final hsv = HSVColor.fromColor(c);
      if (hsv.saturation > 0.35) {
        if (hsv.hue < 15 || hsv.hue > 340) return _Tur.hata;
        if (hsv.hue > 80 && hsv.hue < 170) return _Tur.basari;
      }
    }
    final metin = s.content is Text ? ((s.content as Text).data ?? '').toLowerCase() : '';
    if (RegExp(r'hata|başarısız|açılamadı|yapılamadı|olmadı').hasMatch(metin)) return _Tur.hata;
    return _Tur.bilgi;
  }
}

enum _Tur { bilgi, basari, hata }

class _BildirimKarti extends StatefulWidget {
  const _BildirimKarti({
    super.key,
    required this.icerik,
    required this.eylem,
    required this.tur,
    required this.renk,
    required this.kart,
    required this.yazi,
    required this.sure,
    required this.kapandi,
  });

  final Widget icerik;
  final SnackBarAction? eylem;
  final _Tur tur;
  final Color? renk;
  final Color kart;
  final Color yazi;
  final Duration sure;
  final VoidCallback kapandi;

  @override
  State<_BildirimKarti> createState() => _BildirimKartiState();
}

class _BildirimKartiState extends State<_BildirimKarti> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 220),
  )..forward();
  Timer? _zaman;
  double _surukle = 0; // yukarı kaydırarak kapatma
  bool _kapaniyor = false;

  @override
  void initState() {
    super.initState();
    _zaman = Timer(widget.sure, kapat);
  }

  Future<void> kapat() async {
    if (_kapaniyor) return;
    _kapaniyor = true;
    _zaman?.cancel();
    if (mounted) await _a.reverse();
    widget.kapandi();
  }

  @override
  void dispose() {
    _zaman?.cancel();
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (IconData ikon, Color renk) = switch (widget.tur) {
      _Tur.basari => (Icons.check_circle_rounded, const Color(0xFF2E9D57)),
      _Tur.hata => (Icons.error_rounded, const Color(0xFFD64545)),
      _Tur.bilgi => (Icons.notifications_rounded, widget.renk!),
    };
    final egri = CurvedAnimation(parent: _a, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn);
    final ust = MediaQuery.paddingOf(context).top + 10;

    return Positioned(
      top: ust,
      left: 14,
      right: 14,
      child: AnimatedBuilder(
        animation: egri,
        builder: (_, child) => Transform.translate(
          offset: Offset(0, (1 - egri.value) * -(ust + 90) + _surukle),
          child: Opacity(opacity: _a.value.clamp(0.0, 1.0), child: child),
        ),
        child: GestureDetector(
          onTap: kapat,
          onVerticalDragUpdate: (d) => setState(() => _surukle = (_surukle + d.delta.dy).clamp(-200.0, 12.0)),
          onVerticalDragEnd: (d) {
            if (_surukle < -30 || d.primaryVelocity! < -300) {
              kapat();
            } else {
              setState(() => _surukle = 0);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
              decoration: BoxDecoration(
                color: widget.kart,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: renk.withOpacity(0.25)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.16), blurRadius: 24, offset: const Offset(0, 10)),
                  BoxShadow(color: renk.withOpacity(0.10), blurRadius: 12),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(color: renk.withOpacity(0.14), shape: BoxShape.circle),
                    child: Icon(ikon, color: renk, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DefaultTextStyle.merge(
                      style: TextStyle(color: widget.yazi, fontSize: 14, fontWeight: FontWeight.w600, height: 1.3),
                      child: IconTheme.merge(data: IconThemeData(color: renk), child: widget.icerik),
                    ),
                  ),
                  if (widget.eylem != null)
                    TextButton(
                      onPressed: () {
                        widget.eylem!.onPressed();
                        kapat();
                      },
                      style: TextButton.styleFrom(foregroundColor: renk, textStyle: const TextStyle(fontWeight: FontWeight.w800)),
                      child: Text(widget.eylem!.label),
                    )
                  else
                    const SizedBox(width: 4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
