import 'widgets/profil_avatar.dart';
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
import '../models/story.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../core/utils/extensions.dart';
part 'social/hikaye_goruntuleyici.dart';
part 'social/dua_kartlari.dart';

class SosyalSayfasi extends StatefulWidget {
  const SosyalSayfasi({super.key});

  @override
  State<SosyalSayfasi> createState() => _SosyalSayfasiState();
}

class _SosyalSayfasiState extends State<SosyalSayfasi> {
  final TextEditingController _duaController = TextEditingController();
  final FocusNode _duaFocusNode = FocusNode();
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedTab = 0; // 0: Dualarım, 1: Arkadaşların, 2: Global


  // 🔥 Stream'leri cache'le — her rebuild'de yeniden oluşmasını engelle
  late final Stream<List<UserProfile>> _leaderboardStream;
  late final Stream<List<UserProfile>> _fullLeaderboardStream;
  late final Stream<List<PrayerPost>> _fullPrayersStream;

  // Dinamik akışlar için önbellek:
  String? _cachedUid;
  Stream<UserProfile?>? _cachedUserProfileStream;
  
  Stream<List<PrayerPost>>? _cachedMyPrayersStream;
  Stream<List<PrayerPost>>? _cachedDiscoverStream;
  
  List<String> _lastFriendsList = [];
  Stream<List<PrayerPost>>? _cachedFriendsStream;
  
  // Bildirim ve profil detayları için önbellek:
  Stream<List<AppNotification>>? _cachedNotificationsStream;
  List<String> _lastFriendsProfileList = [];
  Stream<List<UserProfile>>? _cachedFriendsProfilesStream;

  bool _kardesSiralamasi = false; // Liderlik: false = genel, true = kardeşler (haftalık)

  bool _isSubmitting = false; // Paylaşım kontrolü
  String _lastSubmittedText = ""; // Mükerrer kayıt kontrolü


  @override
  void initState() {
    super.initState();
    _leaderboardStream = _firebaseService.getLeaderboard(limit: 5);
    _fullLeaderboardStream = _firebaseService.getLeaderboard(limit: 50);
    _fullPrayersStream = _firebaseService.getPrayers(limit: 200);
    _cachedDiscoverStream = _firebaseService.getPrayers(limit: 10);
    _cachedMyPrayersStream = null; // build içinde UID geldikçe oluşacak

    // 🔥 Sosyal akış önbelleğini Firestore'dan veri geldikçe güncelle
    _fullPrayersStream.listen((prayers) {
      if (mounted) {
        context.read<NamazProvider>().updatePrayerCache(prayers);
      }
    });
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
    // 🔥 BUGÜNKÜ XP HESAPLAMA (PRATİK YÖNTEM)
    int toplamBugunXp = provider.bugunKazanilanXp;

    // 🔥 Stream önbelleği UID bazlı sıfırlama
    if (_cachedUid != provider.currentUid) {
      _cachedUid = provider.currentUid;
      _cachedUserProfileStream = provider.currentUid != null 
          ? _firebaseService.getUserProfile(provider.currentUid!)
          : null;
      _cachedMyPrayersStream = null;
      _cachedFriendsStream = null;
      _cachedNotificationsStream = null;
      _cachedFriendsProfilesStream = null;
    }

    final r = context.renkler;

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
            _buildSectionHeader(
              title: "Arkadaşlarım", 
              icon: Icons.people_alt_rounded,
              buttonText: "Tümünü Gör",
              onSeeAll: () { FocusScope.of(context).unfocus(); _showFriendsModal(context, r, provider); }
            ),
            _buildFriendsPreview(context, r, provider),
            _buildOrtakHedef(r, provider),
            
            // 2. LİDERLİK TABLOSU ÖN İZLEME
            _buildSectionHeader(
              title: "Liderlik Tablosu", 
              icon: Icons.emoji_events_rounded,
              buttonText: "Tümünü Gör",
              onSeeAll: () { FocusScope.of(context).unfocus(); _showFullLeaderboard(context, r, provider); }
            ),
            if (provider.currentUid != null)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                child: Row(
                  children: [
                    _siralamaSecimi(r, "Genel", false),
                    SizedBox(width: Responsive.w(8)),
                    _siralamaSecimi(r, "Kardeşler • Bu Hafta", true),
                  ],
                ),
              ),
            _kardesSiralamasi
                ? _buildKardesSiralamasi(r, provider, limit: 5)
                : _buildIstikametPreview(context, r, provider),

            const SizedBox(height: 10),

