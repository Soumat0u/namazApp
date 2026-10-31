import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:vibration/vibration.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/dualar.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';

/// Namaz sonrası tesbihat: adım adım ilerleyen sayaç. Ekranın herhangi bir yerine dokunmak sayar.
class TesbihatScreen extends StatefulWidget {
  const TesbihatScreen({super.key});

  @override
  State<TesbihatScreen> createState() => _TesbihatScreenState();
}

class _TesbihatScreenState extends State<TesbihatScreen> {
  int _adim = 0;
  int _sayac = 0;

  bool get _bitti => _adim >= tesbihatAdimlari.length;

  void _say() {
    if (_bitti) return;
    final adim = tesbihatAdimlari[_adim];
    if (adim.adet > 1) context.read<NamazProvider>().tesbihatZikri();
    setState(() => _sayac++);
    if (_sayac >= adim.adet) {
      Vibration.vibrate(duration: 120);
      setState(() {
        _adim++;
        _sayac = 0;
      });
    }
  }

  void _bastanBasla() => setState(() {
        _adim = 0;
        _sayac = 0;
      });

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Tesbihat", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            tooltip: "Baştan başla",
            icon: Icon(Icons.restart_alt_rounded, color: r.anaRenk),
            onPressed: _bastanBasla,
          ),
        ],
      ),
      body: _bitti ? _bitisEkrani(r) : _sayacEkrani(r),
    );
  }

  Widget _sayacEkrani(AppThemeColors r) {
    final adim = tesbihatAdimlari[_adim];
    final tekSeferlik = adim.adet == 1;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: tekSeferlik ? null : _say,
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(20)),
        child: Column(
          children: [
            // Adım göstergesi
            Row(
              children: [
                for (int i = 0; i < tesbihatAdimlari.length; i++)
                  Expanded(
                    child: Container(
                      height: 5,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i <= _adim ? r.anaRenk : r.pasifRenk.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: Responsive.h(8)),
            Text("${_adim + 1} / ${tesbihatAdimlari.length}", style: TextStyle(color: r.pasifRenk)),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: Responsive.h(20)),
                    Text(adim.ad,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: Responsive.sp(22), fontWeight: FontWeight.w900, color: r.yaziRengi)),
                    SizedBox(height: Responsive.h(16)),
                    Text(
                      adim.arapcaMetin,
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                      style: TextStyle(fontSize: Responsive.sp(tekSeferlik ? 22 : 34), height: 1.8, color: r.yaziRengi),
                    ),
                    SizedBox(height: Responsive.h(12)),
                    if (adim.okunusMetin != adim.ad)
                      Text(adim.okunusMetin,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontStyle: FontStyle.italic, color: r.anaRenk, fontSize: Responsive.sp(14), height: 1.5)),
                    SizedBox(height: Responsive.h(8)),
                    Text(adim.mealMetin,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(13), height: 1.5)),
                  ],
                ),
              ),
            ),
            if (tekSeferlik)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _say,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: r.anaRenk,
                    padding: EdgeInsets.symmetric(vertical: Responsive.h(16)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text("Okudum, devam",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              )
            else ...[
              SizedBox(
                width: Responsive.w(160),
                height: Responsive.w(160),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: _sayac / adim.adet,
                        strokeWidth: 8,
                        backgroundColor: r.pasifRenk.withOpacity(0.15),
                        color: r.anaRenk,
                      ),
                    ),
                    Text("$_sayac / ${adim.adet}",
                        style: TextStyle(fontSize: Responsive.sp(28), fontWeight: FontWeight.w900, color: r.yaziRengi)),
                  ],
                ),
              ),
              SizedBox(height: Responsive.h(12)),
              Text("Saymak için ekrana dokun", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
            ],
            SizedBox(height: Responsive.h(12)),
          ],
        ),
      ),
    );
  }

  Widget _bitisEkrani(AppThemeColors r) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(24)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_rounded, color: r.anaRenk, size: 72),
            SizedBox(height: Responsive.h(16)),
            Text("Tesbihat tamamlandı",
                style: TextStyle(fontSize: Responsive.sp(20), fontWeight: FontWeight.w900, color: r.yaziRengi)),
            SizedBox(height: Responsive.h(8)),
            Text("Allah kabul etsin. Şimdi dilediğin gibi dua edebilirsin.",
                textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk)),
            SizedBox(height: Responsive.h(24)),
            OutlinedButton.icon(
              onPressed: _bastanBasla,
              icon: const Icon(Icons.restart_alt_rounded),
              label: const Text("Tekrar Başla"),
              style: OutlinedButton.styleFrom(foregroundColor: r.anaRenk),
            ),
          ],
        ),
      ),
    );
  }
}
