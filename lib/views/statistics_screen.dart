import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../providers/theme_provider.dart';

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
          "Performans Analizi",
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
      body: provider.isLoading
          ? Center(
              child: CircularProgressIndicator(color: r.anaRenk),
            )
          : RefreshIndicator(
              color: r.anaRenk,
              backgroundColor: r.kartRengi,
              onRefresh: provider.istatistikleriYukle,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(Responsive.w(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOzetKartlari(context, provider),
                    SizedBox(height: Responsive.h(24)),
                    Text(
                      "Haftalık Performans (Pzt - Paz)",
                      style: TextStyle(
                        fontSize: Responsive.sp(16),
                        fontWeight: FontWeight.bold,
                        color: r.yaziRengi,
                      ),
                    ),
                    SizedBox(height: Responsive.h(12)),
                    _buildCizgiGrafigi(context, provider),
                    SizedBox(height: Responsive.h(24)),
                    _buildMotiveEdiciKart(context),
                    SizedBox(height: Responsive.h(40)),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOzetKartlari(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    return Row(
      children: [
        _istatistikKutusu(
          context,
          baslik: "Seri",
          deger: "${provider.streakCount} Gün",
          ikon: Icons.local_fire_department,
          renk: r.anaRenk,
        ),
        SizedBox(width: Responsive.w(12)),
        _istatistikKutusu(
          context,
          baslik: "Toplam Vakit",
          deger: "${provider.toplamTamamlanan}",
          ikon: Icons.check_circle_outline,
          renk: r.aktifYesil,
        ),
      ],
    );
  }

  Widget _istatistikKutusu(
    BuildContext context, {
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
  }) {
    final r = context.renkler;
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(Responsive.w(16)),
        decoration: BoxDecoration(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.all(Responsive.w(8)),
              decoration: BoxDecoration(
                color: renk.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, color: renk, size: Responsive.w(20)),
            ),
            SizedBox(height: Responsive.h(12)),
            Text(
              deger,
              style: TextStyle(
                fontSize: Responsive.sp(20),
                fontWeight: FontWeight.bold,
                color: r.yaziRengi,
              ),
            ),
            SizedBox(height: Responsive.h(4)),
            Text(
              baslik,
              style: TextStyle(
                fontSize: Responsive.sp(13),
                color: r.yaziRengi.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCizgiGrafigi(BuildContext context, NamazProvider provider) {
    final r = context.renkler;
    return Container(
      height: Responsive.h(220),
      padding: EdgeInsets.only(
        right: Responsive.w(16),
        left: Responsive.w(8),
        top: Responsive.h(20),
        bottom: Responsive.h(8),
      ),
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
      child: LineChart(
        LineChartData(
          gridData: const FlGridData(show: false),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: Responsive.h(24),
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < provider.gunIsimleri.length) {
                    return Padding(
                      padding: EdgeInsets.only(top: Responsive.h(6)),
                      child: Text(
                        provider.gunIsimleri[index],
                        style: TextStyle(
                          color: r.yaziRengi.withOpacity(0.5),
                          fontSize: Responsive.sp(10),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text('Gün');
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: Responsive.w(24),
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: r.yaziRengi.withOpacity(0.5),
                    fontSize: Responsive.sp(10),
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minX: 0,
          maxX: 6,
          minY: 0,
          maxY: 5,
          lineBarsData: [
            LineChartBarData(
              spots: provider.grafikNoktalari.isNotEmpty
                  ? provider.grafikNoktalari
                  : List.generate(7, (index) => FlSpot(index.toDouble(), 0)),
              isCurved: true,
              color: r.anaRenk,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    r.anaRenk.withOpacity(0.3),
                    r.anaRenk.withOpacity(0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMotiveEdiciKart(BuildContext context) {
    final r = context.renkler;
    final tema = context.watch<ThemeProvider>().aktifTema;
    final motiveBg = tema.brightness == Brightness.dark
        ? r.aktifYesil.withOpacity(0.15)
        : const Color(0xFFE8F5E9);

    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: motiveBg,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: r.aktifYesil.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.w(10)),
            decoration: BoxDecoration(
              color: r.kartRengi,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.emoji_events,
              color: r.aktifYesil,
              size: Responsive.w(24),
            ),
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Harika Gidiyorsun!",
                  style: TextStyle(
                    fontSize: Responsive.sp(14),
                    fontWeight: FontWeight.bold,
                    color: r.aktifYesil,
                  ),
                ),
                SizedBox(height: Responsive.h(4)),
                Text(
                  "İstikrarını koruduğun her gün, hedefine bir adım daha yaklaşıyorsun.",
                  style: TextStyle(
                    fontSize: Responsive.sp(12),
                    color: r.yaziRengi.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
