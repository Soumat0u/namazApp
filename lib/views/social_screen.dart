import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/utils/content_moderation.dart';
import '../providers/namaz_provider.dart';
import '../services/firebase_service.dart';
import '../services/seviye_servisi.dart';
import '../models/user_profile.dart';
import '../models/prayer_post.dart';
import '../models/app_notification.dart';
import 'package:intl/intl.dart';

class SosyalSayfasi extends StatefulWidget {
  const SosyalSayfasi({super.key});

  @override
  State<SosyalSayfasi> createState() => _SosyalSayfasiState();
}

class _SosyalSayfasiState extends State<SosyalSayfasi> {
  final TextEditingController _duaController = TextEditingController();
  final FocusNode _duaFocusNode = FocusNode();
  final FirebaseService _firebaseService = FirebaseService();

  // 🔥 Stream'leri cache'le — her rebuild'de yeniden oluşmasını engelle
  late final Stream<List<UserProfile>> _leaderboardStream;
  late final Stream<List<PrayerPost>> _prayersStream;
  late final Stream<List<UserProfile>> _fullLeaderboardStream;
  late final Stream<List<PrayerPost>> _fullPrayersStream;

  @override
  void initState() {
    super.initState();
    _leaderboardStream = _firebaseService.getLeaderboard(limit: 5);
    _prayersStream = _firebaseService.getPrayers(limit: 5);
    _fullLeaderboardStream = _firebaseService.getLeaderboard(limit: 50);
    _fullPrayersStream = _firebaseService.getPrayers(limit: 50);
  }

