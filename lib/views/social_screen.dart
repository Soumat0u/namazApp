import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../services/seviye_servisi.dart';
import 'package:intl/intl.dart';

class SosyalSayfasi extends StatefulWidget {
  const SosyalSayfasi({super.key});

  @override
  State<SosyalSayfasi> createState() => _SosyalSayfasiState();
}

class _SosyalSayfasiState extends State<SosyalSayfasi> {
  final TextEditingController _duaController = TextEditingController();

  @override
  void dispose() {
    _duaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final r = context.renkler;

    // 🔥 BUGÜNKÜ XP HESAPLAMA (PRATİK YÖNTEM)
    int bugunNamazXp = provider.kildiMi.values.where((v) => v).length * SeviyeServisi.namazXp;
    if (provider.kildiMi.values.every((v) => v)) bugunNamazXp += SeviyeServisi.tamGunBonusu;
    
    final bugunStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    int bugunZikirXp = ((provider.zikirGecmisi[bugunStr] ?? 0) / 10).floor();
    int toplamBugunXp = bugunNamazXp + bugunZikirXp;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        title: Text(
          "Manevi Meclis",
          style: TextStyle(
            color: r.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(20),
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Navigasyon barında olduğu için geri tuşunu gizle
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // 1. ÜST GİRİŞ PANELİ (ÖZET BAR)
            _buildOzetBar(context, provider, r, toplamBugunXp),
            
            // 2. LİDERLİK TABLOSU ÖN İZLEME
            _buildSectionHeader(
              title: "İstikamet Rehberi", 
              buttonText: "Tümünü Gör",
              onSeeAll: () => _showFullLeaderboard(context, r, provider)
            ),
            _buildIstikametPreview(context, r, provider),

            const SizedBox(height: 10),

            // 3. DUA MECLİSİ ÖN İZLEME
            _buildSectionHeader(
              title: "Dua Meclisi", 
              buttonText: "Dua Duvarına Git",
              onSeeAll: () => _showDuaDuvari(context, r)
            ),
            _buildDuaPreview(context, r),
            
            const SizedBox(height: 20),

            // 4. DUA EKLEME FORMU
            _buildDuaEklemeFormu(r),

            const SizedBox(height: 40), // Sayfa altı boşluğu
          ],
        ),
      ),
    );
  }

  // --- SEKSİYON BAŞLIĞI (ORTAK) ---
  Widget _buildSectionHeader({required String title, required String buttonText, required VoidCallback onSeeAll}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: Responsive.sp(17),
              fontWeight: FontWeight.w900,
              color: Colors.black87,
            ),
          ),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(4)),
              backgroundColor: context.renkler.anaRenk.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              buttonText,
              style: TextStyle(fontWeight: FontWeight.w800, color: context.renkler.anaRenk, fontSize: Responsive.sp(12)),
            ),
          ),
        ],
      ),
    );
  }

  // --- ÖZET BAR (GİRİŞ PANELİ) ---
  Widget _buildOzetBar(BuildContext context, NamazProvider provider, AppThemeColors r, int bugunXp) {
    String unvan = provider.mevcutUnvan;
    String basHarf = unvan.isNotEmpty ? unvan[0] : "T";

    return Container(
      margin: EdgeInsets.all(Responsive.w(16)),
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Sol: Unvan Rozeti
          Container(
            width: Responsive.w(45),
            height: Responsive.w(45),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [r.anaRenk, r.anaRenk.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              basHarf,
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: Responsive.sp(20)),
            ),
          ),
          SizedBox(width: Responsive.w(12)),
          
          // Orta: Unvan & Progress
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  unvan.toUpperCase(),
                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(14), letterSpacing: 1),
                ),
                SizedBox(height: Responsive.h(6)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: provider.seviyeIlerleme,
                    backgroundColor: r.arkaPlanRengi,
                    valueColor: AlwaysStoppedAnimation<Color>(r.anaRenk),
                    minHeight: Responsive.h(6),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: Responsive.w(12)),

          // Sağ: Bugün Rozeti
          Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(6)),
            decoration: BoxDecoration(
              color: r.anaRenk.withOpacity(0.1),
              borderRadius: BorderRadius.circular(Responsive.w(12)),
            ),
            child: Column(
              children: [
                Text("BUGÜN", style: TextStyle(color: r.anaRenk.withOpacity(0.6), fontSize: Responsive.sp(8), fontWeight: FontWeight.bold)),
                Text("+$bugunXp XP", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(12))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- 1. İSTİKAMET REHBERİ (LİDERLİK) ---
  Widget _buildIstikametPreview(BuildContext context, AppThemeColors r, NamazProvider provider) {
    return Column(
      children: List.generate(5, (index) => _buildLeaderboardItem(r, index)),
    );
  }

  void _showFullLeaderboard(BuildContext context, AppThemeColors r, NamazProvider provider) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: r.arkaPlanRengi,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              _buildBottomSheetHandle(r),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Hakk Yolu Sıralaması", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(18), color: r.yaziRengi)),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                  itemCount: 50,
                  itemBuilder: (context, index) => _buildLeaderboardItem(r, index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLeaderboardItem(AppThemeColors r, int index) {
    bool constitutesTopThree = index < 3;
    Color? bgColor = constitutesTopThree 
        ? (index == 0 ? const Color(0xFFFFD700).withOpacity(0.1) : (index == 1 ? const Color(0xFFC0C0C0).withOpacity(0.1) : (index == 2 ? const Color(0xFFCD7F32).withOpacity(0.1) : null))) 
        : null;
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(5)),
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(
        color: bgColor ?? r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: constitutesTopThree ? (index == 0 ? const Color(0xFFFFD700) : (index == 1 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32))).withOpacity(0.3) : r.pasifRenk.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: Responsive.w(25),
            child: Text(
              "${index + 1}",
              style: TextStyle(fontWeight: FontWeight.w900, color: constitutesTopThree ? (index == 0 ? const Color(0xFFD4AF37) : r.yaziRengi) : r.pasifRenk, fontSize: Responsive.sp(14)),
            ),
          ),
          CircleAvatar(
            radius: Responsive.w(16),
            backgroundColor: r.pasifRenk.withOpacity(0.2),
            child: Icon(Icons.person, size: Responsive.w(18), color: r.yaziRengi.withOpacity(0.5)),
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(index == 2 ? "Sen" : "Kullanıcı #${index + 101}", style: TextStyle(fontWeight: FontWeight.bold, color: index == 2 ? r.anaRenk : r.yaziRengi, fontSize: Responsive.sp(14))),
                Text(SeviyeServisi.unvanGetir(50000 - (index * 4000)), style: TextStyle(color: r.yaziRengi.withOpacity(0.5), fontSize: Responsive.sp(11))),
              ],
            ),
          ),
          Text("${50000 - (index * 4000)} XP", style: TextStyle(fontWeight: FontWeight.w900, color: r.yaziRengi, fontSize: Responsive.sp(13))),
        ],
      ),
    );
  }

  // --- 2. DUA MECLİSİ ---
  Widget _buildDuaPreview(BuildContext context, AppThemeColors r) {
    return Column(
      children: List.generate(5, (index) => _buildDuaItem(context, r, index)),
    );
  }

  void _showDuaDuvari(BuildContext context, AppThemeColors r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.6,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: r.arkaPlanRengi,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            children: [
              _buildBottomSheetHandle(r),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text("Dua Duvarı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(20), color: r.anaRenk)),
              ),
              Expanded(
                child: GridView.builder(
                  controller: scrollController,
                  padding: EdgeInsets.all(Responsive.w(12)),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 1.6, // Taşmayı önlemek ve daha ferah bir alan için oran optimize edildi
                    crossAxisSpacing: Responsive.w(10),
                    mainAxisSpacing: Responsive.h(10),
                  ),
                  itemCount: 50,
                  itemBuilder: (context, index) {
                    final dualar = [
                      {"isim": "Ömer F.", "dua": "Sınava girecek tüm kardeşlerimize Allah zihin açıklığı versin, emeklerini zayi etmesin inşaAllah."},
                      {"isim": "Meryem A.", "dua": "Hasta olan annem için şifa dualarınızı bekliyorum. Rabbim Şâfî ismiyle tecelli eylesin."},
                      {"isim": "Salih B.", "dua": "Hayırlı bir iş kapısı için dualarınıza talibim. Rabbim rızkımızı bol ve helal eylesin."},
                      {"isim": "Zeynep K.", "dua": "Ailemiz ve sevdiklerimiz için huzur dolu bir ömür diliyorum. Rabbim birliğimizi bozmasın."},
                      {"isim": "Ahmet T.", "dua": "Borcu olan kardeşlerimize ödeme kolaylığı, dertli olanlara deva diliyorum. Âmîn."},
                    ];
                    final mockDua = dualar[index % dualar.length];
                    return _DuaGridCard(duaData: mockDua, r: r);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDuaItem(BuildContext context, AppThemeColors r, int index) {
    final dualar = [
      {"isim": "Ömer F.", "dua": "Sınava girecek tüm kardeşlerimize Allah zihin açıklığı versin, emeklerini zayi etmesin inşaAllah."},
      {"isim": "Meryem A.", "dua": "Hasta olan annem için şifa dualarınızı bekliyorum. Rabbim Şâfî ismiyle tecelli eylesin."},
      {"isim": "Salih B.", "dua": "Hayırlı bir iş kapısı için dualarınıza talibim. Rabbim rızkımızı bol ve helal eylesin."},
      {"isim": "Zeynep K.", "dua": "Ailemiz ve sevdiklerimiz için huzur dolu bir ömür diliyorum. Rabbim birliğimizi bozmasın."},
      {"isim": "Ahmet T.", "dua": "Borcu olan kardeşlerimize ödeme kolaylığı, dertli olanlara deva diliyorum. Âmîn."},
    ];
    final mockDua = dualar[index % dualar.length];

    return Card(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
      color: r.kartRengi,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(20)), side: BorderSide(color: r.pasifRenk.withOpacity(0.1))),
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 12, backgroundColor: r.anaRenk.withOpacity(0.1), child: Icon(Icons.person, size: 14, color: r.anaRenk)),
                SizedBox(width: 8),
                Text(mockDua["isim"]!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(13), color: r.yaziRengi)),
                const Spacer(),
                Text("${(index + 1) * 7} dk önce", style: TextStyle(color: r.yaziRengi.withOpacity(0.4), fontSize: Responsive.sp(10))),
              ],
            ),
            SizedBox(height: Responsive.h(12)),
            Text(
              mockDua["dua"]!,
              style: TextStyle(color: r.yaziRengi.withOpacity(0.8), fontSize: Responsive.sp(14), height: 1.5, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: Responsive.h(16)),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dua meclisine katıldınız. Amîn!"), duration: Duration(seconds: 1)));
                },
                icon: const Icon(Icons.favorite_rounded, size: 16, color: Colors.white),
                label: const Text("Amîn", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: r.anaRenk,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. DUA EKLEME FORMU ---
  Widget _buildDuaEklemeFormu(AppThemeColors r) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(color: r.anaRenk.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.edit_note_rounded, color: r.anaRenk, size: 24),
              const SizedBox(width: 8),
              Text(
                "Dua Talebi Oluştur",
                style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(15)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _duaController,
            maxLines: 3,
            style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(14)),
            decoration: InputDecoration(
              hintText: "Duanızı buraya yazın...",
              hintStyle: TextStyle(color: r.yaziRengi.withOpacity(0.3)),
              filled: true,
              fillColor: r.arkaPlanRengi,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(45),
            child: ElevatedButton(
              onPressed: () {
                if (_duaController.text.isNotEmpty) {
                  _duaController.clear();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Duanız meclise iletildi. Allah kabul etsin!")));
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: r.anaRenk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: const Text("Duanı Paylaş", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomSheetHandle(AppThemeColors r) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      height: 4,
      width: 40,
      decoration: BoxDecoration(
        color: r.pasifRenk.withOpacity(0.3),
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }
}

class _DuaGridCard extends StatelessWidget {
  final Map<String, String> duaData;
  final AppThemeColors r;
  final bool isFullView;

  const _DuaGridCard({required this.duaData, required this.r, this.isFullView = false});

  void _showDuaOdakModu(BuildContext context) {
    if (isFullView) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dua Detay",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
            child: Material(
              color: Colors.transparent,
              child: _DuaGridCard(duaData: duaData, r: r, isFullView: true),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1, child: child));
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDuaOdakModu(context),
      child: Container(
        padding: EdgeInsets.all(Responsive.w(12)),
        decoration: BoxDecoration(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(15)),
          border: Border.all(color: r.anaRenk.withOpacity(isFullView ? 0.3 : 0.1)),
          boxShadow: isFullView ? [BoxShadow(color: r.anaRenk.withOpacity(0.2), blurRadius: 20)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: isFullView ? 12 : 8, backgroundColor: r.anaRenk.withOpacity(0.1), child: Icon(Icons.person, size: isFullView ? 14 : 10, color: r.anaRenk)),
                const SizedBox(width: 6),
                Expanded(child: Text(duaData["isim"]!, style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(isFullView ? 14 : 10), color: r.yaziRengi), overflow: TextOverflow.ellipsis)),
                if (isFullView) 
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, size: 20, color: r.yaziRengi.withOpacity(0.4))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "\"${duaData["dua"]}\"",
              maxLines: isFullView ? null : 2,
              overflow: isFullView ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                color: r.yaziRengi.withOpacity(0.8),
                fontSize: Responsive.sp(isFullView ? 16 : 11),
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isFullView) ...[
                  Text("Allah kabul etsin", style: TextStyle(color: r.anaRenk.withOpacity(0.6), fontSize: Responsive.sp(12), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                ],
                Icon(Icons.favorite_rounded, size: isFullView ? 20 : 14, color: r.anaRenk.withOpacity(0.7)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
