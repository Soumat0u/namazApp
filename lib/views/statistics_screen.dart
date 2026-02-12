import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:intl/intl.dart';

// --- RENK PALETİ ---
const Color kArkaPlanRengi = Color(0xFFFFFDF5);
const Color kKartRengi = Color(0xFFFFFFFF);
const Color kAnaRenk = Color(0xFFE67E22);
const Color kYaziRengi = Color(0xFF3E2723);
const Color kAktifYesil = Color(0xFF2E7D32);

class IstatistikSayfasi extends StatefulWidget {
  const IstatistikSayfasi({super.key});

  @override
  State<IstatistikSayfasi> createState() => _IstatistikSayfasiState();
}

class _IstatistikSayfasiState extends State<IstatistikSayfasi> with RouteAware {
  int _streakCount = 0;
  int _toplamTamamlanan = 0;
  bool _isLoading = true;

  List<FlSpot> _grafikNoktalari = [];
  List<String> _gunIsimleri = [];

  @override
  void initState() {
    super.initState();
    _verileriYukle(); // Sayfa ilk oluşturulduğunda verileri çek
  }

  // Verileri yükleyen ve arayüzü güncelleyen ana fonksiyon
  Future<void> _verileriYukle() async {
    final prefs = await SharedPreferences.getInstance();

    // Geçmiş veriyi çek ("history_stats" anahtarından)
    String? historyJson = prefs.getString('history_stats');
    Map<String, dynamic> history = historyJson != null
        ? json.decode(historyJson)
        : {};

    List<FlSpot> tempSpots = [];
    List<String> tempLabels = [];
    DateTime bugun = DateTime.now();

    // Haftanın başlangıcını Pazartesi yapacak şekilde 7 günlük döngü
    int pztUzaklik = bugun.weekday - 1;
    DateTime buHaftaninPazartesisi = bugun.subtract(Duration(days: pztUzaklik));

    for (int i = 0; i < 7; i++) {
      DateTime hedefGun = buHaftaninPazartesisi.add(Duration(days: i));
      String dateKey = DateFormat('yyyy-MM-dd').format(hedefGun);

      int count = history[dateKey] ?? 0;
      tempSpots.add(FlSpot(i.toDouble(), count.toDouble()));
      tempLabels.add(DateFormat('E', 'tr_TR').format(hedefGun));
    }

    if (mounted) {
      setState(() {
        _streakCount = prefs.getInt('streakCount') ?? 0;
        _toplamTamamlanan = prefs.getInt('toplamKilinan') ?? 0;
        _grafikNoktalari = tempSpots;
        _gunIsimleri = tempLabels;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sayfa her build edildiğinde (veya IndexedStack içinde görünür olduğunda)
    // verileri arka planda güncellemek için küçük bir gecikmeyle fonksiyonu çağırıyoruz.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isLoading) {
        _verileriYukle();
      }
    });

    return Scaffold(
      backgroundColor: kArkaPlanRengi,
      appBar: AppBar(
        title: const Text(
          "Performans Analizi",
          style: TextStyle(color: kYaziRengi, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: kAnaRenk))
          : RefreshIndicator(
              color: kAnaRenk,
              backgroundColor: kKartRengi,
              onRefresh: _verileriYukle, // Manuel aşağı çekme
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildOzetKartlari(),
                    const SizedBox(height: 30),
                    const Text(
                      "Haftalık Performans (Pzt - Paz)",
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: kYaziRengi,
                      ),
                    ),
                    const SizedBox(height: 15),
                    _buildCizgiGrafigi(),
                    const SizedBox(height: 30),
                    _buildMotiveEdiciKart(),
                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
    );
  }

  // --- UI Widget Fonksiyonları (Orijinal yapı korunmuştur) ---
  Widget _buildOzetKartlari() {
    return Row(
      children: [
        _istatistikKutusu(
          baslik: "Seri",
          deger: "$_streakCount Gün",
          ikon: Icons.local_fire_department,
          renk: kAnaRenk,
        ),
        const SizedBox(width: 15),
        _istatistikKutusu(
          baslik: "Toplam Vakit",
          deger: "$_toplamTamamlanan",
          ikon: Icons.check_circle_outline,
          renk: kAktifYesil,
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
          color: kKartRengi,
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
                color: kYaziRengi,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              baslik,
              style: TextStyle(
                fontSize: 14,
                color: kYaziRengi.withOpacity(0.6),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCizgiGrafigi() {
    return Container(
      height: 250,
      padding: const EdgeInsets.only(right: 20, left: 10, top: 25, bottom: 10),
      decoration: BoxDecoration(
        color: kKartRengi,
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
                  if (index >= 0 && index < _gunIsimleri.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _gunIsimleri[index],
                        style: TextStyle(
                          color: kYaziRengi.withOpacity(0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    );
                  }
                  return const Text('');
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
                    color: kYaziRengi.withOpacity(0.5),
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
              spots: _grafikNoktalari.isNotEmpty
                  ? _grafikNoktalari
                  : List.generate(7, (index) => FlSpot(index.toDouble(), 0)),
              isCurved: true,
              color: kAnaRenk,
              barWidth: 4,
              isStrokeCapRound: true,
              dotData: const FlDotData(show: true),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    kAnaRenk.withOpacity(0.3),
                    kAnaRenk.withOpacity(0.0),
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
        border: Border.all(color: kAktifYesil.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.emoji_events, color: kAktifYesil, size: 28),
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
                    color: kAktifYesil,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  "İstikrarını koruduğun her gün, hedefine bir adım daha yaklaşıyorsun.",
                  style: TextStyle(
                    fontSize: 14,
                    color: kYaziRengi.withOpacity(0.7),
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
