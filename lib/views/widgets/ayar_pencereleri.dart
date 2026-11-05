import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/utils/bildirim.dart';
import '../../core/utils/responsive.dart';

/// "Bize Ulaşın" e-postasının gideceği adres
const String iletisimEposta = 'takvayolum@hotmail.com';

/// Kullanıcının e-posta uygulamasında, konusu ve sürüm bilgisi dolu bir taslak açar
Future<void> bizeUlasin() async {
  if (iletisimEposta.isEmpty) {
    Bildirim.snackBar(const SnackBar(content: Text("İletişim adresi yakında eklenecek.")));
    return;
  }
  var surum = '';
  try {
    final p = await PackageInfo.fromPlatform();
    surum = '${p.version} (${p.buildNumber})';
  } catch (_) {}
  final uri = Uri(
    scheme: 'mailto',
    path: iletisimEposta,
    // mailto'da + boşluk sayılmaz; Uri.encodeComponent %20 üretir
    query: 'subject=${Uri.encodeComponent('Takva Yolum - Geri Bildirim')}'
        '&body=${Uri.encodeComponent('\n\n\n— Uygulama sürümü: $surum')}',
  );
  final acildi = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
  if (!acildi) {
    Bildirim.snackBar(SnackBar(content: Text("E-posta uygulaması açılamadı. Adresimiz: $iletisimEposta")));
  }
}

/// Vakitlerin nasıl hesaplandığını anlatan pencere
void hesaplamaBilgisiGoster(BuildContext context, AppThemeColors r) {
  Widget paragraf(String metin) => Padding(
        padding: EdgeInsets.only(bottom: Responsive.h(10)),
        child: Text(
          metin,
          style: TextStyle(fontSize: Responsive.sp(13), color: r.yaziRengi.withOpacity(0.8), height: 1.45),
        ),
      );

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
            Icon(Icons.mosque_outlined, color: r.anaRenk, size: Responsive.w(40)),
            SizedBox(height: Responsive.h(12)),
            Text(
              "Diyanet İşleri Başkanlığı Yöntemi",
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: Responsive.sp(17), fontWeight: FontWeight.bold, color: r.yaziRengi),
            ),
            SizedBox(height: Responsive.h(16)),
            paragraf("Namaz vakitleri, Türkiye Diyanet İşleri Başkanlığı'nın kullandığı hesaplama yöntemine göre, "
                "bulunduğun konumun enlem ve boylamından hesaplanır."),
            paragraf("Bu yöntemde imsak vakti güneşin ufkun 18° altında, yatsı vakti ise 17° altında olduğu an "
                "esas alınır. İkindi vakti, bir cismin gölgesinin kendi boyu kadar uzadığı andır (asr-ı evvel)."),
            paragraf("Vakitler hesaplamayla bulunduğu için Diyanet'in yayımladığı takvimle arada 1-2 dakikalık "
                "farklar olabilir. Kesin vakit için ihtiyatlı davranmanı tavsiye ederiz."),
          ],
        ),
      ),
    ),
  );
}
