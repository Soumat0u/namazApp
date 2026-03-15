import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import 'gorevler_sayfasi.dart'; // 🔥 Sayfa yönlendirmesi için gerekli

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();

    if (provider.isLoading && provider.vakitler == null) {
      return Center(
        child: CircularProgressIndicator(color: context.renkler.anaRenk),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: context.renkler.anaRenk,
        backgroundColor: context.renkler.kartRengi,
        onRefresh: () => context.read<NamazProvider>().konumVeApiIstegi(
          kullaniciTetikledi: true,
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: EdgeInsets.all(Responsive.w(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildLevelCard(context, provider),
                SizedBox(height: Responsive.h(16)),
                _buildHeader(context, provider),
                SizedBox(height: Responsive.h(16)),
                _buildMainClock(context, provider),
                SizedBox(height: Responsive.h(16)),
                _buildVakitGrid(context, provider),
                SizedBox(height: Responsive.h(16)),
                _buildDailyQuests(context, provider), 
                SizedBox(height: Responsive.h(16)),
                _buildPrayerButton(context, provider),
                SizedBox(height: Responsive.h(10)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 🔥 YARDIMCI WIDGET METODLARI (HATALARI ÇÖZEN KISIM) ---

  Widget _buildLevelCard(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    return InkWell(
      onTap: () => _unvanlariGoster(context, provider, r),
      borderRadius: BorderRadius.circular(Responsive.w(16)),
      child: Container(
        padding: EdgeInsets.all(Responsive.w(14)),
        decoration: BoxDecoration(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(color: r.anaRenk.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.military_tech_rounded, color: r.anaRenk, size: Responsive.w(22)),
                    SizedBox(width: Responsive.w(8)),
                    Text(provider.mevcutUnvan, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(15))),
                  ],
                ),
                Text("%${(provider.seviyeIlerleme * 100).toStringAsFixed(0)}", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
              ],
            ),
            SizedBox(height: Responsive.h(12)),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: provider.seviyeIlerleme,
                backgroundColor: r.arkaPlanRengi,
                valueColor: AlwaysStoppedAnimation<Color>(r.anaRenk),
                minHeight: Responsive.h(8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: _sikKutuDecoration(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(provider.ekranTarihi.split(',')[0], style: TextStyle(fontSize: Responsive.sp(18), fontWeight: FontWeight.bold, color: r.yaziRengi)),
              Text(provider.ekranTarihi.contains(',') ? provider.ekranTarihi.split(',')[1].trim() : "", style: TextStyle(fontSize: Responsive.sp(13), color: r.yaziRengi.withOpacity(0.7))),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(8)),
            decoration: BoxDecoration(color: r.anaRenk.withOpacity(0.15), borderRadius: BorderRadius.circular(Responsive.w(20))),
            child: Row(children: [Icon(Icons.local_fire_department, color: r.anaRenk, size: Responsive.w(24)), SizedBox(width: Responsive.w(4)), Text("${provider.streakCount}", style: TextStyle(fontSize: Responsive.sp(20), fontWeight: FontWeight.bold, color: r.yaziRengi))]),
          ),
        ],
      ),
    );
  }

  Widget _buildMainClock(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    return Container(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(24)),
      decoration: _sikKutuDecoration(context),
      child: Column(
        children: [
          Text(provider.aktifVakit.toUpperCase(), style: TextStyle(fontSize: Responsive.sp(24), letterSpacing: 5, color: r.anaRenk, fontWeight: FontWeight.w900)),
          Text(DateFormat("HH:mm").format(DateTime.now()), style: TextStyle(fontSize: Responsive.sp(64), fontWeight: FontWeight.bold, color: r.yaziRengi, letterSpacing: -2, height: 1.0)),
          SizedBox(height: Responsive.h(8)),
          Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(6)),
            decoration: BoxDecoration(color: r.yaziRengi.withOpacity(0.08), borderRadius: BorderRadius.circular(Responsive.w(15))),
            child: Text("Kalan Süre: ${provider.kalanSure}", style: TextStyle(fontSize: Responsive.sp(15), fontWeight: FontWeight.bold, color: r.yaziRengi)),
          ),
        ],
      ),
    );
  }

  Widget _buildVakitGrid(BuildContext context, NamazProvider provider) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
      decoration: _sikKutuDecoration(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _vakitKutusu(context, "Sabah", Icons.wb_twilight, provider.vakitler?["Sabah"] ?? "", provider),
          _vakitKutusu(context, "Öğle", Icons.wb_sunny, provider.vakitler?["Öğle"] ?? "", provider),
          _vakitKutusu(context, "İkindi", Icons.wb_twilight, provider.vakitler?["İkindi"] ?? "", provider),
          _vakitKutusu(context, "Akşam", Icons.bedtime, provider.vakitler?["Akşam"] ?? "", provider),
          _vakitKutusu(context, "Yatsı", Icons.nights_stay, provider.vakitler?["Yatsı"] ?? "", provider),
        ],
      ),
    );
  }

  Widget _buildDailyQuests(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    final gosterilecekGorevler = provider.gorevler.where((g) => g.tip.toString().contains('gunluk')).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("GÜNÜN GÖREVLERİ", style: TextStyle(color: r.yaziRengi.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: Responsive.sp(14), letterSpacing: 1.2)),
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GorevlerSayfasi())),
              child: Text("Tümünü Gör >", style: TextStyle(color: r.anaRenk, fontSize: Responsive.sp(12), fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(10)),
        SizedBox(
          height: Responsive.h(100),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: gosterilecekGorevler.length,
            itemBuilder: (context, index) {
              final gorev = gosterilecekGorevler[index];
              return Container(
                width: Responsive.w(150),
                margin: EdgeInsets.only(right: Responsive.w(12)),
                padding: EdgeInsets.all(Responsive.w(12)),
                decoration: BoxDecoration(
                  color: r.kartRengi,
                  borderRadius: BorderRadius.circular(Responsive.w(16)),
                  border: Border.all(color: gorev.tamamlandiMi ? r.aktifYesil.withOpacity(0.5) : r.anaRenk.withOpacity(0.1), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Icon(gorev.odulAlindiMi ? Icons.check_circle_rounded : (gorev.tamamlandiMi ? Icons.stars_rounded : Icons.track_changes_rounded), color: gorev.tamamlandiMi ? r.aktifYesil : r.anaRenk, size: Responsive.w(20)),
                        if (gorev.tamamlandiMi && !gorev.odulAlindiMi)
                          GestureDetector(
                            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const GorevlerSayfasi())),
                            child: Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: r.anaRenk, borderRadius: BorderRadius.circular(4)), child: Text("AL", style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold))),
                          )
                        else
                          Text("+${gorev.xpOdulu} XP", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(11))),
                      ],
                    ),
                    Text(gorev.baslik, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(13))),
                    ClipRRect(borderRadius: BorderRadius.circular(10), child: LinearProgressIndicator(value: gorev.ilerleme, backgroundColor: r.arkaPlanRengi, valueColor: AlwaysStoppedAnimation<Color>(gorev.tamamlandiMi ? r.aktifYesil : r.anaRenk), minHeight: Responsive.h(4))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPrayerButton(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    bool isDone = provider.kildiMi[provider.aktifVakit] ?? false;
    return GestureDetector(
      onTap: () => provider.vaktiKildimIsaretle(provider.aktifVakit, !isDone),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 300),
        height: Responsive.h(80),
        decoration: BoxDecoration(color: isDone ? r.aktifYesil : r.kartRengi, borderRadius: BorderRadius.circular(Responsive.w(20)), border: isDone ? null : Border.all(color: r.anaRenk.withOpacity(0.3), width: 2)),
        child: Center(child: Text(isDone ? "ALLAH KABUL ETSİN!" : "VAKTİ KILDIM", style: TextStyle(fontSize: Responsive.sp(16), fontWeight: FontWeight.bold, color: isDone ? Colors.white : r.yaziRengi))),
      ),
    );
  }

  // --- TEMEL TASARIM VE DİĞER FONKSİYONLAR ---

  BoxDecoration _sikKutuDecoration(BuildContext context) {
    return BoxDecoration(color: context.renkler.kartRengi, borderRadius: BorderRadius.circular(Responsive.w(20)), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: Offset(0, 4))]);
  }

  Widget _vakitKutusu(BuildContext context, String ad, IconData ikon, String saat, NamazProvider provider) {
    final r = context.renkler;
    bool suan = provider.aktifVakit == ad;
    bool kildi = provider.kildiMi[ad] ?? false;
    return Column(
      children: [
        Icon(ikon, color: kildi ? r.aktifYesil : (suan ? r.anaRenk : r.pasifRenk), size: Responsive.w(24)),
        SizedBox(height: 4),
        Text(saat.split(' ')[0], style: TextStyle(color: r.yaziRengi, fontWeight: suan ? FontWeight.bold : FontWeight.normal, fontSize: Responsive.sp(12))),
        Text(ad, style: TextStyle(color: suan ? r.anaRenk : r.pasifRenk, fontSize: Responsive.sp(10))),
      ],
    );
  }

  void _unvanlariGoster(BuildContext context, NamazProvider provider, AppThemeColors r) {
    showModalBottomSheet(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Container(
        padding: EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text("RÜTBELER", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: 20)),
            SizedBox(height: 20),
            Text("Mevcut Rütben: ${provider.mevcutUnvan}", style: TextStyle(color: r.yaziRengi)),
            // Buraya rütbe listesi ListView eklenebilir
          ],
        ),
      ),
    );
  }
}