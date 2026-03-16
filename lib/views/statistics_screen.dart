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
          baslik: "Günlük Seri",
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
    final simdi = DateTime.now();
    final ayAdi = DateFormat('MMMM yyyy', 'tr_TR').format(simdi);

    // Ayın kaç gün olduğunu ve hangi günle başladığını bulalım
    final ayinIlkGunu = DateTime(simdi.year, simdi.month, 1);
    final ayinSonGunu = DateTime(simdi.year, simdi.month + 1, 0).day;
    final baslangicBoslugu = ayinIlkGunu.weekday - 1; // Pazartesi = 0

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

          // Gün İsimleri (Pzt, Sal...)
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

          // Takvim Grid'i
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

              // ŞİMDİLİK TASARIM İÇİN RASTGELE VAKİT SAYISI (Mantık sonra eklenecek)
              // Örn: Bugünden önceki günler için 0-5 arası değer
              int vakitSayisi = (gun % 6);

              return _buildTakvimGunu(context, gun, vakitSayisi);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTakvimGunu(BuildContext context, int gun, int vakitSayisi) {
    final r = context.renkler;

    // Belirlediğin renk skalası
    final Map<int, Color> renkSkalasi = {
      0: const Color(0xFFFF6961),
      1: const Color(0xFFFCA364),
      2: const Color(0xFFF8D66D),
      3: const Color(0xFFD0D473),
      4: const Color(0xFFB0D476),
      5: const Color(0xFF8CD47E),
    };

    return Container(
      decoration: BoxDecoration(
        color: renkSkalasi[vakitSayisi],
        borderRadius: BorderRadius.circular(Responsive.w(8)),
      ),
      child: Center(
        child: Text(
          "$gun",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(12),
            shadows: const [Shadow(blurRadius: 2, color: Colors.black26)],
          ),
        ),
      ),
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
