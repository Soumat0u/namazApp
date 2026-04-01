import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../services/seviye_servisi.dart';

class SosyalSayfasi extends StatelessWidget {
  const SosyalSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final r = context.renkler;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        title: Text(
          "Topluluk",
          style: TextStyle(
            color: r.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(18),
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: r.yaziRengi, size: Responsive.w(20)),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(Responsive.w(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Kendi Profilim
            _buildProfilKarti(context, provider, r),
            SizedBox(height: Responsive.h(24)),
            
            // Liderlik Tablosu
            Text(
              "Haftanın Liderleri",
              style: TextStyle(
                color: r.yaziRengi,
                fontWeight: FontWeight.w800,
                fontSize: Responsive.sp(16),
              ),
            ),
            SizedBox(height: Responsive.h(12)),
            _buildLiderlikTablosu(context, r, provider),
            
            SizedBox(height: Responsive.h(24)),
            
            // Arkadaşlar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Arkadaşların",
                  style: TextStyle(
                    color: r.yaziRengi,
                    fontWeight: FontWeight.w800,
                    fontSize: Responsive.sp(16),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Bu özellik henüz geliştirme aşamasındadır.")),
                    );
                  },
                  child: Text(
                    "Tümü",
                    style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            _buildArkadasListesi(context, r),
            
            SizedBox(height: Responsive.h(80)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Bu özellik henüz geliştirme aşamasındadır.")),
          );
        },
        backgroundColor: r.anaRenk,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
        label: const Text("Arkadaş Ekle", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildProfilKarti(BuildContext context, NamazProvider provider, AppThemeColors r) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [r.anaRenk, r.anaRenk.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: [
          BoxShadow(
            color: r.anaRenk.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: Responsive.w(30),
            backgroundColor: Colors.white,
            child: Icon(Icons.person, color: r.anaRenk, size: Responsive.w(35)),
          ),
          SizedBox(width: Responsive.w(16)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Sen (Benim Profilim)",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: Responsive.sp(16),
                  ),
                ),
                SizedBox(height: Responsive.h(4)),
                Text(
                  provider.mevcutUnvan,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: Responsive.sp(13),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: Responsive.h(8)),
                Row(
                  children: [
                    Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: Responsive.w(16)),
                    SizedBox(width: Responsive.w(4)),
                    Text(
                      "${provider.streakCount} Günlük Seri",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.sp(12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiderlikTablosu(BuildContext context, AppThemeColors r, NamazProvider provider) {
    int userXp = provider.toplamXp;
    return Container(
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        border: Border.all(color: r.pasifRenk.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildLiderlikSatiri(r, "1", "Ahmet Y.", SeviyeServisi.unvanGetir(1450), 1450, isFirst: true),
          Divider(color: r.pasifRenk.withOpacity(0.2), height: 1),
          _buildLiderlikSatiri(r, "2", "Fatih T.", SeviyeServisi.unvanGetir(1240), 1240),
          Divider(color: r.pasifRenk.withOpacity(0.2), height: 1),
          _buildLiderlikSatiri(r, "3", "Sen", provider.mevcutUnvan, userXp, isMe: true),
          Divider(color: r.pasifRenk.withOpacity(0.2), height: 1),
          _buildLiderlikSatiri(r, "4", "Meryem K.", SeviyeServisi.unvanGetir(980), 980),
        ],
      ),
    );
  }

  Widget _buildLiderlikSatiri(AppThemeColors r, String sira, String isim, String unvan, int xp, {bool isFirst = false, bool isMe = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(12)),
      child: Row(
        children: [
          Container(
            width: Responsive.w(30),
            height: Responsive.w(30),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isFirst ? const Color(0xFFFFD700) : (isMe ? r.anaRenk : r.pasifRenk.withOpacity(0.2)),
            ),
            child: Text(
              sira,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: (isFirst || isMe) ? Colors.white : r.yaziRengi,
                fontSize: Responsive.sp(14),
              ),
            ),
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isim,
                  style: TextStyle(
                    fontWeight: isMe ? FontWeight.bold : FontWeight.w600,
                    color: isMe ? r.anaRenk : r.yaziRengi,
                    fontSize: Responsive.sp(14),
                  ),
                ),
                Text(
                  unvan,
                  style: TextStyle(
                    color: r.yaziRengi.withOpacity(0.5),
                    fontSize: Responsive.sp(11),
                  ),
                ),
              ],
            ),
          ),
          Text(
            "$xp XP",
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isFirst ? const Color(0xFFD4AF37) : r.yaziRengi,
              fontSize: Responsive.sp(14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArkadasListesi(BuildContext context, AppThemeColors r) {
    return Column(
      children: [
        _buildArkadasKarti(r, "Enes G.", "Online", 5),
        _buildArkadasKarti(r, "Fatma Ç.", "2 Saat Önce", 3),
        _buildArkadasKarti(r, "Mehmet K.", "Dün Görüldü", 1),
      ],
    );
  }

  Widget _buildArkadasKarti(AppThemeColors r, String isim, String durum, int kilinan) {
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(12)),
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(12)),
        border: Border.all(color: r.pasifRenk.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: r.pasifRenk.withOpacity(0.2),
            child: Icon(Icons.person, color: r.yaziRengi.withOpacity(0.5)),
          ),
          SizedBox(width: Responsive.w(12)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isim, style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
                Text(durum, style: TextStyle(color: durum == "Online" ? r.aktifYesil : r.yaziRengi.withOpacity(0.5), fontSize: Responsive.sp(10))),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(10), vertical: Responsive.h(4)),
            decoration: BoxDecoration(
              color: kilinan == 5 ? r.aktifYesil.withOpacity(0.1) : r.anaRenk.withOpacity(0.1),
              borderRadius: BorderRadius.circular(Responsive.w(10)),
            ),
            child: Text(
              "$kilinan/5 Vakit",
              style: TextStyle(
                color: kilinan == 5 ? r.aktifYesil : r.anaRenk,
                fontWeight: FontWeight.bold,
                fontSize: Responsive.sp(11),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
