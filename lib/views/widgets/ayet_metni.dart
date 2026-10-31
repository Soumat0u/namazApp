import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

import '../../services/kuran_okuyucu.dart';

/// Ayetin Arapça metni. Tilavet sırasında okunan kelime aydınlatılır; okunmuş kelimeler hafif soluklaşır.
/// Kelime verisi henüz yoksa (internetsiz ilk açılış) metin düz gösterilir.
class AyetMetni extends StatelessWidget {
  final KuranOkuyucu okuyucu;
  final int sure;
  final int ayet;
  final TextStyle stil;
  final Color vurguRengi;
  final TextAlign hiza;

  const AyetMetni({
    super.key,
    required this.okuyucu,
    required this.sure,
    required this.ayet,
    required this.stil,
    this.vurguRengi = Colors.amber,
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
    final aktif = buAyet ? okuyucu.aktifKelime : null;
    return Text.rich(
      TextSpan(children: [
        for (int i = 0; i < veri.kelimeler.length; i++) ...[
          TextSpan(
            text: veri.kelimeler[i],
            style: aktif == i + 1
                ? stil.copyWith(
                    backgroundColor: vurguRengi.withOpacity(0.45),
                    color: stil.color,
                    fontWeight: FontWeight.bold,
                  )
                : (aktif != null && i + 1 < aktif)
                    ? stil.copyWith(color: stil.color?.withOpacity(0.55))
                    : stil,
          ),
          if (i < veri.kelimeler.length - 1) TextSpan(text: ' ', style: stil),
        ],
        TextSpan(text: bitis, style: stil),
      ]),
      textAlign: hiza,
      textDirection: TextDirection.rtl,
    );
  }
}
