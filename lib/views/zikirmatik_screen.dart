import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:provider/provider.dart';

import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../providers/theme_provider.dart';

class ZikirmatikScreen extends StatefulWidget {
  const ZikirmatikScreen({super.key});

  @override
  State<ZikirmatikScreen> createState() => _ZikirmatikScreenState();
}

class _ZikirmatikScreenState extends State<ZikirmatikScreen> {
  final AudioPlayer _audioPlayer = AudioPlayer();

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  void _zikirCek(NamazProvider provider) {
    HapticFeedback.mediumImpact(); // lightImpact yerine daha güçlü
    provider.zikirArtir();
    
    // Check if goal is reached
    if (provider.zikirSayaci > 0 && provider.zikirSayaci == provider.zikirHedefi) {
      // Hedef sesi çal (URL üzerinden örnek bir klik sesi)
      _audioPlayer.play(UrlSource('https://assets.mixkit.co/active_storage/sfx/2571/2571-preview.mp3'));
      HapticFeedback.mediumImpact();
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Hedefinize Ulaştınız: ${provider.zikirHedefi}"),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showOzelHedefDialog(BuildContext context, NamazProvider provider) {
    final TextEditingController _controller = TextEditingController();
    final tema = context.read<ThemeProvider>().aktifTema;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tema.kartRengi,
        title: Text("Özel Hedef", style: TextStyle(color: tema.yaziRengi)),
        content: TextField(
          controller: _controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: tema.yaziRengi),
          decoration: InputDecoration(
            hintText: "Örn: 500",
            hintStyle: TextStyle(color: tema.yaziRengi.withOpacity(0.5)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tema.anaRenk)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tema.anaRenk)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("İptal", style: TextStyle(color: tema.pasifRenk)),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(_controller.text);
              if (val != null && val > 0) {
                provider.zikirHedefBelirle(val);
                Navigator.pop(ctx);
              }
            },
            child: Text("Kaydet", style: TextStyle(color: tema.anaRenk)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final tema = context.watch<ThemeProvider>().aktifTema;

    double progress = provider.zikirHedefi > 0 
        ? (provider.zikirSayaci / provider.zikirHedefi).clamp(0.0, 1.0) 
        : 0.0;

    return Scaffold(
      backgroundColor: tema.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tema.yaziRengi),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Zikirmatik",
          style: TextStyle(
            color: tema.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(22),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Sıfırlamak için basılı tutun',
            icon: Icon(Icons.refresh_rounded, color: tema.yaziRengi),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Sıfırlamak için ikona basılı tutun."),
                  backgroundColor: tema.pasifRenk,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            onLongPress: () {
              HapticFeedback.vibrate(); // Daha uzun bir titreşim
              provider.zikirSifirla();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text("Sayaç sıfırlandı."),
                  backgroundColor: tema.anaRenk,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(height: Responsive.h(20)),
            // Hedef Butonları
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
              child: Row(
                children: [
                  _buildHedefBtn(tema, provider, 33),
                  _buildHedefBtn(tema, provider, 99),
                  _buildHedefBtn(tema, provider, 100),
                  _buildHedefBtn(tema, provider, 1000),
                  _buildOzelHedefBtn(tema, provider),
                ],
              ),
            ),
            
            SizedBox(height: Responsive.h(20)),
            
            // Xp Rozeti
            if (provider.zikirXpKazanilan > 0)
              Container(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(Responsive.w(20)),
                  border: Border.all(color: Colors.amber.withOpacity(0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, color: Colors.amber, size: Responsive.w(20)),
                    SizedBox(width: Responsive.w(6)),
                    Text(
                      "+${provider.zikirXpKazanilan} Toplam Zikir XP",
                      style: TextStyle(
                        color: Colors.amber, 
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.sp(14),
                      ),
                    ),
                  ],
                ),
              ),

            Expanded(
              child: Center(
                child: GestureDetector(
                  onTap: () => _zikirCek(provider),
                  child: Container(
                    width: Responsive.w(280),
                    height: Responsive.w(280),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: tema.kartRengi,
                      boxShadow: [
                        BoxShadow(
                          color: tema.anaRenk.withOpacity(0.15),
                          blurRadius: 30,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: Responsive.w(250),
                          height: Responsive.w(250),
                          child: CircularProgressIndicator(
                            value: progress,
                            strokeWidth: Responsive.w(12),
                            backgroundColor: tema.anaRenk.withOpacity(0.1),
                            valueColor: AlwaysStoppedAnimation<Color>(tema.anaRenk),
                          ),
                        ),
                        // İç kısımdaki desen / dalgalanma efekti
                        Container(
                          width: Responsive.w(210),
                          height: Responsive.w(210),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [tema.anaRenk.withOpacity(0.05), tema.anaRenk.withOpacity(0.15)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                        ),
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${provider.zikirSayaci}",
                              style: TextStyle(
                                fontSize: Responsive.sp(60),
                                fontWeight: FontWeight.bold,
                                color: tema.yaziRengi,
                              ),
                            ),
                            Text(
                              "Hedef: ${provider.zikirHedefi}",
                              style: TextStyle(
                                fontSize: Responsive.sp(16),
                                color: tema.pasifRenk,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Zikir çektikçe dolan küçük gösterge
            Padding(
              padding: EdgeInsets.only(bottom: Responsive.h(40)),
              child: Text(
                "Sonraki XP'ye: ${10 - (provider.zikirSayaci % 10)} Zikir",
                style: TextStyle(
                  color: tema.yaziRengi.withOpacity(0.6),
                  fontSize: Responsive.sp(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHedefBtn(dynamic tema, NamazProvider provider, int hedef) {
    bool isSelected = provider.zikirHedefi == hedef;
    return GestureDetector(
      onTap: () => provider.zikirHedefBelirle(hedef),
      child: Container(
        margin: EdgeInsets.only(right: Responsive.w(10)),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(10)),
        decoration: BoxDecoration(
          color: isSelected ? tema.anaRenk : tema.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(color: isSelected ? tema.anaRenk : tema.anaRenk.withOpacity(0.3)),
        ),
        child: Text(
          "$hedef",
          style: TextStyle(
            color: isSelected ? Colors.white : tema.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(14),
          ),
        ),
      ),
    );
  }

  Widget _buildOzelHedefBtn(dynamic tema, NamazProvider provider) {
    bool isOzelSecili = ![33, 99, 100, 1000].contains(provider.zikirHedefi);
    return GestureDetector(
      onTap: () => _showOzelHedefDialog(context, provider),
      child: Container(
        margin: EdgeInsets.only(right: Responsive.w(10)),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(10)),
        decoration: BoxDecoration(
          color: isOzelSecili ? tema.anaRenk : tema.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(color: isOzelSecili ? tema.anaRenk : tema.anaRenk.withOpacity(0.3)),
        ),
        child: Text(
          isOzelSecili ? "${provider.zikirHedefi}" : "Özel",
          style: TextStyle(
            color: isOzelSecili ? Colors.white : tema.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(14),
          ),
        ),
      ),
    );
  }
}
