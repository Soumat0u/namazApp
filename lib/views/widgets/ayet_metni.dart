import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

import '../../services/kuran_okuyucu.dart';

/// Okunan kelimenin yazısı parlar: renk altına döner ve etrafına ışıltı yayılır ([t] 0..1 animasyon ilerlemesi)
TextStyle parlayanStil(TextStyle stil, double t, {Color renk = const Color(0xFFFFC107)}) {
  final temel = stil.color ?? Colors.black;
  return stil.copyWith(
    color: Color.lerp(temel, renk, t),
    fontWeight: FontWeight.lerp(stil.fontWeight ?? FontWeight.normal, FontWeight.w700, t),
    shadows: [
      Shadow(color: renk.withOpacity(0.85 * t), blurRadius: 14 * t),
      Shadow(color: renk.withOpacity(0.5 * t), blurRadius: 4 * t),
    ],
  );
}

/// Kelime dizisini RTL çizer; [aktif] (0'dan) kelime her değiştiğinde yeniden parlayarak belirir,
/// okunmuş kelimeler hafif soluklaşır.
class ParlayanKelimeler extends StatelessWidget {
  final List<String> kelimeler;
  final int? aktif;
  final TextStyle stil;
  final String sonEk;
  final TextAlign hiza;

  const ParlayanKelimeler({
    super.key,
    required this.kelimeler,
    required this.aktif,
    required this.stil,
    this.sonEk = '',
    this.hiza = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(aktif), // Her yeni kelimede animasyon baştan başlar
      tween: Tween(begin: aktif == null ? 1 : 0, end: 1),
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOut,
      builder: (context, t, _) => Text.rich(
        TextSpan(children: [
          for (int i = 0; i < kelimeler.length; i++) ...[
            TextSpan(
              text: kelimeler[i],
              style: i == aktif
                  ? parlayanStil(stil, t)
                  : (aktif != null && i < aktif!)
                      ? stil.copyWith(color: stil.color?.withOpacity(0.55))
                      : stil,
            ),
            if (i < kelimeler.length - 1) TextSpan(text: ' ', style: stil),
          ],
          if (sonEk.isNotEmpty) TextSpan(text: sonEk, style: stil),
        ]),
        textAlign: hiza,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}

/// Ayetin Arapça metni; tilavette okunan kelime parlar.
/// Kelime verisi henüz yoksa (internetsiz ilk açılış) metin düz gösterilir.
class AyetMetni extends StatelessWidget {
  final KuranOkuyucu okuyucu;
  final int sure;
  final int ayet;
  final TextStyle stil;
  final TextAlign hiza;

  const AyetMetni({
    super.key,
    required this.okuyucu,
    required this.sure,
    required this.ayet,
    required this.stil,
    this.hiza = TextAlign.right,
  });

  @override
  Widget build(BuildContext context) {
    final veri = okuyucu.kelimeler(sure, ayet);
    final bitis = ' ${quran.getVerseEndSymbol(ayet)}';
    if (veri == null || veri.kelimeler.isEmpty) {
      return Text(quran.getVerse(sure, ayet) + bitis, textAlign: hiza, textDirection: TextDirection.rtl, style: stil);
    }
    final buAyet = okuyucu.aktifAyet?.sure == sure && okuyucu.aktifAyet?.ayet == ayet;
    final aktif = buAyet && okuyucu.aktifKelime != null ? okuyucu.aktifKelime! - 1 : null;
    return ParlayanKelimeler(kelimeler: veri.kelimeler, aktif: aktif, stil: stil, sonEk: bitis, hiza: hiza);
  }
}
