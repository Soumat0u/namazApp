import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../services/notification_service.dart';

class KazaTakipSayfasi extends StatefulWidget {
  const KazaTakipSayfasi({super.key});

  @override
  State<KazaTakipSayfasi> createState() => _KazaTakipSayfasiState();
}

class _KazaTakipSayfasiState extends State<KazaTakipSayfasi> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  bool _isDateRangeMode = false; 
  
  int _yil = 0;
  int _ay = 0;
  int _hafta = 0;
  int _gun = 0;

  DateTime? _startDate;
  DateTime? _endDate;

  bool _kadinOzelHal = false;
  TimeOfDay _bildirimSaati = const TimeOfDay(hour: 20, minute: 0);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final tema = context.renkler;
    final provider = context.watch<NamazProvider>();

    return Scaffold(
      backgroundColor: tema.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Kaza Planlayıcı",
          style: TextStyle(
            color: tema.yaziRengi,
            fontWeight: FontWeight.w800,
            fontSize: Responsive.sp(20),
            letterSpacing: -0.5,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tema.yaziRengi),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Sekme Tasarımı
            Container(
              margin: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(10)),
              decoration: BoxDecoration(
                color: tema.kartRengi,
                borderRadius: BorderRadius.circular(25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  borderRadius: BorderRadius.circular(25),
                  color: tema.anaRenk,
                  boxShadow: [
                    BoxShadow(
                      color: tema.anaRenk.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ],
                ),
                labelColor: Colors.white,
                unselectedLabelColor: tema.pasifRenk,
                labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(14)),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                tabs: const [
                  Tab(text: "Takibim"),
                  Tab(text: "Hesapla"),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTakipSekmesi(context, provider, tema),
                  _buildHesaplaSekmesi(context, provider, tema),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTakipSekmesi(BuildContext context, NamazProvider provider, AppThemeColors tema) {
    if (provider.toplamKazaBorcu == 0) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(Responsive.w(24)),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.check_circle_rounded, size: Responsive.w(60), color: Colors.green),
            ),
            SizedBox(height: Responsive.h(20)),
            Text(
              "Kaza borcunuz bulunmuyor.",
              style: TextStyle(color: tema.yaziRengi, fontSize: Responsive.sp(16), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: Responsive.h(8)),
            Text(
              "Elhamdülillah, tüm borçlarınızı tamamladınız.",
              style: TextStyle(color: tema.pasifRenk, fontSize: Responsive.sp(13)),
            ),
            SizedBox(height: Responsive.h(32)),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: tema.anaRenk,
                elevation: 0,
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(24), vertical: Responsive.h(12)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => _tabController.animateTo(1),
              icon: const Icon(Icons.calculate_rounded, color: Colors.white),
              label: const Text("Yeni Borç Hesapla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }

    final double genelIlerleme = provider.toplamKazaBorcu > 0 ? provider.toplamKilinanKaza / provider.toplamKazaBorcu : 0.0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: Responsive.w(20),
        right: Responsive.w(20),
        top: Responsive.w(20),
        bottom: Responsive.h(40),
      ),
      child: Column(
        children: [
          // Gradient İlerleme Kartı (Hero)
          Container(
            padding: EdgeInsets.all(Responsive.w(24)),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [tema.anaRenk, tema.anaRenk.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(Responsive.w(24)),
              boxShadow: [
                BoxShadow(
                  color: tema.anaRenk.withOpacity(0.35),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(6)),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          "TOPLAM İLERLEME",
                          style: TextStyle(color: Colors.white, fontSize: Responsive.sp(10), fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                      SizedBox(height: Responsive.h(16)),
                      Text(
                        "${provider.toplamKilinanKaza}",
                        style: TextStyle(color: Colors.white, fontSize: Responsive.sp(32), fontWeight: FontWeight.w900, height: 1),
                      ),
                      Text(
                        "/ ${provider.toplamKazaBorcu} vakit",
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: Responsive.sp(14), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: Responsive.w(80),
                  height: Responsive.w(80),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: genelIlerleme),
                        duration: const Duration(milliseconds: 1500),
                        curve: Curves.easeOutCubic,
                        builder: (context, value, child) {
                          return CircularProgressIndicator(
                            value: value,
                            strokeWidth: 8,
                            backgroundColor: Colors.white.withOpacity(0.2),
                            color: Colors.white,
                            strokeCap: StrokeCap.round,
                          );
                        },
                      ),
                      Center(
                        child: TweenAnimationBuilder<double>(
                          tween: Tween<double>(begin: 0.0, end: genelIlerleme * 100),
                          duration: const Duration(milliseconds: 1500),
                          builder: (context, value, child) {
                            return Text(
                              "%${value.toInt()}",
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: Responsive.sp(16)),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: Responsive.h(24)),

          // 1 Günlük Paket Butonu
          InkWell(
            onTap: () {
              provider.kazaKilGunlukPaket();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("1 günlük kaza namazı eklendi (5 vakit)."),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: Responsive.h(16)),
              decoration: BoxDecoration(
                color: tema.anaRenk.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tema.anaRenk.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.auto_awesome_rounded, color: tema.anaRenk),
                  SizedBox(width: Responsive.w(8)),
                  Text(
                    "1 Günlük Kaza Kıl (+5 Vakit)",
                    style: TextStyle(fontSize: Responsive.sp(15), fontWeight: FontWeight.w800, color: tema.anaRenk),
                  ),
                ],
              ),
            ),
          ),
          
          SizedBox(height: Responsive.h(24)),

          // Vakit Kartları
          ...provider.vakitIsimleri.map((vakit) {
            final borcMap = provider.kazaBorclariMap[vakit] ?? {'toplamBorc': 0, 'kilinmis': 0};
            final toplamBorc = borcMap['toplamBorc'] ?? 0;
            final kilinmis = borcMap['kilinmis'] ?? 0;
            final kalan = toplamBorc - kilinmis;

            return _buildVakitKarti(context, vakit, kilinmis, toplamBorc, kalan, provider, tema);
          }),
          
          SizedBox(height: Responsive.h(32)),
          
          // Sıfırlama Butonu
          TextButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: tema.kartRengi,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  title: Text("Borçları Sıfırla", style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold)),
                  content: Text(
                    "Tüm kaza borç kayıtlarınızı sıfırlamak istediğinize emin misiniz? Bu işlem geri alınamaz.",
                    style: TextStyle(color: tema.yaziRengi.withOpacity(0.7)),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: Text("İptal", style: TextStyle(color: tema.pasifRenk))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        provider.sifirlaKaza();
                        Navigator.pop(context);
                      },
                      child: const Text("Sıfırla", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              );
            },
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.redAccent),
            label: const Text("Tüm Borçları Sıfırla", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildVakitKarti(BuildContext context, String vakit, int kilinmis, int toplamBorc, int kalan, NamazProvider provider, AppThemeColors tema) {
    double progress = toplamBorc > 0 ? kilinmis / toplamBorc : 0.0;
    
    // Vakitlere özel ikonlar (İsteğe bağlı zenginleştirme)
    IconData vakitIkonu = Icons.wb_sunny_rounded;
    if (vakit == "Sabah") vakitIkonu = Icons.wb_twilight_rounded;
    if (vakit == "Akşam" || vakit == "Yatsı") vakitIkonu = Icons.nights_stay_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(16)),
      padding: EdgeInsets.all(Responsive.w(20)),
      decoration: BoxDecoration(
        color: tema.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(8)),
                decoration: BoxDecoration(
                  color: tema.anaRenk.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(vakitIkonu, color: tema.anaRenk, size: Responsive.w(20)),
              ),
              SizedBox(width: Responsive.w(12)),
              Text(
                vakit,
                style: TextStyle(color: tema.yaziRengi, fontSize: Responsive.sp(16), fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "$kilinmis / $toplamBorc",
                    style: TextStyle(color: tema.yaziRengi, fontSize: Responsive.sp(14), fontWeight: FontWeight.bold),
                  ),
                  Text(
                    kalan > 0 ? "$kalan Kaldı" : "Tamamlandı",
                    style: TextStyle(color: kalan > 0 ? tema.pasifRenk : Colors.green, fontSize: Responsive.sp(10), fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: Responsive.h(16)),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0.0, end: progress),
              duration: const Duration(milliseconds: 1000),
              curve: Curves.easeOutCubic,
              builder: (context, value, child) {
                return LinearProgressIndicator(
                  value: value,
                  minHeight: 8,
                  backgroundColor: tema.arkaPlanRengi,
                  valueColor: AlwaysStoppedAnimation<Color>(kalan > 0 ? tema.anaRenk : Colors.green),
                );
              },
            ),
          ),
          SizedBox(height: Responsive.h(16)),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: tema.anaRenk,
                    side: BorderSide(color: kalan > 0 ? tema.anaRenk.withOpacity(0.5) : tema.pasifRenk.withOpacity(0.2)),
                    padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: kalan > 0 ? () => provider.kazaKil(vakit, adet: 1) : null,
                  child: Text("+1 Vakit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(13))),
                ),
              ),
              SizedBox(width: Responsive.w(12)),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tema.anaRenk,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: tema.pasifRenk.withOpacity(0.2),
                    elevation: 0,
                    padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: kalan > 0 ? () {
                    provider.kazaKil(vakit, adet: kalan >= 5 ? 5 : kalan);
                  } : null,
                  child: Text(kalan >= 5 ? "+5 Vakit" : "+$kalan Vakit", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(13))),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHesaplaSekmesi(BuildContext context, NamazProvider provider, AppThemeColors tema) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.only(
        left: Responsive.w(20),
        right: Responsive.w(20),
        top: Responsive.w(20),
        bottom: Responsive.h(40),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Segmented Control (Modern Mod Seçimi)
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: tema.kartRengi,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isDateRangeMode = false),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                      decoration: BoxDecoration(
                        color: !_isDateRangeMode ? tema.anaRenk.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Süre Bazlı",
                        style: TextStyle(
                          color: !_isDateRangeMode ? tema.anaRenk : tema.pasifRenk,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _isDateRangeMode = true),
                    child: Container(
                      padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
                      decoration: BoxDecoration(
                        color: _isDateRangeMode ? tema.anaRenk.withOpacity(0.12) : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        "Tarih Aralığı",
                        style: TextStyle(
                          color: _isDateRangeMode ? tema.anaRenk : tema.pasifRenk,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: Responsive.h(32)),

          // Giriş Alanları
          if (!_isDateRangeMode)
            _buildSureBazliGiris(tema)
          else
            _buildTarihAraligiGiris(context, tema),
            
          SizedBox(height: Responsive.h(32)),

          // Kadın Özel Hal
          Container(
            decoration: BoxDecoration(
              color: tema.kartRengi,
              borderRadius: BorderRadius.circular(16),
            ),
            child: SwitchListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
              title: Text("Kadın Özel Hal Düşümü", style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold)),
              subtitle: Text("Her ay için ortalama 7 gün düşülür.", style: TextStyle(color: tema.pasifRenk, fontSize: Responsive.sp(12))),
              activeColor: tema.anaRenk,
              value: _kadinOzelHal,
              onChanged: (val) => setState(() => _kadinOzelHal = val),
            ),
          ),
          
          SizedBox(height: Responsive.h(16)),

          // Bildirim Saati
          Container(
            decoration: BoxDecoration(
              color: tema.kartRengi,
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
              title: Text("Günlük Hatırlatma Saati", style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold)),
              subtitle: Text("Kaza namazlarını hatırlat", style: TextStyle(color: tema.pasifRenk, fontSize: Responsive.sp(12))),
              trailing: Container(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(8)),
                decoration: BoxDecoration(
                  color: tema.anaRenk.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _bildirimSaati.format(context),
                  style: TextStyle(color: tema.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(14)),
                ),
              ),
              onTap: () async {
                final time = await showTimePicker(
                  context: context,
                  initialTime: _bildirimSaati,
                );
                if (time != null) {
                  setState(() => _bildirimSaati = time);
                }
              },
            ),
          ),
          
          SizedBox(height: Responsive.h(40)),

          // Hesapla Butonu
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: tema.anaRenk,
              elevation: 0,
              minimumSize: Size(double.infinity, Responsive.h(55)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => _hesaplaVeKaydet(provider),
            child: Text(
              "Hesapla ve Kaydet",
              style: TextStyle(fontSize: Responsive.sp(16), fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
            ),
          ),
          SizedBox(height: Responsive.h(40)),
        ],
      ),
    );
  }

  Widget _buildSureBazliGiris(AppThemeColors tema) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildNumberInput("Yıl", _yil, (v) => setState(() => _yil = v), tema)),
            SizedBox(width: Responsive.w(16)),
            Expanded(child: _buildNumberInput("Ay", _ay, (v) => setState(() => _ay = v), tema)),
          ],
        ),
        SizedBox(height: Responsive.h(16)),
        Row(
          children: [
            Expanded(child: _buildNumberInput("Hafta", _hafta, (v) => setState(() => _hafta = v), tema)),
            SizedBox(width: Responsive.w(16)),
            Expanded(child: _buildNumberInput("Gün", _gun, (v) => setState(() => _gun = v), tema)),
          ],
        ),
      ],
    );
  }

  // Modern Stepper Tasarımı
  Widget _buildNumberInput(String label, int value, Function(int) onChanged, AppThemeColors tema) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
      decoration: BoxDecoration(
        color: tema.kartRengi,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: Column(
        children: [
          Text(label, style: TextStyle(color: tema.pasifRenk, fontSize: Responsive.sp(12), fontWeight: FontWeight.bold)),
          SizedBox(height: Responsive.h(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              GestureDetector(
                onTap: value > 0 ? () => onChanged(value - 1) : null,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: value > 0 ? tema.arkaPlanRengi : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.remove, color: value > 0 ? tema.yaziRengi : tema.pasifRenk.withOpacity(0.3), size: 18),
                ),
              ),
              Text(
                "$value",
                style: TextStyle(color: tema.yaziRengi, fontSize: Responsive.sp(20), fontWeight: FontWeight.w900),
              ),
              GestureDetector(
                onTap: () => onChanged(value + 1),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: tema.arkaPlanRengi,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add, color: tema.yaziRengi, size: 18),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildTarihAraligiGiris(BuildContext context, AppThemeColors tema) {
    final startStr = _startDate != null ? "${_startDate!.day}/${_startDate!.month}/${_startDate!.year}" : "Seçiniz";
    final endStr = _endDate != null ? "${_endDate!.day}/${_endDate!.month}/${_endDate!.year}" : "Seçiniz";

    return InkWell(
      onTap: () async {
        final DateTimeRange? picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(1950),
          lastDate: DateTime.now(),
          initialDateRange: _startDate != null && _endDate != null 
              ? DateTimeRange(start: _startDate!, end: _endDate!) 
              : null,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: tema.anaRenk,
                  onPrimary: Colors.white,
                  onSurface: tema.yaziRengi,
                ),
              ),
              child: child!,
            );
          },
        );
        if (picked != null) {
          setState(() {
            _startDate = picked.start;
            _endDate = picked.end;
          });
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: EdgeInsets.all(Responsive.w(20)),
        decoration: BoxDecoration(
          color: tema.kartRengi,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(Responsive.w(10)),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.date_range_rounded, color: Colors.orange),
            ),
            SizedBox(width: Responsive.w(16)),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Başlangıç:", style: TextStyle(color: tema.pasifRenk, fontSize: Responsive.sp(12))),
                      Text(startStr, style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  SizedBox(height: Responsive.h(8)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Bitiş:", style: TextStyle(color: tema.pasifRenk, fontSize: Responsive.sp(12))),
                      Text(endStr, style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: Responsive.w(12)),
            Icon(Icons.chevron_right_rounded, color: tema.pasifRenk),
          ],
        ),
      ),
    );
  }

  void _hesaplaVeKaydet(NamazProvider provider) {
    int toplamGun = 0;

    if (!_isDateRangeMode) {
      toplamGun = (_yil * 365) + (_ay * 30) + (_hafta * 7) + _gun;
    } else {
      if (_startDate == null || _endDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen tarih aralığı seçiniz.")));
        return;
      }
      toplamGun = _endDate!.difference(_startDate!).inDays;
    }

    if (toplamGun <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Geçerli bir süre giriniz.")));
      return;
    }

    if (_kadinOzelHal) {
      double toplamAy = toplamGun / 30.0;
      int dusulecekGun = (toplamAy * 7).toInt();
      toplamGun -= dusulecekGun;
      if (toplamGun < 0) toplamGun = 0;
    }

    Map<String, int> yeniBorclar = {
      "Sabah": toplamGun,
      "Öğle": toplamGun,
      "İkindi": toplamGun,
      "Akşam": toplamGun,
      "Yatsı": toplamGun,
    };

    provider.kazaBorcunuAyarla(yeniBorclar);
    
    final NotificationService notificationService = NotificationService();
    notificationService.scheduleKazaHatirlatma(hour: _bildirimSaati.hour, minute: _bildirimSaati.minute);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text("Borçlarınız hesaplandı ve kaydedildi. (Her vakit için $toplamGun gün)"),
        backgroundColor: Colors.green,
      ),
    );

    _tabController.animateTo(0);
  }
}