  @override
  void dispose() {
    _duaController.dispose();
    _duaFocusNode.dispose();
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
        automaticallyImplyLeading: false,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.person_add_alt_1_rounded, color: r.anaRenk),
            onPressed: () => _showAddFriendModal(context, r, provider),
          ),
          if (provider.currentUid != null)
            _buildNotificationBadge(context, r, provider),
          SizedBox(width: Responsive.w(8)),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
          children: [
            // 1. ÜST GİRİŞ PANELİ (ÖZET BAR)
            _buildOzetBar(context, provider, r, toplamBugunXp),
            // 1.5 ARKADAŞLARIM (Yeni Sekme)
            _buildSectionHeader(
              title: "Arkadaşlarım", 
              icon: Icons.people_alt_rounded,
              buttonText: "Tümünü Gör",
              onSeeAll: () { FocusScope.of(context).unfocus(); _showFriendsModal(context, r, provider); }
            ),
            
            // 2. LİDERLİK TABLOSU ÖN İZLEME
            _buildSectionHeader(
              title: "İstikamet Rehberi", 
              icon: Icons.emoji_events_rounded,
              buttonText: "Tümünü Gör",
              onSeeAll: () { FocusScope.of(context).unfocus(); _showFullLeaderboard(context, r, provider); }
            ),
            _buildIstikametPreview(context, r, provider),

            const SizedBox(height: 10),

            // 3. DUA MECLİSİ ÖN İZLEME
            _buildSectionHeader(
              title: "Dua Meclisi", 
              icon: Icons.volunteer_activism_rounded,
              buttonText: "Dua Duvarına Git",
              onSeeAll: () { FocusScope.of(context).unfocus(); _showDuaDuvari(context, r); }
            ),
            _buildDuaPreview(context, r, provider),
            
            const SizedBox(height: 20),

            // 4. DUA EKLEME FORMU
            _buildDuaEklemeFormu(r, provider),

            const SizedBox(height: 40),
          ],
        ),
      ),
      ),
    );
  }

  // --- SEKSİYON BAŞLIĞI (ORTAK) ---
  Widget _buildSectionHeader({required String title, required String buttonText, required VoidCallback onSeeAll, required IconData icon}) {
    final r = context.renkler;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(20), vertical: Responsive.h(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(6)),
                decoration: BoxDecoration(
                  color: r.anaRenk.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(Responsive.w(8)),
                ),
                child: Icon(icon, color: r.anaRenk, size: Responsive.w(18)),
              ),
              SizedBox(width: Responsive.w(10)),
              Text(
                title,
                style: TextStyle(
                  fontSize: Responsive.sp(17),
                  fontWeight: FontWeight.w900,
                  color: r.yaziRengi,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          TextButton(
            onPressed: onSeeAll,
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(4)),
              backgroundColor: r.anaRenk.withOpacity(0.08),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  buttonText,
                  style: TextStyle(fontWeight: FontWeight.bold, color: r.anaRenk, fontSize: Responsive.sp(11)),
                ),
                SizedBox(width: Responsive.w(4)),
                Icon(Icons.arrow_forward_ios_rounded, size: Responsive.w(10), color: r.anaRenk),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- PROFİL KARTI (GİRİŞ PANELİ) ---
  Widget _buildOzetBar(BuildContext context, NamazProvider provider, AppThemeColors r, int bugunXp) {
    String unvan = provider.mevcutUnvan;
    String username = provider.currentUsername.isNotEmpty ? provider.currentUsername : unvan;
    String basHarf = username.isNotEmpty ? username[0].toUpperCase() : "T";
    
    // Seviye hesaplamaları
    int mevcutXp = provider.toplamXp;
    var anahtarlar = SeviyeServisi.unvanlar.keys.toList()..sort();
    int baslangicXp = 0;
    int hedefXp = 1000;
    String hedefUnvan = "Salik";

    if (mevcutXp >= anahtarlar.last) {
      baslangicXp = anahtarlar.last;
      hedefXp = anahtarlar.last;
      hedefUnvan = "Zirve";
    } else {
      for (int i = 0; i < anahtarlar.length - 1; i++) {
        if (mevcutXp >= anahtarlar[i] && mevcutXp < anahtarlar[i + 1]) {
          baslangicXp = anahtarlar[i];
          hedefXp = anahtarlar[i + 1];
          hedefUnvan = SeviyeServisi.unvanlar[hedefXp]!;
          break;
        }
      }
    }

    return Container(
      margin: EdgeInsets.all(Responsive.w(16)),
      padding: EdgeInsets.all(Responsive.w(20)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [r.kartRengi, r.kartRengi.withOpacity(0.9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Responsive.w(24)),
        border: Border.all(color: r.anaRenk.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: r.anaRenk.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ÜST KISIM: Avatar, İsim, Unvan ve Bugün
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: Responsive.w(60),
                height: Responsive.w(60),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [r.anaRenk, r.anaRenk.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: r.anaRenk.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ],
                ),
                alignment: Alignment.center,
                child: Text(
                  basHarf,
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: Responsive.sp(26)),
                ),
              ),
              SizedBox(width: Responsive.w(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(18)),
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: Responsive.h(4)),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(2)),
                      decoration: BoxDecoration(
                        color: r.anaRenk.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        unvan.toUpperCase(),
                        style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(11), letterSpacing: 1),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(8)),
                decoration: BoxDecoration(
                  color: r.arkaPlanRengi,
                  borderRadius: BorderRadius.circular(Responsive.w(12)),
                  border: Border.all(color: r.anaRenk.withOpacity(0.2)),
                ),
                child: Column(
                  children: [
                     Icon(Icons.local_fire_department_rounded, color: Colors.orange.shade600, size: 20),
                     Text("${provider.streakCount} Gün", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(11))),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: Responsive.h(20)),
          
          // İLERLEME ÇUBUĞU
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("İlerleme", style: TextStyle(color: r.pasifRenk, fontWeight: FontWeight.w600, fontSize: Responsive.sp(12))),
              Text("$mevcutXp / $hedefXp XP", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w800, fontSize: Responsive.sp(12))),
            ],
          ),
          SizedBox(height: Responsive.h(8)),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: provider.seviyeIlerleme,
              backgroundColor: r.arkaPlanRengi,
              valueColor: AlwaysStoppedAnimation<Color>(r.anaRenk),
              minHeight: Responsive.h(8),
            ),
          ),
          SizedBox(height: Responsive.h(8)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(unvan, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
              Row(
                children: [
                  Text("Hedef: ", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
                  Text(hedefUnvan, style: TextStyle(color: r.anaRenk.withOpacity(0.8), fontWeight: FontWeight.w800, fontSize: Responsive.sp(11))),
                ],
              ),
            ],
          ),

          SizedBox(height: Responsive.h(16)),
          Divider(color: r.pasifRenk.withOpacity(0.1)),
          SizedBox(height: Responsive.h(8)),

          // ALT BÖLÜM: Bugün XP & Toplam XP
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text("Bugün Kazanılan", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
                  SizedBox(height: 2),
                  Text("+$bugunXp XP", style: TextStyle(color: Colors.green.shade600, fontWeight: FontWeight.w800, fontSize: Responsive.sp(14))),
                ],
              ),
              Container(width: 1, height: Responsive.h(30), color: r.pasifRenk.withOpacity(0.2)),
              Column(
                children: [
                  Text("Manevi Birikim", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
                  SizedBox(height: 2),
                  Text("$mevcutXp XP", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(14))),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 🔥 1. İSTİKAMET REHBERİ (LİDERLİK) — GERÇEK VERİ
  // ═══════════════════════════════════════════════

  Widget _buildIstikametPreview(BuildContext context, AppThemeColors r, NamazProvider provider) {
    return StreamBuilder<List<UserProfile>>(
      stream: _leaderboardStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(Responsive.w(30)),
            child: Center(child: CircularProgressIndicator(color: r.anaRenk, strokeWidth: 2)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(r, "İstikamet Rehberi", "Henüz meclis üyesi yok.\nSen ilk ol!");
        }

        final users = snapshot.data!;
        return Column(
          children: List.generate(
            users.length,
            (index) => _buildLeaderboardItem(r, index, users[index], provider.currentUid),
          ),
        );
      },
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
                child: StreamBuilder<List<UserProfile>>(
                  stream: _fullLeaderboardStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: r.anaRenk));
                    }
                    final users = snapshot.data!;
                    return ListView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(4)),
                      itemCount: users.length,
                      itemBuilder: (context, index) => _buildLeaderboardItem(r, index, users[index], provider.currentUid),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Widget _buildLeaderboardItem(AppThemeColors r, int index, UserProfile user, String? currentUid) {
    bool isCurrentUser = user.uid == currentUid;
    bool constitutesTopThree = index < 3;
    Color? bgColor = constitutesTopThree 
        ? (index == 0 ? const Color(0xFFFFD700).withOpacity(0.1) : (index == 1 ? const Color(0xFFC0C0C0).withOpacity(0.1) : (index == 2 ? const Color(0xFFCD7F32).withOpacity(0.1) : null))) 
        : null;

    // Mevcut kullanıcıyı vurgula
    if (isCurrentUser && !constitutesTopThree) {
      bgColor = r.anaRenk.withOpacity(0.06);
    }
    
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(5)),
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(
        color: bgColor ?? r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(
          color: isCurrentUser
              ? r.anaRenk.withOpacity(0.4)
              : constitutesTopThree
                  ? (index == 0 ? const Color(0xFFFFD700) : (index == 1 ? const Color(0xFFC0C0C0) : const Color(0xFFCD7F32))).withOpacity(0.3) 
                  : r.pasifRenk.withOpacity(0.1),
          width: isCurrentUser ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: Responsive.w(25),
            child: Text(
              "${index + 1}",
              style: TextStyle(
                fontWeight: FontWeight.w900, 
                color: constitutesTopThree ? (index == 0 ? const Color(0xFFD4AF37) : r.yaziRengi) : r.pasifRenk, 
                fontSize: Responsive.sp(14),
              ),
            ),
          ),
          CircleAvatar(
            radius: Responsive.w(16),
            backgroundColor: isCurrentUser ? r.anaRenk.withOpacity(0.2) : r.pasifRenk.withOpacity(0.2),
            child: Text(
              user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : "?",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isCurrentUser ? r.anaRenk : r.yaziRengi.withOpacity(0.7),
                fontSize: Responsive.sp(13),
              ),
            ),
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isCurrentUser ? "${user.displayName} (Sen)" : user.displayName, 
                        style: TextStyle(fontWeight: FontWeight.bold, color: isCurrentUser ? r.anaRenk : r.yaziRengi, fontSize: Responsive.sp(14)),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isCurrentUser) ...[
                      const SizedBox(width: 4),
                      Icon(Icons.star_rounded, size: 14, color: r.anaRenk),
                    ],
                  ],
                ),
                Text("@${user.username} • ${user.unvan}", style: TextStyle(color: r.yaziRengi.withOpacity(0.5), fontSize: Responsive.sp(11)), overflow: TextOverflow.ellipsis, maxLines: 1),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${user.totalXp} XP", style: TextStyle(fontWeight: FontWeight.w900, color: r.yaziRengi, fontSize: Responsive.sp(13))),
              if (user.streak > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.local_fire_department_rounded, size: 12, color: Colors.orange.shade600),
                    Text("${user.streak}", style: TextStyle(color: Colors.orange.shade600, fontSize: Responsive.sp(10), fontWeight: FontWeight.bold)),
                  ],
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ═══════════════════════════════════════════════
  // 🤲 2. DUA MECLİSİ — GERÇEK VERİ
  // ═══════════════════════════════════════════════

  Widget _buildDuaPreview(BuildContext context, AppThemeColors r, NamazProvider provider) {
    return StreamBuilder<List<PrayerPost>>(
      stream: _prayersStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(Responsive.w(30)),
            child: Center(child: CircularProgressIndicator(color: r.anaRenk, strokeWidth: 2)),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildEmptyState(r, "Dua Meclisi", "Henüz dua paylaşılmamış.\nİlk duayı sen paylaş!");
        }

        final prayers = snapshot.data!;
        return Column(
          children: prayers.map((prayer) => _buildDuaItem(context, r, prayer, provider)).toList(),
        );
      },
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
                child: StreamBuilder<List<PrayerPost>>(
                  stream: _fullPrayersStream,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data!.isEmpty) {
                      return Center(
                        child: Text("Dua duvarı boş", style: TextStyle(color: r.pasifRenk)),
                      );
                    }
                    final prayers = snapshot.data!;
                    final provider = context.read<NamazProvider>();
                    return GridView.builder(
                      controller: scrollController,
                      padding: EdgeInsets.all(Responsive.w(12)),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 1.6,
                        crossAxisSpacing: Responsive.w(10),
                        mainAxisSpacing: Responsive.h(10),
                      ),
                      itemCount: prayers.length,
                      itemBuilder: (context, index) {
                        return _DuaGridCard(
                          prayer: prayers[index], 
                          r: r, 
                          currentUid: provider.currentUid,
                          firebaseService: _firebaseService,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  Widget _buildDuaItem(BuildContext context, AppThemeColors r, PrayerPost prayer, NamazProvider provider) {
    final zamanFarki = _zamanFarkiHesapla(prayer.timestamp);
    final benAminDedimMi = provider.currentUid != null && prayer.aminBy.contains(provider.currentUid);

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
                CircleAvatar(
                  radius: 12, 
                  backgroundColor: r.anaRenk.withOpacity(0.1), 
                  child: Text(
                    prayer.senderName.isNotEmpty ? prayer.senderName[0].toUpperCase() : "?",
                    style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
                const SizedBox(width: 8),
                Text(prayer.senderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(13), color: r.yaziRengi)),
                const Spacer(),
                Text(zamanFarki, style: TextStyle(color: r.yaziRengi.withOpacity(0.4), fontSize: Responsive.sp(10))),
              ],
            ),
            SizedBox(height: Responsive.h(12)),
            Text(
              prayer.text,
              style: TextStyle(color: r.yaziRengi.withOpacity(0.8), fontSize: Responsive.sp(14), height: 1.5, fontStyle: FontStyle.italic),
            ),
            SizedBox(height: Responsive.h(16)),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Amin sayısı
                if (prayer.aminCount > 0)
                  Text(
                    "${prayer.aminCount} kardeşimiz amîn dedi",
                    style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11), fontWeight: FontWeight.w500),
                  ),
                const Spacer(),
                // Amin butonu
                ElevatedButton.icon(
                  onPressed: () async {
                    if (provider.currentUid == null) return;
                    final isAdded = await _firebaseService.toggleAmin(
                      prayerId: prayer.id,
                      userUid: provider.currentUid!,
                    );
                    if (isAdded != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(isAdded ? "Dua meclisine katıldınız. Amîn!" : "Amîn geri alındı."), 
                          duration: const Duration(seconds: 1)
                        ),
                      );
                    }
                  },
                  icon: Icon(
                    benAminDedimMi ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                    size: 16, 
                    color: Colors.white,
                  ),
                  label: Text(
                    benAminDedimMi ? "Amîn ✓" : "Amîn", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: benAminDedimMi ? r.pasifRenk.withOpacity(0.5) : r.anaRenk,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // --- 4. DUA EKLEME FORMU ---
  Widget _buildDuaEklemeFormu(AppThemeColors r, NamazProvider provider) {
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
            focusNode: _duaFocusNode,
            maxLines: 3,
            maxLength: 500,
            style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(14)),
            decoration: InputDecoration(
              hintText: "Duanızı buraya yazın...",
              hintStyle: TextStyle(color: r.yaziRengi.withOpacity(0.3)),
              filled: true,
              fillColor: r.arkaPlanRengi,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(45),
            child: ElevatedButton(
              onPressed: () async {
                final text = _duaController.text.trim();
                
                // İçerik moderasyonu
                final validationError = ContentModeration.metinDogrula(text);
                if (validationError != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(validationError), backgroundColor: r.kirmizi),
                    );
                  }
                  return;
                }

                if (provider.currentUid == null || provider.currentUsername.isEmpty) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Dua paylaşmak için önce profil oluşturmalısınız.")),
                    );
                  }
                  return;
                }

                await _firebaseService.addPrayer(
                  text: text,
                  senderUid: provider.currentUid!,
                  senderName: provider.currentUsername,
                );

                _duaController.clear();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Duanız meclise iletildi. Allah kabul etsin!")),
                  );
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

  // --- YARDIMCI WİDGET'LAR ---

  Widget _buildEmptyState(AppThemeColors r, String title, String message) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(10)),
      padding: EdgeInsets.all(Responsive.w(24)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(color: r.pasifRenk.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(Icons.people_outline_rounded, size: 40, color: r.pasifRenk.withOpacity(0.4)),
          SizedBox(height: Responsive.h(12)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(13), height: 1.5),
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

  // ════════════════════════════════════════
  // 🤝 BİLDİRİMLER VE ARKADAŞLAR MODALLARI
  // ════════════════════════════════════════
  
  Widget _buildNotificationBadge(BuildContext context, AppThemeColors r, NamazProvider provider) {
    return StreamBuilder<List<AppNotification>>(
      stream: FirebaseService().getNotifications(provider.currentUid!),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final unreadCount = snapshot.data!.where((n) => n.status == 'pending').length;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.notifications_rounded, color: r.anaRenk),
              onPressed: () => _showNotificationsModal(context, r, provider, snapshot.data!),
            ),
            if (unreadCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.redAccent,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    unreadCount > 9 ? "9+" : "$unreadCount",
                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  void _showNotificationsModal(BuildContext context, AppThemeColors r, NamazProvider provider, List<AppNotification> notifications) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final pendingNotifs = notifications.where((n) => n.status == 'pending').toList();
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          maxChildSize: 0.9,
          minChildSize: 0.4,
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
                  child: Text("Bildirimler", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(18), color: r.yaziRengi)),
                ),
                if (pendingNotifs.isEmpty)
                  Expanded(child: Center(child: Text("Bekleyen bildiriminiz yok.", style: TextStyle(color: r.pasifRenk))))
                else
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: pendingNotifs.length,
                      itemBuilder: (context, index) {
                        final notif = pendingNotifs[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: r.anaRenk.withOpacity(0.2),
                            child: Icon(Icons.person, color: r.anaRenk),
                          ),
                          title: Text("${notif.fromDisplayName} seni kardeşliğine davet ediyor.", style: TextStyle(color: r.yaziRengi)),
                          subtitle: Text("@${notif.fromUsername}", style: TextStyle(color: r.pasifRenk, fontSize: 12)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.check_circle_rounded, color: Colors.green),
                                onPressed: () {
                                  FirebaseService().respondToFriendRequest(currentUid: provider.currentUid!, targetUid: notif.fromUid, accept: true);
                                  Navigator.pop(context);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                                onPressed: () {
                                  FirebaseService().respondToFriendRequest(currentUid: provider.currentUid!, targetUid: notif.fromUid, accept: false);
                                  Navigator.pop(context);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddFriendModal(BuildContext context, AppThemeColors r, NamazProvider provider) {
    if (provider.currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giriş yapmanız gerekiyor.")));
      return;
    }
    
    final TextEditingController searchController = TextEditingController();
    bool isSearching = false;
    String errorMessage = "";

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: r.arkaPlanRengi,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text("Topluluğa Kardeş Davet Et", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(18), color: r.yaziRengi)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: searchController,
                    autofocus: true,
                    style: TextStyle(color: r.yaziRengi),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      hintText: "Arkadaşının kullanıcı adı...",
                      filled: true,
                      fillColor: r.kartRengi,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                  if (errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(errorMessage, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: r.anaRenk,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: isSearching ? null : () async {
                        if (searchController.text.trim().isEmpty) return;
                        setState(() { isSearching = true; errorMessage = ""; });
                        
                        final err = await FirebaseService().sendFriendRequest(
                          targetUsername: searchController.text.trim(),
                          senderUid: provider.currentUid!,
                          senderUsername: provider.currentUsername,
                          senderDisplayName: provider.currentUsername,
                        );
                        
                        setState(() { isSearching = false; });
                        
                        if (err != null) {
                          setState(() { errorMessage = err; });
                        } else {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Dua isteği gönderildi!")));
                        }
                      },
                      child: isSearching 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("İstek Gönder", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _showFriendsModal(BuildContext context, AppThemeColors r, NamazProvider provider) {
    if (provider.currentUid == null) return;
    
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
                child: Text("Mumin Kardeşlerim", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(18), color: r.yaziRengi)),
              ),
              Expanded(
                child: StreamBuilder<UserProfile?>(
                  stream: FirebaseService().getUserProfile(provider.currentUid!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) return const Center(child: CircularProgressIndicator());
                    
                    final friendsList = snapshot.data!.friends;
                    if (friendsList.isEmpty) return Center(child: Text("Henüz bir kardeşiniz ekli değil.\nDua halkasına arkadaşlarınızı davet edin!", textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk)));

                    return FutureBuilder<List<UserProfile>>(
                      future: FirebaseService().getFriendsProfiles(friendsList),
                      builder: (context, futureSnap) {
                        if (!futureSnap.hasData) return const Center(child: CircularProgressIndicator());
                        
                        final friendProfiles = futureSnap.data!;
                        return ListView.builder(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(4)),
                          itemCount: friendProfiles.length,
                          itemBuilder: (context, index) => _buildLeaderboardItem(r, index, friendProfiles[index], provider.currentUid),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Zaman farkını okunabilir formata çevirir
  String _zamanFarkiHesapla(DateTime zaman) {
    final fark = DateTime.now().difference(zaman);
    if (fark.inMinutes < 1) return 'Az önce';
    if (fark.inMinutes < 60) return '${fark.inMinutes} dk önce';
    if (fark.inHours < 24) return '${fark.inHours} saat önce';
    if (fark.inDays < 7) return '${fark.inDays} gün önce';
    return DateFormat('dd MMM', 'tr_TR').format(zaman);
  }
}

// ═══════════════════════════════════════════════
// DUA GRID KART (Dua Duvarı modal'ında kullanılır)
// ═══════════════════════════════════════════════

class _DuaGridCard extends StatelessWidget {
  final PrayerPost prayer;
  final AppThemeColors r;
  final bool isFullView;
  final String? currentUid;
  final FirebaseService firebaseService;

  const _DuaGridCard({
    required this.prayer, 
    required this.r, 
    this.isFullView = false,
    this.currentUid,
    required this.firebaseService,
  });

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
              child: _DuaGridCard(
                prayer: prayer, 
                r: r, 
                isFullView: true,
                currentUid: currentUid,
                firebaseService: firebaseService,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1, child: child));
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final benAminDedimMi = currentUid != null && prayer.aminBy.contains(currentUid);

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
                CircleAvatar(
                  radius: isFullView ? 12 : 8, 
                  backgroundColor: r.anaRenk.withOpacity(0.1), 
                  child: Text(
                    prayer.senderName.isNotEmpty ? prayer.senderName[0].toUpperCase() : "?",
                    style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: isFullView ? 12 : 8),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(child: Text(prayer.senderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(isFullView ? 14 : 10), color: r.yaziRengi), overflow: TextOverflow.ellipsis)),
                if (isFullView) 
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, size: 20, color: r.yaziRengi.withOpacity(0.4))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "\"${prayer.text}\"",
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (prayer.aminCount > 0)
                  Text(
                    "${prayer.aminCount} Amîn",
                    style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(isFullView ? 12 : 9), fontWeight: FontWeight.w600),
                  ),
                const Spacer(),
                if (isFullView) ...[
                  Text("Allah kabul etsin", style: TextStyle(color: r.anaRenk.withOpacity(0.6), fontSize: Responsive.sp(12), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: () async {
                    if (currentUid == null) return;
                    await firebaseService.toggleAmin(prayerId: prayer.id, userUid: currentUid!);
                  },
                  child: Icon(
                    benAminDedimMi ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                    size: isFullView ? 20 : 14, 
                    color: benAminDedimMi ? Colors.redAccent : r.anaRenk.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

