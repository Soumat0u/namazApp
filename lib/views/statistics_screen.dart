import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/namaz_provider.dart';

class IstatistikSayfasi extends StatelessWidget {
  const IstatistikSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NamazProvider>();

    return Scaffold(
      backgroundColor: AppColors.arkaPlanRengi,
      appBar: AppBar(
        title: const Text(
          "Performans Analizi",
          style: TextStyle(
            color: AppColors.yaziRengi,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: provider.isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.anaRenk),
            )
          : RefreshIndicator(
              color: AppColors.anaRenk,
              backgroundColor: AppColors.kartRengi,
              onRefresh: provider.istatistikleriYukle,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOzetKartlari(provider),
                    const SizedBox(height: 30),
                    const Text(
                      "Haftalık Performans (Pzt - Paz)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.yaziRengi,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildCizgiGrafigi(provider),
                    const SizedBox(height: 30),
                    _buildMotiveEdiciKart(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildOzetKartlari(NamazProvider provider) {
    return Row(
      children: [
        _istatistikKutusu(
          baslik: "Seri",
          deger: "${provider.streakCount} Gün",
          ikon: Icons.local_fire_department,
          renk: AppColors.anaRenk,
        ),
        const SizedBox(width: 15),
        _istatistikKutusu(
          baslik: "Toplam Vakit",
          deger: "${provider.toplamTamamlanan}",
          ikon: Icons.check_circle_outline,
          renk: AppColors.aktifYesil,
        ),
      ],
    );
  }

  Widget _istatistikKutusu({
    required String baslik,
    required String deger,
    required IconData ikon,
    required Color renk,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.kartRengi,
          borderRadius: BorderRadius.circular(20),
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
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: renk.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(ikon, color: renk, size: 24),
            ),
            const SizedBox(height: 15),
            Text(
              deger,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.yaziRengi,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              baslik,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.yaziRengi.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCizgiGrafigi(NamazProvider provider) {
    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 20, left: 10, top: 25, bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.kartRengi,
        borderRadius: BorderRadius.circular(25),
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
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  int index = value.toInt();
                  if (index >= 0 && index < provider.gunIsimleri.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        provider.gunIsimleri[index],
                        style: TextStyle(
                          color: AppColors.yaziRengi.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text(
                    'Gün',
                  ); // Skeleton sırasında hata vermemesi için
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: 1,
                reservedSize: 30,
                getTitlesWidget: (value, meta) => Text(
                  value.toInt().toString(),
                  style: TextStyle(
                    color: AppColors.yaziRengi.withOpacity(0.5),
                    fontSize: 12,
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
              color: AppColors.anaRenk,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.anaRenk.withOpacity(0.3),
                    AppColors.anaRenk.withOpacity(0.0),
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

  Widget _buildMotiveEdiciKart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.aktifYesil.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: AppColors.aktifYesil,
              size: 28,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Harika Gidiyorsun!",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.aktifYesil,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "İstikrarını koruduğun her gün, hedefine bir adım daha yaklaşıyorsun.",
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.yaziRengi.withOpacity(0.7),
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
