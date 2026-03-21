import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import 'package:intl/intl.dart';

class IstatistikSayfasi extends StatelessWidget {
  const IstatistikSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final r = context.renkler;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        title: Text(
          "Vakit Analizi",
          style: TextStyle(
            color: r.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(18),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.all(Responsive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üstteki sayaçlar
            _buildKucukOzetKartlari(context, provider),

            SizedBox(height: Responsive.h(24)),

            // Aylık Takvim Bölümü
            _buildAylikTakvim(context, provider),

            SizedBox(height: Responsive.h(24)),

            // Renk Skalası Bilgilendirmesi
            _buildRenkLejanti(context),

            SizedBox(height: Responsive.h(40)),
          ],
        ),
      ),
    );
  }

  // Üstteki seri ve toplam sayaçlarının küçültülmüş hali
  Widget _buildKucukOzetKartlari(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    return Row(
      children: [
        _kucukIstatistikKutusu(
          context,
          baslik: "Seri",
          deger: "${provider.streakCount}",
          ikon: Icons.local_fire_department,
          renk: r.anaRenk,
        ),
        SizedBox(width: Responsive.w(12)),
        _kucukIstatistikKutusu(
          context,
          baslik: "Toplam Vakit",
          deger: "${provider.toplamTamamlanan}",
          ikon: Icons.check_circle_rounded,
          renk: r.aktifYesil,
        ),
      ],
    );
  }

  Widget _kucukIstatistikKutusu(
    BuildContext context, {
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
  }) {
    final r = context.renkler;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(Responsive.w(12)),
        decoration: BoxDecoration(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(12)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(ikon, color: renk, size: Responsive.w(18)),
            SizedBox(width: Responsive.w(8)),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deger,
                  style: TextStyle(
                    fontSize: Responsive.sp(15),
                    fontWeight: FontWeight.bold,
                    color: r.yaziRengi,
                  ),
                ),
                Text(
                  baslik,
                  style: TextStyle(
                    fontSize: Responsive.sp(10),
                    color: r.yaziRengi.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Ana Takvim Widget'ı
  Widget _buildAylikTakvim(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    final sanalBugun = provider.getSanalSimdi();
    final ayAdi = DateFormat('MMMM yyyy', 'tr_TR').format(sanalBugun);

    final ayinIlkGunu = DateTime(sanalBugun.year, sanalBugun.month, 1);
    final ayinSonGunu = DateTime(sanalBugun.year, sanalBugun.month + 1, 0).day;
    final baslangicBoslugu = ayinIlkGunu.weekday - 1;

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            ayAdi.toUpperCase(),
            style: TextStyle(
              fontSize: Responsive.sp(16),
              fontWeight: FontWeight.w900,
              color: r.anaRenk,
              letterSpacing: 1.2,
            ),
          ),
          SizedBox(height: Responsive.h(4)),
          Divider(color: r.anaRenk.withOpacity(0.1), thickness: 1),
          SizedBox(height: Responsive.h(12)),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ["Pzt", "Sal", "Çar", "Per", "Cum", "Cmt", "Paz"].map((
              g,
            ) {
              return SizedBox(
                width: Responsive.w(35),
                child: Text(
                  g,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.sp(11),
                    fontWeight: FontWeight.bold,
                    color: r.yaziRengi.withOpacity(0.4),
                  ),
                ),
              );
            }).toList(),
          ),
          SizedBox(height: Responsive.h(10)),

          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: ayinSonGunu + baslangicBoslugu,
            itemBuilder: (context, index) {
              if (index < baslangicBoslugu) return const SizedBox();

              final gun = index - baslangicBoslugu + 1;
              final hucreTarihi = DateTime(sanalBugun.year, sanalBugun.month, gun);

              final sanalBugunStr = provider.getSanalGun();
              final sanalBugunObj = DateFormat('yyyy-MM-dd').parse(sanalBugunStr);

              int vakitSayisi;

              if (hucreTarihi.isAfter(sanalBugunObj)) {
                vakitSayisi = -1; // Gelecek günler
              } else if (provider.ilkAcilisTarihi != null &&
                  hucreTarihi.isBefore(provider.ilkAcilisTarihi!)) {
                vakitSayisi = -1; // Uygulama açılışından öncesi
              } else {
                String dateKey = DateFormat('yyyy-MM-dd').format(hucreTarihi);
                vakitSayisi = provider.aylikGecmis[dateKey] ?? 0;
              }

              bool isSanalBugun = DateFormat('yyyy-MM-dd').format(hucreTarihi) == sanalBugunStr;

              return _buildTakvimGunu(
                context,
                gun,
                vakitSayisi,
                hucreTarihi,
                provider,
                isSanalBugun: isSanalBugun,
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTakvimGunu(
  BuildContext context,
  int gun,
  int vakitSayisi,
  DateTime hucreTarihi,
  NamazProvider provider, {
  bool isSanalBugun = false,
}) {
  final r = context.renkler;

  final Map<int, Color> renkSkalasi = {
    -1: r.pasifRenk.withOpacity(0.15),
    0: const Color(0xFFFF6961),
    1: const Color(0xFFFCA364),
    2: const Color(0xFFF8D66D),
    3: const Color(0xFFD0D473),
    4: const Color(0xFFB0D476),
    5: const Color(0xFF8CD47E),
  };

  Color hucreRengi;
  if (isSanalBugun) {
    // Bugün renksiz (pasif kutucuklarla aynı) ama çerçeveli
    hucreRengi = r.pasifRenk.withOpacity(0.15);
  } else {
    hucreRengi = renkSkalasi[vakitSayisi] ?? r.pasifRenk.withOpacity(0.15);
  }

  // Sadece kesinleşmiş geçmiş günler (vakitSayisi != -1) ve bugün olmayan günler tıklanabilir.
  bool tiklanabilir = vakitSayisi != -1 && !isSanalBugun;

  return GestureDetector(
    onTap: tiklanabilir 
        ? () => _gunDetayiGoster(context, hucreTarihi, provider, vakitSayisi)
        : null,
    child: AnimatedContainer( // Görsel geri bildirim için AnimatedContainer
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: hucreRengi,
        borderRadius: BorderRadius.circular(Responsive.w(8)),
        border: isSanalBugun
            ? Border.all(color: r.anaRenk, width: 2)
            : (tiklanabilir ? Border.all(color: Colors.black.withOpacity(0.05)) : null),
      ),
      child: Center(
        child: Text(
          "$gun",
          style: TextStyle(
            color: isSanalBugun 
                ? r.yaziRengi 
                : (tiklanabilir ? Colors.white : r.yaziRengi.withOpacity(0.4)),
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(12),
          ),
        ),
      ),
    ),
  );
}

  void _gunDetayiGoster(
  BuildContext context,
  DateTime tarih,
  NamazProvider provider,
  int toplamVakit,
) {
  // 🔥 HATA BURADAYDI: watch kullanan 'renkler' yerine 'renklerOku' kullanmalısın
  final r = context.renklerOku; 
  
  String dateKey = DateFormat('yyyy-MM-dd').format(tarih);
  String displayDate = DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(tarih);
  String bugunKey = DateFormat('yyyy-MM-dd').format(DateTime.now());

  // Veriyi güvenli çekme
  Map<String, dynamic> detaylar;
  if (dateKey == bugunKey) {
    detaylar = provider.kildiMi;
  } else {
    var data = provider.gunlukDetaylar[dateKey];
    detaylar = data != null ? Map<String, dynamic>.from(data) : {};
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: r.arkaPlanRengi,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
    ),
    builder: (context) {
      return Container(
        padding: EdgeInsets.all(Responsive.w(20)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40, 
              height: 5, 
              decoration: BoxDecoration(
                color: r.pasifRenk.withOpacity(0.5), 
                borderRadius: BorderRadius.circular(10)
              )
            ),
            SizedBox(height: 20),
            Text(displayDate, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: r.yaziRengi)),
            Text("$toplamVakit / 5 Vakit Kılındı", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            if (detaylar.isEmpty && toplamVakit > 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Text("Bu güne ait detaylı veri bulunamadı.", textAlign: TextAlign.center),
              )
            else
              ...provider.vakitIsimleri.map((vakit) {
                bool kilindiMi = detaylar[vakit] == true;
                return ListTile(
                  leading: Icon(
                    kilindiMi ? Icons.check_circle : Icons.radio_button_unchecked, 
                    color: kilindiMi ? r.aktifYesil : r.pasifRenk
                  ),
                  title: Text(vakit, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w500)),
                );
              }),
            SizedBox(height: Responsive.h(20)),
          ],
        ),
      );
    },
  );
}

  // Renklerin ne anlama geldiğini gösteren alt kısım
  Widget _buildRenkLejanti(BuildContext context) {
    final r = context.renkler;
    return Container(
      padding: EdgeInsets.all(Responsive.w(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Vakit Takibi Renk Skalası",
            style: TextStyle(
              fontSize: Responsive.sp(12),
              fontWeight: FontWeight.bold,
              color: r.yaziRengi.withOpacity(0.6),
            ),
          ),
          SizedBox(height: Responsive.h(10)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              final Map<int, Color> renkler = {
                0: const Color(0xFFFF6961),
                1: const Color(0xFFFCA364),
                2: const Color(0xFFF8D66D),
                3: const Color(0xFFD0D473),
                4: const Color(0xFFB0D476),
                5: const Color(0xFF8CD47E),
              };
              return Column(
                children: [
                  Container(
                    width: Responsive.w(25),
                    height: Responsive.h(10),
                    decoration: BoxDecoration(
                      color: renkler[i],
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  SizedBox(height: Responsive.h(4)),
                  Text(
                    "$i Vakit",
                    style: TextStyle(
                      fontSize: Responsive.sp(9),
                      color: r.yaziRengi.withOpacity(0.5),
                    ),
                  ),
                ],
              );
            }),
          ),
        ],
      ),
    );
  }
}
