import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/bildirim.dart';
import '../../core/utils/responsive.dart';

/// Bağış (havale/EFT) bilgileri. IBAN boşsa "Bize Destek Ol" butonu gösterilmez.
class DestekBilgisi {
  static const String aliciAdi = 'Muhammed Şafak Çiftçi';
  static const String iban = 'TR590001000186821167885001';

  static bool get hazir => iban.isNotEmpty;

  /// "TR12 3456 ..." biçiminde, dörderli gruplar
  static String get ibanGorunen {
    final duz = iban.replaceAll(' ', '');
    final parcalar = <String>[];
    for (var i = 0; i < duz.length; i += 4) {
      parcalar.add(duz.substring(i, i + 4 > duz.length ? duz.length : i + 4));
    }
    return parcalar.join(' ');
  }
}

void destekOlGoster(BuildContext context, AppThemeColors r) {
  void kopyala(String metin, String ne) {
    Clipboard.setData(ClipboardData(text: metin));
    Bildirim.snackBar(SnackBar(content: Text("$ne kopyalandı"), duration: const Duration(seconds: 2)));
  }

  Widget satir(String etiket, String deger, String kopyalanacak) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(10)),
      padding: EdgeInsets.fromLTRB(Responsive.w(14), Responsive.h(10), Responsive.w(4), Responsive.h(10)),
      decoration: BoxDecoration(
        color: r.anaRenk.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(etiket, style: TextStyle(fontSize: Responsive.sp(11), color: r.yaziRengi.withOpacity(0.6))),
                SizedBox(height: Responsive.h(2)),
                SelectableText(
                  deger,
                  style: TextStyle(
                    fontSize: Responsive.sp(15),
                    fontWeight: FontWeight.bold,
                    color: r.yaziRengi,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: "Kopyala",
            icon: Icon(Icons.copy_rounded, color: r.anaRenk, size: Responsive.w(20)),
            onPressed: () => kopyala(kopyalanacak, etiket),
          ),
        ],
      ),
    );
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: r.arkaPlanRengi,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (context) => SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(Responsive.w(20), Responsive.h(16), Responsive.w(20), Responsive.h(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: r.pasifRenk.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            SizedBox(height: Responsive.h(20)),
            Icon(Icons.volunteer_activism_rounded, color: r.anaRenk, size: Responsive.w(40)),
            SizedBox(height: Responsive.h(12)),
            Text(
              "Bize Destek Ol",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.sp(18), fontWeight: FontWeight.bold, color: r.yaziRengi),
            ),
            SizedBox(height: Responsive.h(8)),
            Text(
              "Takva Yolum'u reklamsız ve ücretsiz tutmak istiyoruz. Namaz vakitlerin, "
              "dualar ve okudukların araya giren reklamlarla bölünmesin, verilerin "
              "kimseye satılmasın diye.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.sp(13), color: r.yaziRengi.withOpacity(0.75), height: 1.45),
            ),
            SizedBox(height: Responsive.h(10)),
            Text(
              "Ama sunucular, güncellemeler ve yeni içerikler (ansiklopedi maddeleri, "
              "dualar, ilmihal) emek ve masraf istiyor. Uygulamayı ayakta tutan tek şey "
              "senin gibi kullanıcıların desteği. Az ya da çok, her katkı uygulamanın "
              "binlerce kişiye ulaşmaya devam etmesini sağlar ve sadaka-i câriye niyetiyle "
              "yapılan bir hayra ortak olursun.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.sp(13), color: r.yaziRengi.withOpacity(0.75), height: 1.45),
            ),
            SizedBox(height: Responsive.h(10)),
            Text(
              "Allah razı olsun.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.sp(13), fontWeight: FontWeight.w600, color: r.anaRenk),
            ),
            SizedBox(height: Responsive.h(20)),
            if (DestekBilgisi.aliciAdi.isNotEmpty)
              satir("Alıcı", DestekBilgisi.aliciAdi, DestekBilgisi.aliciAdi),
            satir("IBAN", DestekBilgisi.ibanGorunen, DestekBilgisi.iban.replaceAll(' ', '')),
            SizedBox(height: Responsive.h(4)),
            Text(
              "Açıklama kısmına \"Bağış\" yazabilirsin.",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.sp(11), color: r.yaziRengi.withOpacity(0.55)),
            ),
          ],
        ),
      ),
    ),
  );
}
