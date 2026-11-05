import '../core/utils/bildirim.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../core/utils/extensions.dart';
import '../providers/namaz_provider.dart';
import '../providers/theme_provider.dart';
import 'widgets/sayfa_arka_plani.dart';
import 'widgets/sehir_secici.dart';
import 'widgets/destek_ol.dart';
import 'widgets/ayar_pencereleri.dart';

class AyarlarSayfasi extends StatelessWidget {
  const AyarlarSayfasi({super.key});

  final String _hesaplamaYontemi = "Diyanet İşleri (Türkiye)";


  /// Hesap silme: ne silineceği açıkça yazılır, şifreli hesaplarda şifre istenir
  Future<void> _hesabiSilOnayi(BuildContext context) async {
    final r = context.renklerOku;
    final provider = context.read<NamazProvider>();
    final sifreli = provider.girisYontemi == 'password';
    final sifre = TextEditingController();
    String? hata;
    bool siliniyor = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, yenile) => AlertDialog(
          backgroundColor: r.kartRengi,
          title: Text("Hesabımı Sil", style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Bu işlem geri alınamaz. Şunlar kalıcı olarak silinir:\n\n"
                "• Profilin, kullanıcı adın ve fotoğrafın\n"
                "• Arkadaşlık bağların ve bildirimlerin\n"
                "• Paylaştığın dualar ve hikayelerin\n"
                "• Kurduğun ortak hatimler\n"
                "• Bu telefondaki namaz, kaza ve oruç kayıtların",
                style: TextStyle(color: r.yaziRengi.withOpacity(0.8), fontSize: 13, height: 1.4),
              ),
              if (sifreli) ...[
                const SizedBox(height: 14),
                TextField(
                  controller: sifre,
                  obscureText: true,
                  style: TextStyle(color: r.yaziRengi),
                  decoration: InputDecoration(
                    labelText: "Onaylamak için şifren",
                    labelStyle: TextStyle(color: r.pasifRenk),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 10),
                Text("Onay için hesabını bir kez daha seçmen istenecek.",
                    style: TextStyle(color: r.pasifRenk, fontSize: 12)),
              ],
              if (hata != null) ...[
                const SizedBox(height: 10),
                Text(hata!, style: TextStyle(color: Colors.red.shade600, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: siliniyor ? null : () => Navigator.pop(ctx),
              child: Text("Vazgeç", style: TextStyle(color: r.pasifRenk)),
            ),
            TextButton(
              onPressed: siliniyor
                  ? null
                  : () async {
                      yenile(() {
                        siliniyor = true;
                        hata = null;
                      });
                      final sonuc = await provider.hesabiSil(sifre: sifreli ? sifre.text : null);
                      if (!ctx.mounted) return;
                      if (sonuc != null) {
                        yenile(() {
                          siliniyor = false;
                          hata = sonuc;
                        });
                        return;
                      }
                      Navigator.of(ctx, rootNavigator: true).popUntil((route) => route.isFirst);
                    },
              child: siliniyor
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text("Kalıcı Olarak Sil",
                      style: TextStyle(color: Colors.red.shade600, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
    sifre.dispose();
  }

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
            _buildActionTile(
              r,
              title: "Bildirim Sesi",
              icon: Icons.music_note_outlined,
              onTap: () => _showSoundPicker(context, provider, r),
            ),
            const Divider(height: 1),
            _buildInfoTile(
              r,
              title: provider.seciliSehir.isEmpty ? "Konum (GPS)" : "Konum (Seçilen Şehir)",
              subtitle: provider.konumBilgisi.trBuyuk,
              icon: Icons.location_on_outlined,
              onTap: () => sehirSeciciGoster(context),
              trailing: IconButton(
                icon: Icon(
                  Icons.refresh,
                  color: r.anaRenk,
                  size: Responsive.w(20),
                ),
                onPressed: () {
                  Bildirim.snackBar(
                    const SnackBar(
                      content: Text("Vakitler güncelleniyor..."),
                      duration: Duration(seconds: 1),
                    ),
                  );
                  provider.konumVeApiIstegi(kullaniciTetikledi: true);
                },
              ),
            ),
          ]),
          SizedBox(height: Responsive.h(16)),
          _buildSectionHeader(r, "Ramazan"),
          _buildSettingsCard(r, [
            // Yalnızca Ramazan'da (ya da Ramazan dışında açık kalmışsa, kapatılabilsin diye)
            if (provider.ramazanda || provider.orucModu) ...[
              _buildSwitchTile(
                r,
                title: "Sahur ve iftar bildirimleri",
                subtitle: provider.bildirimlerAcik
                    ? "İmsaktan 45 dakika önce sahur, akşam vaktinde iftar bildirimi"
                    : "Önce yukarıdan bildirimleri açın",
                icon: Icons.notifications_active_outlined,
                value: provider.orucModu,
                onChanged: provider.bildirimlerAcik ? provider.orucModuDegistir : (_) {},
              ),
              const Divider(height: 1),
            ],
            _buildSwitchTile(
              r,
              title: "Ramazan görünümünü önizle",
              subtitle: provider.hicriGunler.values.any((h) => h.ay == 9) && !provider.ramazanOnizleme
                  ? "Ramazan'da ana sayfa kendiliğinden değişir"
                  : "Ramazan dışında ana sayfadaki Ramazan kartını dener (örnek: 12. gün)",
              icon: Icons.nightlight_round,
              value: provider.ramazanOnizleme,
              onChanged: provider.ramazanOnizlemeDegistir,
            ),
          ]),
          SizedBox(height: Responsive.h(16)),
          _buildSectionHeader(r, "Görünüm"),
          _buildThemeSelector(r, themeProvider),
          SizedBox(height: Responsive.h(12)),
          _buildArkaPlanSecici(r, themeProvider),
          SizedBox(height: Responsive.h(12)),
          _buildYaziBoyutuSecici(r, themeProvider),
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
              onTap: () => hesaplamaBilgisiGoster(context, r),
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
          SizedBox(height: Responsive.h(8)),
          _buildSettingsCard(r, [
            _buildActionTile(
              r,
              title: "Hesabımı Sil",
              icon: Icons.delete_forever_rounded,
              color: Colors.red.shade600,
              onTap: () => _hesabiSilOnayi(context),
            ),
          ]),
          SizedBox(height: Responsive.h(16)),
          _buildSectionHeader(r, "Uygulama"),
          _buildSettingsCard(r, [
            if (DestekBilgisi.hazir) ...[
              _buildActionTile(
                r,
                title: "Bize Destek Ol",
                icon: Icons.volunteer_activism_outlined,
                onTap: () => destekOlGoster(context, r),
              ),
              const Divider(height: 1),
            ],
            _buildActionTile(
              r,
              title: "Bize Ulaşın",
              icon: Icons.mail_outline,
              onTap: bizeUlasin,
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
                          Bildirim.snackBar(
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

  /// Yazı boyutu: dört seçenek, canlı örnek metinle
  Widget _buildYaziBoyutuSecici(AppThemeColors r, ThemeProvider themeProvider) {
    final secenekler = ThemeProvider.yaziBoyutlari;
    final secili = secenekler.indexWhere((s) => s.$1 == themeProvider.yaziOlcegi).clamp(0, secenekler.length - 1);
    return Container(
      padding: EdgeInsets.all(Responsive.w(14)),
      decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(Responsive.w(16))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.format_size_rounded, color: r.anaRenk, size: Responsive.w(20)),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: Text("Yazı Boyutu",
                    style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi, fontSize: Responsive.sp(14))),
              ),
              Text(secenekler[secili].$2,
                  style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
            ],
          ),
          SizedBox(height: Responsive.h(10)),
          Text(
            "Vakit girince bildirim gelir; kıldığın vakti işaretlemeyi unutma.",
            style: TextStyle(color: r.yaziRengi.withOpacity(0.8), fontSize: Responsive.sp(13)),
          ),
          SizedBox(height: Responsive.h(6)),
          Row(
            children: [
              Text("A", style: TextStyle(color: r.pasifRenk, fontSize: 13, fontWeight: FontWeight.bold)),
              Expanded(
                child: Slider(
                  value: secili.toDouble(),
                  min: 0,
                  max: (secenekler.length - 1).toDouble(),
                  divisions: secenekler.length - 1,
                  activeColor: r.anaRenk,
                  inactiveColor: r.pasifRenk.withOpacity(0.2),
                  onChanged: (v) => themeProvider.yaziOlcegiDegistir(secenekler[v.round()].$1),
                ),
              ),
              Text("A", style: TextStyle(color: r.pasifRenk, fontSize: 22, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  /// Arka plan seçici: her seçenek gerçek arka planın canlı, küçültülmüş önizlemesiyle gösterilir
  Widget _buildArkaPlanSecici(AppThemeColors r, ThemeProvider themeProvider) {
    return Builder(builder: (context) {
      final vakitTemasi = context.select<NamazProvider, String>((p) => p.vaktinTemasi);
      final koyu = Theme.of(context).brightness == Brightness.dark;
      final secili = themeProvider.arkaPlanModu;
      return Container(
        padding: EdgeInsets.fromLTRB(Responsive.w(14), Responsive.w(14), 0, Responsive.w(14)),
        decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(Responsive.w(16))),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wallpaper_rounded, color: r.anaRenk, size: Responsive.w(20)),
                SizedBox(width: Responsive.w(8)),
                Text("Arka Plan",
                    style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi, fontSize: Responsive.sp(14))),
                const Spacer(),
                Padding(
                  padding: EdgeInsets.only(right: Responsive.w(14)),
                  child: Text(secili.ad,
                      style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(12))),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(12)),
            SizedBox(
              height: Responsive.h(178),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.only(right: Responsive.w(14)),
                itemCount: ArkaPlanModu.values.length,
                separatorBuilder: (_, _) => SizedBox(width: Responsive.w(10)),
                itemBuilder: (context, i) {
                  final mod = ArkaPlanModu.values[i];
                  final aktif = mod == secili;
                  return GestureDetector(
                    onTap: () => themeProvider.arkaPlanModuDegistir(mod),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: Responsive.w(84),
                          height: Responsive.h(146),
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: aktif ? r.anaRenk : r.pasifRenk.withOpacity(0.2),
                              width: aktif ? 2.5 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(13),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Telefon ekranı ölçüsünde çizilip küçültülür: desenler gerçek boyutta görünür
                                FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: 360,
                                    height: 640,
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        SayfaArkaPlani(
                                          mod: mod,
                                          vakitTemasi: vakitTemasi,
                                          zemin: r.arkaPlanRengi,
                                          vurgu: r.anaRenk,
                                          koyuTema: koyu,
                                        ),
                                        // Örnek kartlar: arka planın içerikle nasıl duracağı
                                        Padding(
                                          padding: const EdgeInsets.fromLTRB(24, 70, 24, 0),
                                          child: Column(
                                            children: [
                                              for (final y in const [90.0, 150.0, 70.0]) ...[
                                                Container(
                                                  height: y,
                                                  decoration: BoxDecoration(
                                                    color: r.kartRengi,
                                                    borderRadius: BorderRadius.circular(22),
                                                  ),
                                                ),
                                                const SizedBox(height: 18),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (aktif)
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: Container(
                                      padding: const EdgeInsets.all(2),
                                      decoration: BoxDecoration(color: r.anaRenk, shape: BoxShape.circle),
                                      child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: Responsive.h(8)),
                        Text(
                          mod.ad,
                          style: TextStyle(
                            fontSize: Responsive.sp(12),
                            fontWeight: aktif ? FontWeight.w800 : FontWeight.w600,
                            color: aktif ? r.anaRenk : r.yaziRengi.withOpacity(0.75),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: Responsive.h(10)),
            Padding(
              padding: EdgeInsets.only(right: Responsive.w(14)),
              child: Text(secili.aciklama, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
            ),
          ],
        ),
      );
    });
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
              _ThemeGroupWidget(
                isim: 'Gül',
                lightId: 'gul',
                darkId: 'gul_karanlik',
                baseLightColor: const Color(0xFFD6457A),
                baseDarkColor: const Color(0xFFF48FB1),
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

  void _showSoundPicker(BuildContext context, NamazProvider provider, AppThemeColors r) {
    String tempSecili = provider.bildirimSesi;

    showModalBottomSheet(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final List<Map<String, String>> sesler = [
              {"id": "varsayilan", "isim": "Sistem Varsayılanı", "icon": "settings_suggest"},
              {"id": "ezan", "isim": "Ezan", "icon": "mosque"},
              {"id": "ney", "isim": "Ney Sesi", "icon": "music_note"},
              {"id": "birds", "isim": "Kuş Sesleri", "icon": "nature"},
              {"id": "su", "isim": "Su Sesi", "icon": "water_drop"},
              {"id": "ozel", "isim": "Özel Ses Dosyası...", "icon": "library_music"},
            ];

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(16),
                  Responsive.h(16),
                  Responsive.w(16),
                  Responsive.h(24), // Alt kısım için güvenli boşluk
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Handle Bar
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: r.pasifRenk.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    SizedBox(height: Responsive.h(16)),
                    Text(
                      "Bildirim Sesi Seçin",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.sp(18),
                        color: r.yaziRengi,
                      ),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    Text(
                      "Seçtiğiniz ses çalacaktır, onaylamak için Tamam'a basın.",
                      style: TextStyle(
                        fontSize: Responsive.sp(12),
                        color: r.yaziRengi.withOpacity(0.5),
                      ),
                    ),
                    SizedBox(height: Responsive.h(20)),
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: sesler.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final ses = sesler[index];
                          final isSelected = tempSecili == ses["id"];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                setModalState(() => tempSecili = ses["id"]!);
                                if (ses["id"] == "ozel") {
                                  provider.ozelSesSec();
                                } else {
                                  provider.sesOnizlemeCal(ses["id"]!, null);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.all(Responsive.w(12)),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected ? r.anaRenk : r.pasifRenk.withOpacity(0.2),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  color: isSelected ? r.anaRenk.withOpacity(0.05) : Colors.transparent,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isSelected ? r.anaRenk : r.pasifRenk.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isSelected ? Icons.check_rounded : Icons.music_note_rounded,
                                        color: isSelected ? Colors.white : r.pasifRenk,
                                        size: 18,
                                      ),
                                    ),
                                    SizedBox(width: Responsive.w(12)),
                                    Expanded(
                                      child: Text(
                                        ses["isim"]!,
                                        style: TextStyle(
                                          color: r.yaziRengi,
                                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                          fontSize: Responsive.sp(14),
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(Icons.volume_up_rounded, color: r.anaRenk, size: 20),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: Responsive.h(24)),
                    SizedBox(
                      width: double.infinity,
                      height: Responsive.h(50),
                      child: ElevatedButton(
                        onPressed: () {
                          provider.bildirimSesiDegistir(tempSecili);
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: r.anaRenk,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          "TAMAM",
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: Responsive.sp(14),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: Responsive.h(10)), // Ekstra güvenli alan
                  ],
                ),
              ),
            );
          },
        );
      },
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
    required this.isim,
    required this.lightId,
    required this.darkId,
    required this.baseLightColor,
    required this.baseDarkColor,
    required this.themeProvider,
    required this.r,
  });

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

