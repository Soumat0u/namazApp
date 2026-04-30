import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/utils/responsive.dart';
import '../providers/theme_provider.dart';
import 'qibla_screen.dart';
import 'zikirmatik_screen.dart'; // Eklendi
import 'settings_screen.dart'; // Ayarlar Eklendi
import 'kaza_screen.dart';


class AraclarSayfasi extends StatelessWidget {
  const AraclarSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final tema = context.watch<ThemeProvider>().aktifTema;

    return Scaffold(
      backgroundColor: tema.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "Araçlar",
          style: TextStyle(
            color: tema.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(22),
          ),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(Responsive.w(16)),
        child: GridView.count(
          crossAxisCount: 2, // 2 sütunlu grid
          crossAxisSpacing: Responsive.w(16),
          mainAxisSpacing: Responsive.h(16),
          childAspectRatio: 0.9,
          children: [
            _buildAracCard(
              context: context,
              icon: Icons.explore_rounded,
              title: "Kıble Pusulası",
              color: tema.anaRenk,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const QiblaScreen()),
                );
              },
            ),
            _buildAracCard(
              context: context,
              icon: Icons.track_changes_rounded,
              title: "Zikirmatik",
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ZikirmatikScreen()),
                );
              },
            ),
            _buildAracCard(
              context: context,
              icon: Icons.event_repeat_rounded,
              title: "Kaza Planlayıcı",
              color: Colors.orange,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const KazaTakipSayfasi()),
                );
              },
            ),
            _buildAracCard(
              context: context,
              icon: Icons.settings_rounded,
              title: "Ayarlar",
              color: Colors.blueGrey,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const AyarlarSayfasi()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showYakinda(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Bu özellik çok yakında eklenecektir!"),
        duration: Duration(seconds: 2),
      ),
    );
  }

  Widget _buildAracCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
    bool isSoon = false,
  }) {
    final tema = context.watch<ThemeProvider>().aktifTema;
    return Container(
      decoration: BoxDecoration(
        color: tema.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        border: Border.all(color: color.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            debugPrint("Tapped on: $title");
            onTap();
          },
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(Responsive.w(16)),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: Responsive.w(36)),
                    ),
                    SizedBox(height: Responsive.h(12)),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: tema.yaziRengi,
                        fontWeight: FontWeight.bold,
                        fontSize: Responsive.sp(14),
                      ),
                    ),
                  ],
                ),
              ),
              if (isSoon)
                Positioned(
                  top: Responsive.w(12),
                  right: Responsive.w(12),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(8), vertical: Responsive.h(4)),
                    decoration: BoxDecoration(
                      color: Colors.redAccent.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(Responsive.w(10)),
                    ),
                    child: Text(
                      "YAKINDA",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: Responsive.sp(9),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
