import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart'; // PAYLAŞ PAKETİ EKLENDİ
import '../core/constants/app_colors.dart';
import '../providers/namaz_provider.dart';

class AyarlarSayfasi extends StatefulWidget {
  const AyarlarSayfasi({super.key});

  @override
  State<AyarlarSayfasi> createState() => _AyarlarSayfasiState();
}

class _AyarlarSayfasiState extends State<AyarlarSayfasi> {
  bool _bildirimlerAcik = true;
  String _hesaplamaYontemi = "Diyanet İşleri (Türkiye)";

  @override
  void initState() {
    super.initState();
    _ayarlariYukle();
  }

  Future<void> _ayarlariYukle() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _bildirimlerAcik = prefs.getBool('bildirimler_acik') ?? true;
    });
  }

  Future<void> _ayarKaydet(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NamazProvider>();

    return Scaffold(
      backgroundColor: AppColors.arkaPlanRengi,
      appBar: AppBar(
        title: const Text(
          "Ayarlar",
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
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionHeader("Genel"),
          _buildSettingsCard([
            _buildSwitchTile(
              title: "Bildirimler",
              subtitle: "Vakit girdiğinde bildirim gönder",
              icon: Icons.notifications_active_outlined,
              value: _bildirimlerAcik,
              onChanged: (val) {
                setState(() => _bildirimlerAcik = val);
                _ayarKaydet('bildirimler_acik', val);
              },
            ),
            const Divider(height: 1),
            _buildInfoTile(
              title: "Kayıtlı Konum",
              subtitle: provider.konumBilgisi,
              icon: Icons.location_on_outlined,
              trailing: IconButton(
                icon: const Icon(Icons.refresh, color: AppColors.anaRenk),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Konum Ana Sayfa üzerinden güncellenir."),
                    ),
                  );
                },
              ),
            ),
          ]),

          const SizedBox(height: 20),
          _buildSectionHeader("Hesaplama"),
          _buildSettingsCard([
            _buildInfoTile(
              title: "Hesaplama Yöntemi",
              subtitle: _hesaplamaYontemi,
              icon: Icons.mosque_outlined,
              trailing: const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.pasifRenk,
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

          const SizedBox(height: 20),
          _buildSectionHeader("Uygulama"),
          _buildSettingsCard([
            _buildActionTile(
              title: "Bize Ulaşın",
              icon: Icons.mail_outline,
              onTap: () {},
            ),
            const Divider(height: 1),
            _buildActionTile(
              title: "Uygulamayı Paylaş",
              icon: Icons.share_outlined,
              onTap: () {
                // SHARE PLUS KULLANIMI
                Share.share(
                  'Namaz Vakti uygulamasını hemen indir ve namazlarını düzenli takip et! 📱 \n\nhttps://play.google.com/store/apps/details?id=com.example.namaz_app',
                );
              },
            ),
            const Divider(height: 1),
            _buildActionTile(
              title: "Verileri Sıfırla",
              icon: Icons.delete_outline,
              color: AppColors.kirmizi,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Emin misiniz?"),
                    content: const Text(
                      "Tüm kayıtlı namaz takibi verileriniz ve ayarlarınız silinecek.",
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          "İptal",
                          style: TextStyle(color: AppColors.pasifRenk),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          context.read<NamazProvider>().verileriSifirla();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Veriler sıfırlandı."),
                              backgroundColor: AppColors.anaRenk,
                            ),
                          );
                        },
                        child: const Text(
                          "Sil",
                          style: TextStyle(color: AppColors.kirmizi),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ]),
          const SizedBox(height: 30),
          Center(
            child: Text(
              "Namaz Vakti v1.0.0",
              style: TextStyle(
                color: AppColors.yaziRengi.withOpacity(0.5),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 50),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 10, bottom: 10),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: AppColors.yaziRengi.withOpacity(0.6),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.kartRengi,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.anaRenk.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.anaRenk),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.yaziRengi,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: AppColors.yaziRengi.withOpacity(0.6),
        ),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppColors.anaRenk,
      ),
    );
  }

  Widget _buildInfoTile({
    required String title,
    required String subtitle,
    required IconData icon,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppColors.pasifRenk.withOpacity(0.2),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.yaziRengi),
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: AppColors.yaziRengi,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.anaRenk,
          fontWeight: FontWeight.w500,
        ),
      ),
      trailing: trailing,
    );
  }

  Widget _buildActionTile({
    required String title,
    required IconData icon,
    required VoidCallback onTap,
    Color color = AppColors.yaziRengi,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.bold, color: color),
      ),
      trailing: const Icon(
        Icons.arrow_forward_ios,
        size: 16,
        color: AppColors.pasifRenk,
      ),
    );
  }
}
