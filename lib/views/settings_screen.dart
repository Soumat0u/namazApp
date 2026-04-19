import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../providers/theme_provider.dart';

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  final String _hesaplamaYontemi = "Diyanet İşleri (Türkiye)";


  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final r = context.renkler;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: r.yaziRengi),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Ayarlar",
          style: TextStyle(
            color: r.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(18),
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(Responsive.w(16)),
        children: [
          _buildSectionHeader(r, "Genel"),
          _buildSettingsCard(r, [
            _buildSwitchTile(
              r,
              title: "Bildirimler",
              subtitle: "Vakit girdiğinde bildirim gönder",
              icon: Icons.notifications_active_outlined,
              value: provider.bildirimlerAcik, 
              onChanged: (val) => provider.bildirimAyariDegistir(val),
            ),
            const Divider(height: 1),
            _buildInfoTile(
              r,
              title: "Kayıtlı Konum",
              subtitle: provider.konumBilgisi.toUpperCase(),
              icon: Icons.location_on_outlined,
              trailing: IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: r.anaRenk,
                  size: Responsive.w(20),
                ),

                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Konum güncelleme için Ana Sayfa'yı yenileyin.",
                      ),
                    ),
                  );
                },
              ),
            ),
          ]),
          SizedBox(height: Responsive.h(16)),
          _buildSectionHeader(r, "Görünüm"),
          _buildThemeSelector(r, themeProvider),
          SizedBox(height: Responsive.h(16)),
          _buildSectionHeader(r, "Hesaplama"),
          _buildSettingsCard(r, [
            _buildInfoTile(
              r,
              title: "Hesaplama Yöntemi",
              subtitle: _hesaplamaYontemi,
              icon: Icons.mosque_outlined,
              trailing: Icon(
                Icons.arrow_forward_ios,
                size: Responsive.w(14),
                color: r.pasifRenk,
              ),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Şu an sadece Diyanet metodu aktiftir."),
                  ),
                );
              },
            ),
          ]),
          SizedBox(height: Responsive.h(16)),
          _buildSectionHeader(r, "Hesap"),
          _buildSettingsCard(r, [
            _buildActionTile(
              r,
              title: "Çıkış Yap",
              icon: Icons.logout_rounded,
              color: Colors.orange.shade700,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: r.kartRengi,
                    title: Text("Çıkış Yap", style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(16))),
                    content: Text(
                      "Hesabınızdan çıkış yapmak istediğinize emin misiniz?",
                      style: TextStyle(color: r.yaziRengi.withOpacity(0.7), fontSize: Responsive.sp(14)),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: Text("İptal", style: TextStyle(color: r.pasifRenk))),
                      TextButton(
                        onPressed: () {
                          final provider = context.read<NamazProvider>();
                          
                          // Tüm pencereleri ve sayfaları kapatıp en ana Safyaya dön
                          Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);

                          // Geçiş animasyonunun tamamlanmasını bekle, ardından oturumu kapat.
                          Future.delayed(const Duration(milliseconds: 400), () {
                            provider.cikisYap();
                          });
                        },
                        child: Text("Çıkış Yap", style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
          SizedBox(height: Responsive.h(16)),
          _buildSectionHeader(r, "Uygulama"),
          _buildSettingsCard(r, [
            _buildActionTile(
              r,
              title: "Bize Ulaşın",
              icon: Icons.mail_outline,
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildActionTile(
              r,
              title: "Uygulamayı Paylaş",
              icon: Icons.share_outlined,
              onTap: () {
                Share.share(
                  'Namaz Vakti uygulamasını indir! \n\nhttps://play.google.com/store/apps/details?id=com.example.namaz_app',
                );
              },
            ),
            const Divider(height: 1),

            
            const Divider(height: 1),

            _buildActionTile(
              r,
              title: "Verileri Sıfırla",
              icon: Icons.delete_outline,
              color: r.kirmizi,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: r.kartRengi,
                    title: Text(
                      "Emin misiniz?",
                      style: TextStyle(
                        color: r.yaziRengi,
                        fontSize: Responsive.sp(16),
                      ),
                    ),
                    content: Text(
                      "Tüm kayıtlı namaz takibi verileriniz ve ayarlarınız silinecek.",
                      style: TextStyle(
                        color: r.yaziRengi.withOpacity(0.7),
                        fontSize: Responsive.sp(14),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(
                          "İptal",
                          style: TextStyle(color: r.pasifRenk),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          context.read<NamazProvider>().verileriSifirla();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text("Veriler sıfırlandı."),
                              backgroundColor: r.anaRenk,
                            ),
                          );
                        },
                        child: Text("Sil", style: TextStyle(color: r.kirmizi)),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
          SizedBox(height: Responsive.h(24)),
          Center(
            child: Text(
              "Namaz Vakti v1.0.0",
              style: TextStyle(
                color: r.yaziRengi.withOpacity(0.5),
                fontSize: Responsive.sp(11),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(40)),
        ],
      ),
    );
  }

  Widget _buildThemeSelector(AppThemeColors r, ThemeProvider themeProvider) {
    return Container(
      padding: EdgeInsets.all(Responsive.w(14)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(Responsive.w(7)),
                decoration: BoxDecoration(
                  color: r.anaRenk.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.palette_outlined,
                  color: r.anaRenk,
                  size: Responsive.w(20),
                ),
              ),
              SizedBox(width: Responsive.w(10)),
              Text(
                "Tema Seçimi",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: Responsive.sp(15),
                  color: r.yaziRengi,
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(14)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ThemeGroupWidget(
                isim: 'Varsayılan',
                lightId: 'varsayilan',
                darkId: 'karanlik',
                baseLightColor: const Color(0xFFE67E22),
                baseDarkColor: const Color(0xFFFFB74D),
                themeProvider: themeProvider,
                r: r,
              ),
              _ThemeGroupWidget(
                isim: 'Zümrüt',
                lightId: 'zumrut',
                darkId: 'zumrut_karanlik',
                baseLightColor: const Color(0xFF2E7D32),
                baseDarkColor: const Color(0xFF4CAF50),
                themeProvider: themeProvider,
                r: r,
              ),
              _ThemeGroupWidget(
                isim: 'Okyanus',
                lightId: 'okyanus',
                darkId: 'okyanus_karanlik',
                baseLightColor: const Color(0xFF1565C0),
                baseDarkColor: const Color(0xFF42A5F5),
                themeProvider: themeProvider,
                r: r,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(AppThemeColors r, String title) {
    return Padding(
      padding: EdgeInsets.only(left: Responsive.w(8), bottom: Responsive.h(8)),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: r.yaziRengi.withOpacity(0.6),
          fontSize: Responsive.sp(12),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(AppThemeColors r, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile(
    AppThemeColors r, {
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: EdgeInsets.all(Responsive.w(7)),
        decoration: BoxDecoration(
          color: r.anaRenk.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: r.anaRenk, size: Responsive.w(20)),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: r.yaziRengi,
          fontSize: Responsive.sp(14),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: Responsive.sp(11),
          color: r.yaziRengi.withOpacity(0.6),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeThumbColor: r.anaRenk,
      ),
    );
  }

  Widget _buildInfoTile(
    AppThemeColors r, {
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: r.yaziRengi),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: r.yaziRengi,
          fontSize: Responsive.sp(14),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: Responsive.sp(12),
          color: r.anaRenk,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
    );
  }

  Widget _buildActionTile(
    AppThemeColors r, {
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    final c = color ?? r.yaziRengi;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: c,
          fontSize: Responsive.sp(14),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios,
        size: Responsive.w(14),
        color: r.pasifRenk,
      ),
    );
  }
}

class _ThemeGroupWidget extends StatelessWidget {
  final String isim;
  final String lightId;
  final String darkId;
  final Color baseLightColor;
  final Color baseDarkColor;
  final ThemeProvider themeProvider;
  final AppThemeColors r;

  const _ThemeGroupWidget({
    Key? key,
    required this.isim,
    required this.lightId,
    required this.darkId,
    required this.baseLightColor,
    required this.baseDarkColor,
    required this.themeProvider,
    required this.r,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final activeId = themeProvider.aktifTema.id;
    final bool isSelected = activeId == lightId || activeId == darkId;
    final bool isDark = activeId == darkId;
    
    final Color currentColor = isDark ? baseDarkColor : baseLightColor;

    final double circleSize = Responsive.w(44);
    final double expandedHeight = circleSize * 2.3;

    return GestureDetector(
      onTap: () {
        if (!isSelected) {
          // Eğer şu anki tema karanlık moddaysa, yeni seçilen de karanlık mod başlasın
          final isCurrentlyDark = themeProvider.aktifTema.brightness == Brightness.dark;
          themeProvider.temaDegistir(isCurrentlyDark ? darkId : lightId);
        } else {
          // Zaten seçiliyse moda geçiş yap
          themeProvider.temaDegistir(isDark ? lightId : darkId);
        }
      },
      onVerticalDragEnd: (details) {
        if (!isSelected) return;
        if (details.primaryVelocity != null) {
          if (details.primaryVelocity! > 0 && !isDark) {
            // Aşağı kaydırıldı, karanlık moda geç
            themeProvider.temaDegistir(darkId);
          } else if (details.primaryVelocity! < 0 && isDark) {
            // Yukarı kaydırıldı, aydınlık moda geç
            themeProvider.temaDegistir(lightId);
          }
        }
      },
      child: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: circleSize,
            height: isSelected ? expandedHeight : circleSize,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(circleSize / 2),
              border: isSelected
                  ? Border.all(color: currentColor, width: 2.5)
                  : Border.all(color: Colors.transparent, width: 2.5),
              color: isSelected 
                     ? (isDark ? const Color(0xFF1E1E1E) : Colors.white)
                     : Colors.transparent,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: currentColor.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // Arkaplanda ikonlar
                if (isSelected) ...[
                  Positioned(
                    top: Responsive.w(8),
                    left: 0,
                    right: 0,
                    child: Icon(Icons.wb_sunny_rounded, color: Colors.blueGrey.shade300, size: Responsive.w(18)),
                  ),
                  Positioned(
                    bottom: Responsive.w(8),
                    left: 0,
                    right: 0,
                    child: Icon(Icons.nightlight_round, color: Colors.blueGrey.shade300, size: Responsive.w(18)),
                  ),
                ],
                // Hareketli buton / Normal buton
                AnimatedAlign(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  alignment: isSelected 
                             ? (isDark ? Alignment.bottomCenter : Alignment.topCenter)
                             : Alignment.center,
                  child: Container(
                    width: circleSize - (isSelected ? 5 : 0),
                    height: circleSize - (isSelected ? 5 : 0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: isDark 
                            ? [const Color(0xFF1E1E1E), baseDarkColor] 
                            : [const Color(0xFFFFFFFF), baseLightColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check,
                            color: Colors.white,
                            size: 20,
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(8)),
          Text(
            isim,
            style: TextStyle(
              fontSize: Responsive.sp(11),
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              color: isSelected
                  ? currentColor
                  : r.yaziRengi.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }
}

