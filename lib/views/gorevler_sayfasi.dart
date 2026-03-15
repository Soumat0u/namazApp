import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:confetti/confetti.dart'; 
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../models/gorev_model.dart';

class GorevlerSayfasi extends StatefulWidget {
  const GorevlerSayfasi({super.key});

  @override
  State<GorevlerSayfasi> createState() => _GorevlerSayfasiState();
}

class _GorevlerSayfasiState extends State<GorevlerSayfasi> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 2));
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NamazProvider>().gorevTamamlaById('z_tanisma');
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final provider = context.watch<NamazProvider>();

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Scaffold(
          backgroundColor: r.arkaPlanRengi,
          appBar: AppBar(
            backgroundColor: r.arkaPlanRengi,
            elevation: 0,
            title: Text(
              "GÖREV MERKEZİ",
              style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            centerTitle: true,
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(Responsive.w(16)),
            child: Column(
              children: [
                _buildSection(context, "GÜNLÜK GÖREVLER", GorevTipi.gunluk, provider),
                SizedBox(height: Responsive.h(24)),
                _buildSection(context, "HAFTALIK MARATON", GorevTipi.haftalik, provider),
                SizedBox(height: Responsive.h(24)),
                _buildSection(context, "BAŞARIMLAR", GorevTipi.zamansiz, provider),
              ],
            ),
          ),
        ),
        
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          colors: [
            r.anaRenk, 
            const Color(0xFFFFD700), // Altın Gold
            Colors.amber, 
            Colors.white, 
            Colors.orange
          ],
          numberOfParticles: 20,
          gravity: 0.1,
        ),
      ],
    );
  }

  Widget _buildSection(BuildContext context, String baslik, GorevTipi tip, NamazProvider provider) {
    final r = context.renkler;
    final gorevler = provider.gorevler.where((g) => g.tip == tip).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(baslik, style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(14))),
        SizedBox(height: Responsive.h(12)),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: gorevler.length,
          itemBuilder: (context, index) {
            final gorev = gorevler[index];
            return Container(
              margin: EdgeInsets.only(bottom: Responsive.h(12)),
              padding: EdgeInsets.all(Responsive.w(16)),
              decoration: BoxDecoration(
                color: r.kartRengi,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: gorev.tamamlandiMi ? r.aktifYesil.withOpacity(0.3) : Colors.transparent),
              ),
              child: Row(
                children: [
                  Icon(
                    gorev.odulAlindiMi ? Icons.check_circle_rounded : (gorev.tamamlandiMi ? Icons.stars_rounded : Icons.radio_button_off_rounded),
                    color: gorev.tamamlandiMi ? (gorev.odulAlindiMi ? r.pasifRenk : r.aktifYesil) : r.pasifRenk,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          gorev.baslik,
                          style: TextStyle(
                            color: gorev.odulAlindiMi ? r.yaziRengi.withOpacity(0.5) : r.yaziRengi,
                            fontWeight: FontWeight.bold,
                            decoration: gorev.odulAlindiMi ? TextDecoration.lineThrough : null,
                          ),
                        ),
                        Text(gorev.aciklama, style: TextStyle(color: r.yaziRengi.withOpacity(0.5), fontSize: Responsive.sp(11))),
                      ],
                    ),
                  ),
                  _buildRewardAction(provider, gorev, r),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildRewardAction(NamazProvider provider, Gorev gorev, dynamic r) {
    if (gorev.tamamlandiMi && !gorev.odulAlindiMi) {
      return ElevatedButton(
        onPressed: () {
          provider.oduluAl(gorev);
          _confettiController.play(); // 🔥 Konfeti burada tetikleniyor
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: r.anaRenk,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          elevation: 5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text("AL", style: TextStyle(fontWeight: FontWeight.bold)),
      );
    } else if (gorev.odulAlindiMi) {
      return Icon(Icons.done_all_rounded, color: r.aktifYesil, size: 22);
    } else {
      return Column(
        children: [
          Text("+${gorev.xpOdulu}", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
          Text("XP", style: TextStyle(color: r.anaRenk, fontSize: 10)),
        ],
      );
    }
  }
}