            // 3. DUA MECLİSİ ÖN İZLEME VE SEKMELER
            Padding(
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
                        child: Icon(Icons.volunteer_activism_rounded, color: r.anaRenk, size: Responsive.w(18)),
                      ),
                      SizedBox(width: Responsive.w(10)),
                      Text("Meclis", style: TextStyle(fontSize: Responsive.sp(17), fontWeight: FontWeight.w900, color: r.yaziRengi, letterSpacing: -0.3)),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: r.anaRenk.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildMeclisTabButton("Dualarım", 0, r),
                        _buildMeclisTabButton("Arkadaşlar", 1, r),
                        _buildMeclisTabButton("Global", 2, r),
                      ],
                    ),
                  )
                ],
              ),
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

  Widget _buildMeclisTabButton(String label, int index, AppThemeColors r) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
        onTap: () {
          if (_selectedTab == index) return;
          FocusScope.of(context).unfocus(); // Sekme değişirken odağı temizle
          setState(() {
            _selectedTab = index;
            // Sekme değişince ilgili stream'i sıfırla, taze oluşturulsun
            _cachedMyPrayersStream = null;
            _cachedFriendsStream = null;
            _cachedDiscoverStream = null;
          });
        },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? r.arkaPlanRengi : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: isSelected ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4)] : [],
        ),
        child: Text(
          label, 
          style: TextStyle(
            fontWeight: FontWeight.bold, 
            fontSize: 12, 
            color: isSelected ? r.anaRenk : r.pasifRenk
          )
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
  void _profilFotoSecenekleri(BuildContext context, AppThemeColors r, NamazProvider provider) {
    final messenger = ScaffoldMessenger.of(context);
    Future<void> calistir(Future<String?> Function() islem) async {
      Navigator.pop(context);
      final hata = await islem();
      if (hata != null) messenger.showSnackBar(SnackBar(content: Text(hata)));
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBottomSheetHandle(r),
            ListTile(
              leading: Icon(Icons.photo_library_rounded, color: r.anaRenk),
              title: Text(provider.profilFoto == null ? "Profil Fotoğrafı Ekle" : "Profil Fotoğrafını Değiştir",
                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
              onTap: () => calistir(provider.profilFotoSec),
            ),
            if (provider.profilFoto != null)
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: r.kirmizi),
                title: Text("Fotoğrafı Kaldır", style: TextStyle(color: r.kirmizi, fontWeight: FontWeight.bold)),
                onTap: () => calistir(provider.profilFotoKaldir),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _buildOzetBar(BuildContext context, NamazProvider provider, AppThemeColors r, int bugunXp) {
    String unvan = provider.mevcutUnvan;
    String username = provider.currentUsername.isNotEmpty ? provider.currentUsername : unvan;
    String basHarf = username.isNotEmpty ? username[0].toUpperCase() : "T";
    
    // Seviye hesaplamaları
    int mevcutXp = provider.toplamXp;
    var anahtarlar = SeviyeServisi.unvanlar.keys.toList()..sort();
    int hedefXp = 1000;
    String hedefUnvan = "Salik";

    if (mevcutXp >= anahtarlar.last) {
      hedefXp = anahtarlar.last;
      hedefUnvan = "Zirve";
    } else {
      for (int i = 0; i < anahtarlar.length - 1; i++) {
        if (mevcutXp >= anahtarlar[i] && mevcutXp < anahtarlar[i + 1]) {
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
          StreamBuilder<UserProfile?>(
            stream: _cachedUserProfileStream,
            builder: (context, snap) {
              final profile = snap.data;
              final hasActiveStory = profile?.lastStoryAt != null && 
                  DateTime.now().difference(profile!.lastStoryAt!).inHours < 24;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  GestureDetector(
                    // Hikaye varsa açılır, yoksa fotoğraf seçenekleri; basılı tutunca her zaman fotoğraf
                    onTap: () async {
                      if (hasActiveStory && provider.currentUid != null) {
                        _openStoryViewerWithContext(context, provider, provider.currentUid!, r);
                      } else {
                        _profilFotoSecenekleri(context, r, provider);
                      }
                    },
                    onLongPress: () => _profilFotoSecenekleri(context, r, provider),
                    child: Stack(
                      children: [
                    Container(
                      padding: EdgeInsets.all(hasActiveStory ? 3 : 0),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: hasActiveStory ? Border.all(color: r.anaRenk, width: 2) : null,
                      ),
                      child: Container(
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
                        child: ProfilAvatar(
                          photoUrl: provider.profilFoto ?? profile?.photoUrl,
                          isim: basHarf,
                          radius: Responsive.w(30),
                          arkaPlan: Colors.transparent,
                          yaziRengi: Colors.white,
                        ),
                      ),
                    ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: GestureDetector(
                            onTap: () => _profilFotoSecenekleri(context, r, provider),
                            child: CircleAvatar(
                              radius: Responsive.w(10),
                              backgroundColor: r.kartRengi,
                              child: Icon(Icons.camera_alt_rounded, size: Responsive.w(12), color: r.anaRenk),
                            ),
                          ),
                        ),
                      ],
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
                        Text(
                          "@${provider.currentHandle}",
                          style: TextStyle(color: r.pasifRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: Responsive.h(4)),
                        Text(
                          unvan,
                          style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(11), letterSpacing: 0.5),
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
                        Image.asset(
                          'assets/images/streak_icon.png',
                          width: 20,
                          height: 20,
                          color: r.anaRenk,
                          colorBlendMode: BlendMode.srcIn,
                        ),
                        Text("${provider.streakCount} Gün", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(11))),
                      ],
                    ),
                  ),
                ],
              );
            }
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
  // 👥 0. ARKADAŞLARIM ÖN İZLEME (ÇEVRİMİÇİ)
  // ═══════════════════════════════════════════════

  /// Arkadaş profilleri akışı; liste değişmedikçe aynı akış kullanılır (her rebuild'de yeniden sorgu atılmasın)
  Stream<List<UserProfile>> _arkadasProfilleri(List<String> friends) {
    final degisti = _lastFriendsProfileList.length != friends.length ||
        !_lastFriendsProfileList.every((f) => friends.contains(f));
    if (degisti || _cachedFriendsProfilesStream == null) {
      _lastFriendsProfileList = List.from(friends);
      _cachedFriendsProfilesStream = _firebaseService.getFriendsProfilesStream(friends).asBroadcastStream();
    }
    return _cachedFriendsProfilesStream!;
  }

  /// Ben + arkadaşlarım (profil ve arkadaş akışlarını birleştirir)
  Widget _kardeslerleBirlikte(Widget Function(UserProfile ben, List<UserProfile> arkadaslar) builder) {
    return StreamBuilder<UserProfile?>(
      stream: _cachedUserProfileStream,
      builder: (context, userSnap) {
        final ben = userSnap.data;
        if (ben == null) return const SizedBox();
        if (ben.friends.isEmpty) return builder(ben, const []);
        return StreamBuilder<List<UserProfile>>(
          stream: _arkadasProfilleri(ben.friends),
          builder: (context, snap) => snap.hasData ? builder(ben, snap.data!) : const SizedBox(),
        );
      },
    );
  }

  /// Bu hafta ben + kardeşlerimin kıldığı toplam vakit / hedef (kişi başı 35)
  Widget _buildOrtakHedef(AppThemeColors r, NamazProvider provider) {
    if (provider.currentUid == null) return const SizedBox();
    return _kardeslerleBirlikte((ben, arkadaslar) {
      if (arkadaslar.isEmpty) return const SizedBox();
      final ozet = provider.haftalikOzet;
      final toplam = ozet.namaz + arkadaslar.fold<int>(0, (t, a) => t + a.buHaftaNamaz(ozet.hafta));
      final hedef = 35 * (arkadaslar.length + 1);
      final oran = (toplam / hedef).clamp(0.0, 1.0);
      return Container(
        margin: EdgeInsets.fromLTRB(Responsive.w(16), 0, Responsive.w(16), Responsive.h(10)),
        padding: EdgeInsets.all(Responsive.w(14)),
        decoration: BoxDecoration(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(16)),
          border: Border.all(color: r.anaRenk.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.groups_rounded, color: r.anaRenk, size: Responsive.w(18)),
                SizedBox(width: Responsive.w(8)),
                Expanded(
                  child: Text("Bu Hafta Birlikte",
                      style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi, fontSize: Responsive.sp(14))),
                ),
                Text("$toplam / $hedef vakit",
                    style: TextStyle(fontWeight: FontWeight.w900, color: r.anaRenk, fontSize: Responsive.sp(12))),
              ],
            ),
            SizedBox(height: Responsive.h(8)),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: oran,
                minHeight: Responsive.h(8),
                backgroundColor: r.pasifRenk.withOpacity(0.15),
                color: r.anaRenk,
              ),
            ),
            SizedBox(height: Responsive.h(6)),
            Text(
              oran >= 1
                  ? "Maşallah! ${arkadaslar.length + 1} kardeş bu haftanın tüm vakitlerini kıldı."
                  : "Sen ve ${arkadaslar.length} kardeşin, bu haftanın tüm vakitlerini birlikte tamamlayın.",
              style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11)),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFriendsPreview(BuildContext context, AppThemeColors r, NamazProvider provider) {
    if (provider.currentUid == null) return const SizedBox();

    return StreamBuilder<UserProfile?>(
      stream: _cachedUserProfileStream,
      builder: (context, userSnap) {
        if (!userSnap.hasData || userSnap.data == null) return const SizedBox();
        final friends = userSnap.data!.friends;
        if (friends.isEmpty) {
          return _buildEmptyState(
            r,
            "Arkadaşlarım",
            "Henüz bir kardeşin yok.\nArkadaşlarını ekle; birbirinizin namazlarını görün, birlikte hedef koyun.",
            butonYazisi: "Arkadaş Ekle",
            onButon: () => _showAddFriendModal(context, r, provider),
          );
        }

        return StreamBuilder<List<UserProfile>>(
          stream: _arkadasProfilleri(friends),
          builder: (context, profilesSnap) {
            if (!profilesSnap.hasData) return const SizedBox();
            
            // Arkadaşları sırala: 1. Hikayesi olanlar, 2. Çevrimiçi olanlar, 3. Son aktiflik
            final displayFriends = profilesSnap.data!;
            displayFriends.sort((a, b) {
              final now = DateTime.now();
              final aHasStory = a.lastStoryAt != null && now.difference(a.lastStoryAt!).inHours < 24;
              final bHasStory = b.lastStoryAt != null && now.difference(b.lastStoryAt!).inHours < 24;

              if (aHasStory != bHasStory) return aHasStory ? -1 : 1;
              if (a.isOnline != b.isOnline) return a.isOnline ? -1 : 1;
              
              final aTime = a.lastActive ?? DateTime(0);
              final bTime = b.lastActive ?? DateTime(0);
              return bTime.compareTo(aTime);
            });
            
            final limitedFriends = displayFriends.take(10).toList();
            if (limitedFriends.isEmpty) return const SizedBox();

            return Container(
              height: Responsive.h(100),
              margin: EdgeInsets.only(bottom: Responsive.h(10)),
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                scrollDirection: Axis.horizontal,
                itemCount: limitedFriends.length,
                itemBuilder: (context, index) {
                  final friend = limitedFriends[index];
                  final bool isOnline = friend.isOnline;
                  
                  // Aktif hikaye kontrolü (son 24 saat)
                  final bool hasActiveStory = friend.lastStoryAt != null && 
                      DateTime.now().difference(friend.lastStoryAt!).inHours < 24;

                  return GestureDetector(
                    onTap: () async {
                      if (hasActiveStory) {
                        // Eğer kendi hikayesi değilse izlenme kaydı yap (Arka planda)
                        if (friend.uid != provider.currentUid) {
                          _firebaseService.recordStoryView(
                            storyUid: friend.uid,
                            viewerUid: provider.currentUid!,
                            viewerDisplayName: provider.currentUsername,
                          );
                        }
                        _openStoryViewerWithContext(context, provider, friend.uid, r);
                      }
                    },
                    child: Container(
                      width: Responsive.w(65),
                      margin: EdgeInsets.only(right: Responsive.w(12)),
                      child: Column(
                        children: [
                          Stack(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(2.5),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: hasActiveStory 
                                      ? Border.all(color: r.anaRenk, width: 2)
                                      : Border.all(
                                          color: isOnline ? r.anaRenk.withOpacity(0.3) : r.pasifRenk.withOpacity(0.4), 
                                          width: 2
                                        ),
                                ),
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: r.arkaPlanRengi,
                                    shape: BoxShape.circle,
                                  ),
                                  child: ProfilAvatar(
                                    photoUrl: friend.photoUrl,
                                    isim: friend.displayName,
                                    radius: Responsive.w(22),
                                    arkaPlan: isOnline ? r.anaRenk.withOpacity(0.1) : r.pasifRenk.withOpacity(0.1),
                                    yaziRengi: isOnline ? r.anaRenk : r.pasifRenk,
                                  ),
                                ),
                              ),
                              if (isOnline)
                                Positioned(
                                  right: 2,
                                  bottom: 2,
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: Colors.green,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: r.arkaPlanRengi, width: 2),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            friend.displayName,
                            style: TextStyle(
                              color: isOnline ? r.yaziRengi : r.yaziRengi.withOpacity(0.6), 
                              fontSize: Responsive.sp(10), 
                              fontWeight: FontWeight.w800
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            "@${friend.username}",
                            style: TextStyle(
                              color: r.pasifRenk, 
                              fontSize: Responsive.sp(8), 
                              fontWeight: FontWeight.bold
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      }
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

  Widget _siralamaSecimi(AppThemeColors r, String etiket, bool kardesler) {
    return ChoiceChip(
      label: Text(etiket),
      selected: _kardesSiralamasi == kardesler,
      onSelected: (_) => setState(() => _kardesSiralamasi = kardesler),
      selectedColor: r.anaRenk.withOpacity(0.15),
      labelStyle: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: Responsive.sp(12),
        color: _kardesSiralamasi == kardesler ? r.anaRenk : r.pasifRenk,
      ),
      showCheckmark: false,
    );
  }

  /// Ben + kardeşlerim, bu haftaki XP'ye göre
  Widget _buildKardesSiralamasi(AppThemeColors r, NamazProvider provider, {int? limit, ScrollController? scrollController}) {
    return _kardeslerleBirlikte((ben, arkadaslar) {
      if (arkadaslar.isEmpty) {
        return _buildEmptyState(r, "Kardeş Sıralaması", "Kardeşlerini ekle, bu hafta kimin daha gayretli olduğunu birlikte görün.");
      }
      final hafta = provider.haftalikOzet.hafta;
      final xp = {for (final a in arkadaslar) a.uid: a.buHaftaXp(hafta), ben.uid: provider.haftalikOzet.xp};
      final liste = [ben, ...arkadaslar]..sort((a, b) => xp[b.uid]!.compareTo(xp[a.uid]!));
      final gosterilen = limit == null ? liste : liste.take(limit).toList();
      final ogeler = [
        for (int i = 0; i < gosterilen.length; i++)
          _buildLeaderboardItem(r, i, gosterilen[i], provider.currentUid, xpEtiketi: "${xp[gosterilen[i].uid]} XP"),
      ];
      return scrollController == null
          ? Column(children: ogeler)
          : ListView(controller: scrollController, children: ogeler);
    });
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
                child: Text(_kardesSiralamasi ? "Kardeşler • Bu Hafta" : "Liderlik Tablosu", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(18), color: r.yaziRengi)),
              ),
              Expanded(
                child: _kardesSiralamasi
                    ? _buildKardesSiralamasi(r, provider, scrollController: scrollController)
                    : StreamBuilder<List<UserProfile>>(
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

  Widget _buildLeaderboardItem(AppThemeColors r, int index, UserProfile user, String? currentUid, {String? xpEtiketi}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _kullaniciProfiliniGoster(context, r, user),
      child: _leaderboardSatiri(r, index, user, currentUid, xpEtiketi: xpEtiketi),
    );
  }

  Widget _leaderboardSatiri(AppThemeColors r, int index, UserProfile user, String? currentUid, {String? xpEtiketi}) {
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
          ProfilAvatar(
            photoUrl: user.photoUrl,
            isim: user.displayName,
            radius: Responsive.w(16),
            arkaPlan: isCurrentUser ? r.anaRenk.withOpacity(0.2) : r.pasifRenk.withOpacity(0.2),
            yaziRengi: isCurrentUser ? r.anaRenk : r.yaziRengi.withOpacity(0.7),
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
              Text(xpEtiketi ?? "${user.totalXp} XP", style: TextStyle(fontWeight: FontWeight.w900, color: r.yaziRengi, fontSize: Responsive.sp(13))),
              if (user.streak > 0)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset(
                      'assets/images/streak_icon.png',
                      width: 12,
                      height: 12,
                      color: r.anaRenk,
                      colorBlendMode: BlendMode.srcIn,
                    ),
                    const SizedBox(width: 2),
                    Text("${user.streak}", style: TextStyle(color: r.anaRenk, fontSize: Responsive.sp(10), fontWeight: FontWeight.bold)),
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
    if (provider.currentUid == null) {
      return Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(child: Text("Giriş Yapılmadı", style: TextStyle(color: r.pasifRenk))),
      );
    }

    return StreamBuilder<UserProfile?>(
      stream: _cachedUserProfileStream,
      builder: (context, userSnap) {
        if (userSnap.connectionState == ConnectionState.waiting && !userSnap.hasData) {
          return const Padding(
            padding: EdgeInsets.all(30),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        
        final friends = userSnap.data?.friends ?? [];

        // Arkadaşı olmayanlar için boş Kardeşlik ekranı uyarısı ve Ekleme Butonu
        if (_selectedTab == 1 && friends.isEmpty) {
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
                  "Arkadaşlarının dualarını görmek için arkadaş ekle.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(14), height: 1.5),
                ),
                SizedBox(height: Responsive.h(16)),
                ElevatedButton.icon(
                  onPressed: () {
                    FocusScope.of(context).unfocus();
                    _showAddFriendModal(context, r, provider);
                  },
                  icon: const Icon(Icons.person_add_rounded, size: 18, color: Colors.white),
                  label: const Text("Arkadaş Ekle", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: r.anaRenk,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  ),
                )
              ],
            ),
          );
        }

        // Aktif sekme için stream oluştur (yoksa)
        if (_selectedTab == 0 && _cachedMyPrayersStream == null && provider.currentUid != null) {
          _cachedMyPrayersStream = _firebaseService.getMyPrayers(provider.currentUid!, limit: 5);
        }
        if (_selectedTab == 1 && _cachedFriendsStream == null) {
          _lastFriendsList = List.from(friends);
          _cachedFriendsStream = _firebaseService.getFriendsPrayers(friends, limit: 5);
        } else if (_selectedTab == 1) {
          // Arkadaş listesi değiştiyse stream'i yenile
          bool friendsListChanged = _lastFriendsList.length != friends.length || 
              !_lastFriendsList.every((f) => friends.contains(f));
          if (friendsListChanged) {
            _lastFriendsList = List.from(friends);
            _cachedFriendsStream = _firebaseService.getFriendsPrayers(friends, limit: 5);
          }
        }
        if (_selectedTab == 2 && _cachedDiscoverStream == null) {
          _cachedDiscoverStream = _firebaseService.getPrayers(limit: 10);
        }

        // Aktif sekmenin stream'ini al
        Stream<List<PrayerPost>>? prayerStream;
        if (_selectedTab == 0) {
          prayerStream = _cachedMyPrayersStream;
        } else if (_selectedTab == 1) {
          prayerStream = _cachedFriendsStream;
        } else {
          prayerStream = _cachedDiscoverStream;
        }

        return StreamBuilder<List<PrayerPost>>(
          stream: prayerStream,
          builder: (context, snapshot) {
            // 🔥 FLUID UX: Global sekmesinde önbellekteki duaları göster, ama diğer sekmelerde datayı bekle
            final currentPrayers = snapshot.data ?? ( _selectedTab == 2 ? provider.cachedPrayers.take(5).toList() : [] );

            if (snapshot.connectionState == ConnectionState.waiting && currentPrayers.isEmpty) {
               return Padding(
                 padding: EdgeInsets.all(Responsive.w(30)),
                 child: Center(child: CircularProgressIndicator(color: r.anaRenk, strokeWidth: 2)),
               );
            }

            if (currentPrayers.isEmpty) {
              String msg = "Henüz bir dua paylaşılmamış.";
              if (_selectedTab == 0) msg = "Henüz bir dua paylaşmadın.";
              if (_selectedTab == 1) msg = "Arkadaşların bu hafta henüz dua paylaşmadı.";
              if (_selectedTab == 2) msg = "Bu hafta henüz dua paylaşılmadı.\nHaftanın ilk duasını sen paylaş!";

              return _buildEmptyState(r, "Dua Meclisi", msg, icon: Icons.volunteer_activism_outlined);
            }

            final prayers = currentPrayers;
            return Column(
              children: [
                ...prayers.asMap().entries.map((entry) => _buildDuaItem(context, r, entry.value, provider, prayers, entry.key)),
                TextButton.icon(
                  onPressed: () { 
                    FocusScope.of(context).unfocus(); 
                    if (_selectedTab == 0) {
                      _showDuaDuvari(
                        context, 
                        r, 
                        customStream: _firebaseService.getMyPrayers(provider.currentUid!, limit: 100),
                        title: "Dualarım"
                      );
                    } else if (_selectedTab == 1) {
                      _showDuaDuvari(
                        context, 
                        r, 
                        customStream: _firebaseService.getFriendsPrayers(friends, limit: 100),
                        title: "Arkadaşlarının Duaları"
                      );
                    } else {
                      _showDuaDuvari(context, r, customStream: _firebaseService.getPrayers(limit: 100)); 
                    }
                  },
                  icon: Icon(Icons.arrow_forward_rounded, color: r.anaRenk, size: 18),
                  label: Text("Tüm Duaları Gör", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
                ),
              ]
            );
          },
        );
      }
    );
  }

  void _showDuaDuvari(BuildContext context, AppThemeColors r, {Stream<List<PrayerPost>>? customStream, String? title}) {
    FocusScope.of(context).unfocus();
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
                child: Text(title ?? "Dua Duvarı", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(20), color: r.anaRenk)),
              ),
              Expanded(
                child: StreamBuilder<List<PrayerPost>>(
                  stream: customStream ?? _fullPrayersStream,
                  builder: (context, snapshot) {
                    final provider = context.read<NamazProvider>();
                    // 🔥 Önbellekten veriyi al (Sadece global akış için)
                    final currentPrayers = snapshot.data ?? (customStream == null ? provider.cachedPrayers : []);

                    if (snapshot.connectionState == ConnectionState.waiting && currentPrayers.isEmpty) {
                       return Center(child: CircularProgressIndicator(color: r.anaRenk));
                    }

                    if (currentPrayers.isEmpty) {
                      return Center(
                        child: Text("Dua duvarı boş", style: TextStyle(color: r.pasifRenk)),
                      );
                    }
                    final prayers = currentPrayers;
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
                          allPrayers: prayers,
                          index: index,
                          onReelTap: (list, idx) { 
                            FocusScope.of(context).unfocus(); 
                            
                            // Eğer Global akışındaysak (customStream null ise) tüm arşivi kullan
                            List<PrayerPost> swipeList = list;
                            int swipeIdx = idx;
                            
                            if (customStream == null && provider.cachedPrayers.isNotEmpty) {
                              swipeList = provider.cachedPrayers;
                              swipeIdx = swipeList.indexWhere((p) => p.id == list[idx].id);
                              if (swipeIdx == -1) {
                                swipeList = list;
                                swipeIdx = idx;
                              }
                            }
                            
                            _showPrayerReels(context, r, swipeList, swipeIdx); 
                          },
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

  Widget _buildDuaItem(BuildContext context, AppThemeColors r, PrayerPost prayer, NamazProvider provider, List<PrayerPost> allPrayers, int index) {
    final benAminDedimMi = provider.currentUid != null && 
                           provider.currentUid!.isNotEmpty && 
                           prayer.aminBy.contains(provider.currentUid);

    return GestureDetector(
      key: ValueKey(prayer.id),
      onLongPress: () => duaSecenekleriniGoster(context, r, prayer, provider.currentUid),
      onTap: () {
        // Eğer Global sekmesindeysek tüm arşivi (cache) kullan
        List<PrayerPost> swipeList = allPrayers;
        int swipeIndex = index;

        if (_selectedTab == 2 && provider.cachedPrayers.isNotEmpty) {
          swipeList = provider.cachedPrayers;
          swipeIndex = swipeList.indexWhere((p) => p.id == prayer.id);
          // Eğer tıklanan dua cache'de yoksa (nadir), mevcut listeyi kullanmaya devam et
          if (swipeIndex == -1) {
            swipeList = allPrayers;
            swipeIndex = index;
          }
        }
        
        _showPrayerReels(context, r, swipeList, swipeIndex);
      },
      child: Card(
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prayer.senderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(13), color: r.yaziRengi)),
                      if (prayer.senderUsername.isNotEmpty)
                        Text("@${prayer.senderUsername}", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10), fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const Spacer(),
                  Text(prayer.zamanFarki, style: TextStyle(color: r.yaziRengi.withOpacity(0.4), fontSize: Responsive.sp(10))),
                ],
              ),
              SizedBox(height: Responsive.h(12)),
              Text(
                prayer.text,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: r.yaziRengi.withOpacity(0.8), fontSize: Responsive.sp(14), height: 1.5, fontStyle: FontStyle.italic),
              ),
              SizedBox(height: Responsive.h(16)),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Amin sayısı
                  if (prayer.aminCount > 0)
                    Text(
                      "${prayer.aminCount} beğeni",
                      style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11), fontWeight: FontWeight.w500),
                    ),
                  const Spacer(),
                  // Amin butonu (Animasyonlu)
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (provider.currentUid == null) return;
                      // Hında reaksiyon hissi
                      HapticFeedback.lightImpact();
                        final isAdded = await _firebaseService.toggleAmin(
                          prayerId: prayer.id,
                          userUid: provider.currentUid!,
                        );

                        // 🔥 XP KAZANDIRMA/GERİ ALMA: Kendi duası değilse
                        if (prayer.senderUid != provider.currentUid) {
                          if (isAdded == true) {
                            await provider.xpEkle(SeviyeServisi.aminXp);
                          } else if (isAdded == false) {
                            await provider.xpEkle(-SeviyeServisi.aminXp);
                          }
                        }

                      if (isAdded != null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isAdded ? "Dua meclisine katıldınız. Amîn!" : "Amîn geri alındı."), 
                            duration: const Duration(seconds: 1)
                          ),
                        );
                      }
                    },
                    icon: AminParticleButton(
                      key: ValueKey("anim_${prayer.id}"),
                      isAmind: benAminDedimMi,
                      r: r,
                      child: Icon(
                        benAminDedimMi ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                        size: 16, 
                        color: Colors.white,
                      ),
                    ),
                    label: Text(
                      benAminDedimMi ? "Amîn ✓" : "Amîn", 
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
      ),
    );
  }

  void _showPrayerReels(BuildContext context, AppThemeColors r, List<PrayerPost> prayers, int initialIndex) {
    FocusScope.of(context).unfocus();

    // 1. Tıklanan duayı bul
    final clickedPrayer = prayers[initialIndex];
    
    // 2. Diğer tüm duaları al ve karıştır
    final otherPrayers = prayers.where((p) => p.id != clickedPrayer.id).toList()..shuffle();
    
    // 3. Tıklanan duayı en başa koy, diğerlerini arkasına ekle
    final finalPrayers = [clickedPrayer, ...otherPrayers];

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Prayers",
      barrierColor: Colors.black.withOpacity(0.6),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                PageView.builder(
                  scrollDirection: Axis.vertical,
                  controller: PageController(initialPage: 0),
                  itemCount: finalPrayers.length,
                  itemBuilder: (context, index) {
                    final prayer = finalPrayers[index];
                    return Center(
                      child: Container(
                        margin: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                        height: MediaQuery.of(context).size.height * 0.75,
                        child: _buildReelItem(context, r, prayer),
                      ),
                    );
                  },
                ),
                // Kapat butonu
                Positioned(
                  top: Responsive.h(50),
                  right: Responsive.w(20),
                  child: IconButton(
                    icon: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(
          opacity: anim1,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.9, end: 1.0).animate(CurvedAnimation(parent: anim1, curve: Curves.easeOutBack)),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildReelItem(BuildContext context, AppThemeColors r, PrayerPost initialPrayer) {
    final provider = context.read<NamazProvider>();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('prayers').doc(initialPrayer.id).snapshots(),
      builder: (context, snapshot) {
        // Eğer veri geldiyse güncel duayı kullan, yoksa başlangıç değerini kullan
        final prayer = snapshot.hasData && snapshot.data!.exists
            ? PrayerPost.fromFirestore(snapshot.data!)
            : initialPrayer;
            
        final benAminDedimMi = provider.currentUid != null && prayer.aminBy.contains(provider.currentUid);

        return Container(
          padding: EdgeInsets.all(Responsive.w(24)),
          decoration: BoxDecoration(
            color: r.kartRengi.withOpacity(0.9),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 30,
                offset: const Offset(0, 10),
              )
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: r.anaRenk.withOpacity(0.2),
                child: Text(
                  prayer.senderName.isNotEmpty ? prayer.senderName[0].toUpperCase() : "?",
                  style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: 24),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                prayer.senderName,
                style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                "@${prayer.senderUsername}",
                style: TextStyle(color: r.pasifRenk, fontSize: 14),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Text(
                      prayer.text,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: r.yaziRengi.withOpacity(0.9), 
                        fontSize: Responsive.sp(18), 
                        height: 1.6, 
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    children: [
                      AminParticleButton(
                        isAmind: benAminDedimMi,
                        r: r,
                        child: IconButton(
                          icon: Icon(
                            benAminDedimMi ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                            color: benAminDedimMi ? r.kirmizi : r.pasifRenk,
                            size: 32,
                          ),
                          onPressed: () async {
                            if (provider.currentUid == null) return;
                            HapticFeedback.mediumImpact();
                            final isAdded = await _firebaseService.toggleAmin(
                              prayerId: prayer.id,
                              userUid: provider.currentUid!,
                            );

                            // 🔥 XP KAZANDIRMA/GERİ ALMA: Kendi duası değilse
                            if (prayer.senderUid != provider.currentUid) {
                              if (isAdded == true) {
                                await provider.xpEkle(SeviyeServisi.aminXp);
                              } else if (isAdded == false) {
                                await provider.xpEkle(-SeviyeServisi.aminXp);
                              }
                            }

                          },
                        ),
                      ),
                      Text(
                        "${prayer.aminCount}",
                        style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(width: 40),
                  Column(
                    children: [
                      IconButton(
                        icon: Icon(Icons.share_rounded, color: r.pasifRenk, size: 28),
                        onPressed: () {
                          final shareText = "🤲 NamazApp Dua Meclisi'nden bir dua:\n\n\"${prayer.text}\"\n\n— ${prayer.senderName} (@${prayer.senderUsername})\n\nSen de aramıza katıl!";
                          Share.share(shareText);
                        },
                      ),
                      Text(
                        "Paylaş",
                        style: TextStyle(color: r.pasifRenk, fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                prayer.zamanFarki,
                style: TextStyle(color: r.pasifRenk.withOpacity(0.6), fontSize: 11),
              ),
            ],
          ),
        );
      },
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
                "Dua Ekle",
                style: TextStyle(
                  color: r.yaziRengi, 
                  fontWeight: FontWeight.bold, 
                  fontSize: Responsive.sp(15),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _duaController,
            focusNode: _duaFocusNode,
            autofocus: false,
            onTapOutside: (event) => _duaFocusNode.unfocus(),
            maxLines: 3,
            maxLength: 500,
            style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(14)),
            decoration: InputDecoration(
              hintText: "Duanızı buraya yazın...",
              hintStyle: TextStyle(color: r.yaziRengi.withOpacity(0.3)),
              filled: true,
              fillColor: r.arkaPlanRengi,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(15), 
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
              counterStyle: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10)),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: Responsive.h(45),
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : () async {
                final text = _duaController.text.trim();
                
                if (text.isEmpty) return;

                // Mükerrer kayıt kontrolü
                if (text == _lastSubmittedText) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Aynı duayı az önce paylaştınız.")),
                    );
                  }
                  return;
                }

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

                setState(() => _isSubmitting = true);

                try {
                  await _firebaseService.addPrayer(
                    text: text,
                    senderUid: provider.currentUid!,
                    senderName: provider.currentUsername,
                    senderUsername: provider.currentHandle,
                  );

                  // 🔥 XP KAZANDIRMA
                  await provider.xpEkle(SeviyeServisi.duaXp);
                  await provider.duaPaylasildi();

                  _lastSubmittedText = text; // Başarılıysa kaydet
                  _duaController.clear();
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Duanız meclise iletildi. Allah kabul etsin!")),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Hata oluştu: $e")),
                    );
                  }
                } finally {
                  if (mounted) setState(() => _isSubmitting = false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: r.anaRenk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: _isSubmitting 
                ? const SizedBox(
                    width: 20, 
                    height: 20, 
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text(
                    "Duanı Paylaş", 
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
            ),
          ),
        ],
      ),
    );
  } // <--- Buradaki noktali virgul (;) kaldirildi.

  // --- YARDIMCI WİDGET'LAR ---

  Widget _buildEmptyState(AppThemeColors r, String title, String message,
      {IconData icon = Icons.people_outline_rounded, String? butonYazisi, VoidCallback? onButon}) {
    return Container(
      width: double.infinity, // Diğer kartlar gibi tam genişlik
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(10)),
      padding: EdgeInsets.all(Responsive.w(24)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(color: r.pasifRenk.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40, color: r.pasifRenk.withOpacity(0.4)),
          SizedBox(height: Responsive.h(12)),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(13), height: 1.5),
          ),
          if (butonYazisi != null && onButon != null) ...[
            SizedBox(height: Responsive.h(14)),
            ElevatedButton.icon(
              onPressed: onButon,
              icon: const Icon(Icons.person_add_alt_1_rounded, size: 18, color: Colors.white),
              label: Text(butonYazisi, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: r.anaRenk,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
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
    if (_cachedNotificationsStream == null && provider.currentUid != null) {
      _cachedNotificationsStream = FirebaseService().getNotifications(provider.currentUid!);
    }

    return StreamBuilder<List<AppNotification>>(
      stream: _cachedNotificationsStream,
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final unreadCount = snapshot.data!.where((n) => n.status == 'pending' || n.status == 'unread').length;
        
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
        final pendingNotifs = notifications
            .where((n) => n.type == 'friend_request' ? n.status == 'pending' : true)
            .toList();
        // Açılınca bilgi bildirimleri okundu sayılır
        _firebaseService.bildirimleriOkunduYap(
          provider.currentUid!,
          [for (final n in notifications) if (n.status == 'unread') n.id],
        );
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
                        if (notif.type != 'friend_request') return _bilgiBildirimi(context, r, provider, notif);
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
                                onPressed: () => _istegiCevapla(context, provider, notif, kabul: true),
                              ),
                              IconButton(
                                icon: const Icon(Icons.cancel_rounded, color: Colors.redAccent),
                                onPressed: () => _istegiCevapla(context, provider, notif, kabul: false),
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

  /// "İsteğin kabul edildi" ve "namazını kıldın mı?" bildirimleri
  Widget _bilgiBildirimi(BuildContext context, AppThemeColors r, NamazProvider provider, AppNotification notif) {
    final hatirlatma = notif.type == 'nudge';
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: r.anaRenk.withOpacity(0.2),
        child: Icon(hatirlatma ? Icons.waving_hand_rounded : Icons.handshake_rounded, color: r.anaRenk),
      ),
      title: Text(
        hatirlatma
            ? "${notif.fromDisplayName} hatırlatıyor: ${notif.vakit ?? 'namazını'} kıldın mı? 🤲"
            : "${notif.fromDisplayName} kardeşlik isteğini kabul etti.",
        style: TextStyle(color: r.yaziRengi, fontWeight: notif.status == 'unread' ? FontWeight.bold : FontWeight.normal),
      ),
      subtitle: Text("@${notif.fromUsername} • ${notif.timestamp.zamanFarki}", style: TextStyle(color: r.pasifRenk, fontSize: 12)),
      trailing: IconButton(
        icon: Icon(Icons.close_rounded, color: r.pasifRenk),
        onPressed: () {
          _firebaseService.bildirimiSil(provider.currentUid!, notif.id);
          Navigator.pop(context);
        },
      ),
    );
  }

  Future<void> _istegiCevapla(BuildContext context, NamazProvider provider, AppNotification notif, {required bool kabul}) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.pop(context);
    final hata = await _firebaseService.respondToFriendRequest(
      currentUid: provider.currentUid!,
      targetUid: notif.fromUid,
      accept: kabul,
      currentUsername: provider.currentHandle,
      currentDisplayName: provider.currentUsername,
    );
    messenger.showSnackBar(SnackBar(
      content: Text(hata ?? (kabul
          ? "${notif.fromDisplayName} ile artık kardeşsiniz."
          : "İstek reddedildi.")),
    ));
  }

  void _showAddFriendModal(BuildContext context, AppThemeColors r, NamazProvider provider) {
    if (provider.currentUid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Giriş yapmanız gerekiyor.")));
      return;
    }
    
    final TextEditingController searchController = TextEditingController();
    bool isSearching = false;
    String errorMessage = "";
    final messenger = ScaffoldMessenger.of(context);

    Future<void> istekGonder(String kullaniciAdi, StateSetter setState) async {
      final hedef = kullaniciAdi.trim().replaceFirst('@', '');
      if (hedef.isEmpty || isSearching) return;
      setState(() { isSearching = true; errorMessage = ""; });

      final err = await _firebaseService.sendFriendRequest(
        targetUsername: hedef,
        senderUid: provider.currentUid!,
        senderUsername: provider.currentHandle,
        senderDisplayName: provider.currentUsername,
      );
      if (!mounted) return;

      if (err == null || err == FirebaseService.arkadasOlduMesaji) {
        Navigator.of(this.context).pop();
        messenger.showSnackBar(SnackBar(
          content: Text(err == null
              ? "Arkadaşlık isteği gönderildi!"
              : "@$hedef sana zaten istek göndermişti, artık kardeşsiniz!"),
        ));
      } else {
        setState(() { isSearching = false; errorMessage = err; });
      }
    }

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
                  Text("Arkadaş Ekle", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(18), color: r.yaziRengi)),
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
                      onPressed: isSearching ? null : () => istekGonder(searchController.text, setState),
                      child: isSearching 
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Text("İstek Gönder", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  Divider(color: r.pasifRenk.withOpacity(0.1)),
                  const SizedBox(height: 12),
                  
                  // Önerilen Kardeşler
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Sana Önerilenler", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(14), color: r.pasifRenk)),
                  ),
                  const SizedBox(height: 12),
                  FutureBuilder<UserProfile?>(
                    future: FirebaseService().getUserProfile(provider.currentUid!).first,
                    builder: (context, userSnap) {
                      if (userSnap.connectionState == ConnectionState.waiting) {
                        return Center(child: CircularProgressIndicator(color: r.anaRenk, strokeWidth: 2));
                      }
                      
                      final currentFriends = userSnap.data?.friends ?? [];
                      
                      return FutureBuilder<List<UserProfile>>(
                        future: _firebaseService.getSuggestedFriends(
                          provider.currentUid!,
                          currentFriends,
                          haric: userSnap.data?.gonderilenIstekler ?? const [],
                        ),
                        builder: (context, suggestSnap) {
                          if (suggestSnap.connectionState == ConnectionState.waiting) {
                            return const Center(child: SizedBox(height: 100));
                          }
                          
                          final suggestions = suggestSnap.data ?? [];
                          if (suggestions.isEmpty) {
                            return Text("Şu an için yeni bir öneri bulunmuyor.", style: TextStyle(color: r.pasifRenk.withOpacity(0.6), fontSize: 12));
                          }
                          
                          return SizedBox(
                            height: 140, // Kart yüksekliği
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: suggestions.length,
                              itemBuilder: (context, idx) {
                                final sUser = suggestions[idx];
                                return Container(
                                  width: 110,
                                  margin: const EdgeInsets.only(right: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: r.kartRengi,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: r.pasifRenk.withOpacity(0.1)),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      ProfilAvatar(
                                        photoUrl: sUser.photoUrl,
                                        isim: sUser.displayName,
                                        radius: 20,
                                        arkaPlan: r.anaRenk.withOpacity(0.2),
                                        yaziRengi: r.anaRenk,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        sUser.displayName,
                                        style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi, fontSize: 12),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        sUser.unvan,
                                        style: TextStyle(color: r.pasifRenk, fontSize: 10),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const Spacer(),
                                      SizedBox(
                                        height: 24,
                                        child: ElevatedButton(
                                          onPressed: isSearching ? null : () => istekGonder(sUser.username, setState),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: r.anaRenk.withOpacity(0.1),
                                            elevation: 0,
                                            padding: const EdgeInsets.symmetric(horizontal: 12),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          child: Text("Ekle", style: TextStyle(color: r.anaRenk, fontSize: 11, fontWeight: FontWeight.bold)),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }

  void _showDeleteFriendDialog(BuildContext context, AppThemeColors r, UserProfile user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: r.arkaPlanRengi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Arkadaşlıktan Çıkar", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
        content: Text(
          "${user.displayName} (@${user.username}) isimli kardeşimizi arkadaşlarınızdan çıkarmak istediğinize emin misiniz?",
          style: TextStyle(color: r.yaziRengi.withOpacity(0.7)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Vazgeç", style: TextStyle(color: r.pasifRenk, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<NamazProvider>().arkadasiSil(user.uid);
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text("${user.displayName} arkadaşlıktan çıkarıldı."),
                  backgroundColor: r.anaRenk,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: r.kirmizi,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Çıkar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
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
                child: Text("Mümin Kardeşlerim", style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(18), color: r.yaziRengi)),
              ),
              Expanded(
                child: StreamBuilder<UserProfile?>(
                  stream: _firebaseService.getUserProfile(provider.currentUid!),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData || snapshot.data == null) return const Center(child: CircularProgressIndicator());
                    
                    final friendsList = snapshot.data!.friends;
                    if (friendsList.isEmpty) return Center(child: Text("Henüz bir kardeşiniz ekli değil.\nDua halkasına arkadaşlarınızı davet edin!", textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk)));

                    return StreamBuilder<List<UserProfile>>(
                      stream: _firebaseService.getFriendsProfilesStream(friendsList),
                      builder: (context, streamSnap) {
                        if (!streamSnap.hasData) return const Center(child: CircularProgressIndicator());
                        
                        // Tüm arkadaşları sırala: Önce çevrimiçi olanlar, sonra son aktiflik zamanına göre
                        final allFriendsSorted = streamSnap.data!;
                        allFriendsSorted.sort((a, b) {
                          if (a.isOnline != b.isOnline) {
                            return a.isOnline ? -1 : 1;
                          }
                          final aTime = a.lastActive ?? DateTime(0);
                          final bTime = b.lastActive ?? DateTime(0);
                          return bTime.compareTo(aTime);
                        });

                        final onlineOnes = allFriendsSorted.where((f) => f.isOnline).toList();
                        final offlineOnes = allFriendsSorted.where((f) => !f.isOnline).toList();

                        return ListView(
                          controller: scrollController,
                          padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                          children: [
                            if (onlineOnes.isNotEmpty) ...[
                              _buildSubHeader(r, "Çevrimiçi", onlineOnes.length),
                              ...onlineOnes.map((f) => _buildFriendItem(r, f, provider.currentUid)),
                            ],
                            if (offlineOnes.isNotEmpty) ...[
                              SizedBox(height: Responsive.h(16)),
                              _buildSubHeader(r, "Çevrimdışı", offlineOnes.length),
                              ...offlineOnes.map((f) => _buildFriendItem(r, f, provider.currentUid)),
                            ],
                            SizedBox(height: Responsive.h(40)),
                          ],
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

  Widget _buildSubHeader(AppThemeColors r, String title, int count) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: Responsive.h(10)),
      child: Row(
        children: [
          Text(title, style: TextStyle(color: r.pasifRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(14))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: r.pasifRenk.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text("$count", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Kullanıcı profil kartı: unvan, XP, seri, bu haftaki gayret ve bugünkü vakitler
  void _kullaniciProfiliniGoster(BuildContext context, AppThemeColors r, UserProfile user) {
    final provider = context.read<NamazProvider>();
    final hafta = provider.haftalikOzet.hafta;
    final benim = user.uid == provider.currentUid;

    Widget kutu(String deger, String etiket, IconData ikon) => Expanded(
          child: Container(
            padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
            decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(14)),
            child: Column(
              children: [
                Icon(ikon, color: r.anaRenk, size: Responsive.w(20)),
                SizedBox(height: Responsive.h(4)),
                Text(deger, style: TextStyle(fontWeight: FontWeight.w900, color: r.yaziRengi, fontSize: Responsive.sp(15))),
                Text(etiket, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10))),
              ],
            ),
          ),
        );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.arkaPlanRengi,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (_) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(Responsive.w(20), 0, Responsive.w(20), Responsive.h(20)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildBottomSheetHandle(r),
              ProfilAvatar(
                photoUrl: benim ? (provider.profilFoto ?? user.photoUrl) : user.photoUrl,
                isim: user.displayName,
                radius: Responsive.w(40),
                arkaPlan: r.anaRenk.withOpacity(0.15),
                yaziRengi: r.anaRenk,
              ),
              SizedBox(height: Responsive.h(10)),
              Text(user.displayName,
                  style: TextStyle(fontWeight: FontWeight.w900, color: r.yaziRengi, fontSize: Responsive.sp(18))),
              Text("@${user.username} • ${user.unvan}",
                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
              if (!benim)
                Text(user.isOnline ? "Çevrimiçi" : "Son görülme: ${user.lastActive?.zamanFarki ?? 'Belirsiz'}",
                    style: TextStyle(color: r.pasifRenk.withOpacity(0.7), fontSize: Responsive.sp(11))),
              SizedBox(height: Responsive.h(16)),
              Row(
                children: [
                  kutu("${user.totalXp}", "Toplam XP", Icons.star_rounded),
                  SizedBox(width: Responsive.w(8)),
                  kutu("${user.streak}", "Gün Seri", Icons.local_fire_department_rounded),
                  SizedBox(width: Responsive.w(8)),
                  kutu("${user.friends.length}", "Kardeş", Icons.groups_rounded),
                ],
              ),
              SizedBox(height: Responsive.h(8)),
              Row(
                children: [
                  kutu("${user.buHaftaNamaz(hafta)}/35", "Bu Hafta Vakit", Icons.calendar_month_rounded),
                  SizedBox(width: Responsive.w(8)),
                  kutu("${user.buHaftaXp(hafta)}", "Bu Hafta XP", Icons.trending_up_rounded),
                ],
              ),
              SizedBox(height: Responsive.h(14)),
              Align(
                alignment: Alignment.centerLeft,
                child: Text("Bugün", style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
              ),
              SizedBox(height: Responsive.h(6)),
              _bugunkuVakitler(r, user),
            ],
          ),
        ),
      ),
    );
  }

  /// Arkadaşın bugün işaretlediği vakitler (5 nokta)
  Widget _bugunkuVakitler(AppThemeColors r, UserProfile user) {
    final provider = context.read<NamazProvider>();
    final kilinan = user.bugunKilinanlar(provider.getSanalGun());
    return Row(
      children: [
        for (final v in provider.vakitIsimleri)
          Tooltip(
            message: kilinan.contains(v) ? "$v kılındı" : v,
            child: Container(
              width: Responsive.w(8),
              height: Responsive.w(8),
              margin: EdgeInsets.only(right: Responsive.w(4)),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kilinan.contains(v) ? r.anaRenk : r.pasifRenk.withOpacity(0.25),
              ),
            ),
          ),
        Text("${kilinan.length}/5 bugün", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(9))),
      ],
    );
  }

  /// Arkadaş şu anki vakti henüz işaretlemediyse "hatırlat" butonu
  Widget _hatirlatButonu(AppThemeColors r, UserProfile user) {
    final provider = context.read<NamazProvider>();
    final vakit = provider.aktifVakit;
    if (!provider.vakitIsimleri.contains(vakit)) return const SizedBox();
    if (user.bugunKilinanlar(provider.getSanalGun()).contains(vakit)) return const SizedBox();
    return IconButton(
      tooltip: "$vakit namazını hatırlat",
      icon: Icon(Icons.waving_hand_rounded, color: r.anaRenk, size: 20),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final hata = await _firebaseService.durtGonder(
          fromUid: provider.currentUid!,
          fromUsername: provider.currentHandle,
          fromDisplayName: provider.currentUsername,
          targetUid: user.uid,
          vakit: vakit,
          gun: provider.getSanalGun(),
        );
        messenger.showSnackBar(SnackBar(
          content: Text(hata ?? "${user.displayName} kardeşine $vakit namazı hatırlatıldı."),
        ));
      },
    );
  }

  Widget _buildFriendItem(AppThemeColors r, UserProfile user, String? currentUid) {
    final lastSeen = user.lastActive != null ? user.lastActive!.zamanFarki : "Belirsiz";
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _kullaniciProfiliniGoster(context, r, user),
      child: _arkadasSatiri(r, user, currentUid, lastSeen),
    );
  }

  Widget _arkadasSatiri(AppThemeColors r, UserProfile user, String? currentUid, String lastSeen) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(10)),
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(15)),
        border: Border.all(color: r.pasifRenk.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              ProfilAvatar(
                photoUrl: user.photoUrl,
                isim: user.displayName,
                radius: Responsive.w(20),
                arkaPlan: r.anaRenk.withOpacity(0.1),
                yaziRengi: r.anaRenk,
              ),
              if (user.isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: Colors.green, shape: BoxShape.circle, border: Border.all(color: r.arkaPlanRengi, width: 2)),
                  ),
                ),
            ],
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.displayName, style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi, fontSize: Responsive.sp(14))),
                Text("@${user.username}", style: TextStyle(color: r.anaRenk.withOpacity(0.7), fontWeight: FontWeight.bold, fontSize: Responsive.sp(11))),
                Text(user.isOnline ? "Çevrimiçi" : "Son görülme: $lastSeen", style: TextStyle(color: r.pasifRenk.withOpacity(0.6), fontSize: Responsive.sp(10))),
                SizedBox(height: Responsive.h(4)),
                _bugunkuVakitler(r, user),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("${user.totalXp} XP", style: TextStyle(fontWeight: FontWeight.bold, color: r.anaRenk, fontSize: Responsive.sp(12))),
              Text(user.unvan, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10))),
            ],
          ),
          _hatirlatButonu(r, user),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: r.pasifRenk, size: 20),
            padding: EdgeInsets.zero,
            onSelected: (value) async {
              if (value == 'delete') {
                _showDeleteFriendDialog(context, r, user);
              } else if (value == 'block' && currentUid != null) {
                final messenger = ScaffoldMessenger.of(context);
                final hata = await _firebaseService.kullaniciyiEngelle(currentUid, user.uid);
                messenger.showSnackBar(SnackBar(content: Text(hata ?? "@${user.username} engellendi.")));
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.person_remove_rounded, color: r.kirmizi, size: 18),
                    const SizedBox(width: 8),
                    Text("Kardeşlikten Çıkar", style: TextStyle(color: r.kirmizi, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: Row(
                  children: [
                    Icon(Icons.block_rounded, color: r.kirmizi, size: 18),
                    const SizedBox(width: 8),
                    Text("Engelle", style: TextStyle(color: r.kirmizi, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  
  // --- HİKAYE YÖNETİCİSİ (YÜKLEME VE AÇMA) ---
  Future<void> _openStoryViewerWithContext(BuildContext context, NamazProvider provider, String targetUid, AppThemeColors r) async {
    if (provider.currentUid == null) return;

    // Arkadaş listesini al (Kendi hikayemiz de dahil edilecek)
    final profile = await _firebaseService.getUserProfileFuture(provider.currentUid!);
    final friends = profile?.friends ?? [];

    // Tüm aktif hikayeleri çek
    List<UserStory> allStories = await _firebaseService.getActiveStoriesFuture(friends, provider.currentUid!);
    
    if (allStories.isEmpty) return;

    // 🔥 MANTIĞI GÜNCELLE:
    // Eğer kendi storymize tıkladıysak SADECE kendi storymizi görelim.
    // Eğer arkadaş storysine tıkladıysak SADECE arkadaşların storylerini görelim (kendimizinkini listeden çıkaralım).
    if (targetUid == provider.currentUid) {
      allStories = allStories.where((s) => s.uid == provider.currentUid).toList();
    } else {
      allStories = allStories.where((s) => s.uid != provider.currentUid).toList();
    }

    if (allStories.isEmpty) return;

    // 🔥 SIRALAMA MANTIĞI: Arkadaş listesindeki görsel sırayla aynı olmalı.
    // (Hikayesi olanlar zaten filtrelendi, şimdi Online ve Son Aktifliğe göre sıralayalım)
    if (targetUid != provider.currentUid) {
      final profiles = await _firebaseService.getFriendsProfilesStream(friends).first;
      allStories.sort((a, b) {
        final profileA = profiles.firstWhere((p) => p.uid == a.uid, orElse: () => UserProfile(uid: a.uid, username: a.username, displayName: a.displayName, totalXp: 0, unvan: "Talip", streak: 0, createdAt: DateTime.now()));
        final profileB = profiles.firstWhere((p) => p.uid == b.uid, orElse: () => UserProfile(uid: b.uid, username: b.username, displayName: b.displayName, totalXp: 0, unvan: "Talip", streak: 0, createdAt: DateTime.now()));
        
        if (profileA.isOnline != profileB.isOnline) return profileA.isOnline ? -1 : 1;
        final aTime = profileA.lastActive ?? DateTime(0);
        final bTime = profileB.lastActive ?? DateTime(0);
        return bTime.compareTo(aTime);
      });
    }

    // Tıklanan kullanıcının hikayesinin indexini bul
    int initialIndex = allStories.indexWhere((s) => s.uid == targetUid);
    if (initialIndex == -1) initialIndex = 0;

    if (context.mounted) {
      _showStoryViewer(context, r, allStories, initialIndex);
    }
  }
}
