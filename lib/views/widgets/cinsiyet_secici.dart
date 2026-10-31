import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../providers/namaz_provider.dart';

/// Kadın / Erkek seçimi (kayıt formu, ayarlar ve tek seferlik seçim ekranında kullanılır)
class CinsiyetSecici extends StatelessWidget {
  final String? secili;
  final ValueChanged<String> onSecildi;

  const CinsiyetSecici({super.key, required this.secili, required this.onSecildi});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: _secenek(context, 'kadin', 'Kadın', Icons.female_rounded)),
        SizedBox(width: Responsive.w(12)),
        Expanded(child: _secenek(context, 'erkek', 'Erkek', Icons.male_rounded)),
      ],
    );
  }

  Widget _secenek(BuildContext context, String deger, String etiket, IconData ikon) {
    final r = context.renkler;
    final aktif = secili == deger;
    return InkWell(
      onTap: () => onSecildi(deger),
      borderRadius: BorderRadius.circular(15),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(vertical: Responsive.h(14)),
        decoration: BoxDecoration(
          color: aktif ? r.anaRenk.withOpacity(0.15) : r.kartRengi,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: aktif ? r.anaRenk : r.pasifRenk.withOpacity(0.2), width: aktif ? 1.5 : 1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(ikon, color: aktif ? r.anaRenk : r.pasifRenk),
            SizedBox(width: Responsive.w(6)),
            Text(etiket,
                style: TextStyle(fontWeight: FontWeight.bold, color: aktif ? r.anaRenk : r.yaziRengi)),
          ],
        ),
      ),
    );
  }
}

/// Google ile giren veya eski sürümden gelen, cinsiyeti bilinmeyen kullanıcılara bir kez gösterilir
class CinsiyetSecimEkrani extends StatefulWidget {
  const CinsiyetSecimEkrani({super.key});

  @override
  State<CinsiyetSecimEkrani> createState() => _CinsiyetSecimEkraniState();
}

class _CinsiyetSecimEkraniState extends State<CinsiyetSecimEkrani> {
  String? _secili;

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(Responsive.w(24)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_rounded, size: 56, color: r.anaRenk),
              SizedBox(height: Responsive.h(16)),
              Text("Bir şey daha",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: Responsive.sp(22), fontWeight: FontWeight.w900, color: r.yaziRengi)),
              SizedBox(height: Responsive.h(8)),
              Text(
                "Kaza hesabı gibi özellikleri sana göre ayarlayabilmemiz için cinsiyetini seç.",
                textAlign: TextAlign.center,
                style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(13)),
              ),
              SizedBox(height: Responsive.h(24)),
              CinsiyetSecici(secili: _secili, onSecildi: (c) => setState(() => _secili = c)),
              SizedBox(height: Responsive.h(24)),
              ElevatedButton(
                onPressed: _secili == null ? null : () => context.read<NamazProvider>().cinsiyetAyarla(_secili!),
                style: ElevatedButton.styleFrom(
                  backgroundColor: r.anaRenk,
                  padding: EdgeInsets.symmetric(vertical: Responsive.h(16)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: const Text("Devam Et", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
