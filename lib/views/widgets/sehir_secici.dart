import '../../core/utils/bildirim.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/iller.dart';
import '../../core/utils/extensions.dart';
import '../../core/utils/responsive.dart';
import '../../providers/namaz_provider.dart';

const String _gpsSecimi = '__gps__';

/// İl seçim penceresini açar. Seçim yapılırsa vakitler o ilin merkezine göre alınır;
/// "Konumumu kullan" seçilirse GPS'e dönülür.
Future<void> sehirSeciciGoster(BuildContext context) async {
  final provider = context.read<NamazProvider>();
  final r = context.renklerOku;

  final secim = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: r.arkaPlanRengi,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _SehirListesi(seciliSehir: provider.seciliSehir, r: r),
  );
  if (secim == null || !context.mounted) return;

  Bildirim.snackBar(
    SnackBar(
      content: Text(secim == _gpsSecimi ? 'Konum alınıyor...' : '$secim vakitleri alınıyor...'),
      duration: const Duration(seconds: 1),
    ),
  );
  final hata = await provider.sehirSec(secim == _gpsSecimi ? null : secim);
  if (hata != null) {
    Bildirim.snackBar(SnackBar(content: Text(hata)));
  }
}

class _SehirListesi extends StatefulWidget {
  final String seciliSehir;
  final AppThemeColors r;
  const _SehirListesi({required this.seciliSehir, required this.r});

  @override
  State<_SehirListesi> createState() => _SehirListesiState();
}

class _SehirListesiState extends State<_SehirListesi> {
  String _arama = '';

  @override
  Widget build(BuildContext context) {
    final r = widget.r;
    final aranan = _arama.trKucuk;
    final liste = iller.where((il) => il.ad.trKucuk.contains(aranan)).toList();

    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.h(16), Responsive.w(16), Responsive.h(8)),
              child: Text(
                'Şehir Seç',
                style: TextStyle(
                  fontSize: Responsive.sp(18),
                  fontWeight: FontWeight.bold,
                  color: r.yaziRengi,
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
              child: TextField(
                onChanged: (v) => setState(() => _arama = v.trim()),
                style: TextStyle(color: r.yaziRengi),
                decoration: InputDecoration(
                  hintText: 'İl ara',
                  hintStyle: TextStyle(color: r.pasifRenk),
                  prefixIcon: Icon(Icons.search, color: r.pasifRenk),
                  filled: true,
                  fillColor: r.kartRengi,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            SizedBox(height: Responsive.h(8)),
            Expanded(
              child: ListView(
                children: [
                  if (_arama.isEmpty)
                    ListTile(
                      leading: Icon(Icons.my_location, color: r.anaRenk),
                      title: Text(
                        'Konumumu kullan (GPS)',
                        style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold),
                      ),
                      trailing: widget.seciliSehir.isEmpty
                          ? Icon(Icons.check_rounded, color: r.anaRenk)
                          : null,
                      onTap: () => Navigator.pop(context, _gpsSecimi),
                    ),
                  for (final il in liste)
                    ListTile(
                      title: Text(il.ad, style: TextStyle(color: r.yaziRengi)),
                      trailing: il.ad == widget.seciliSehir
                          ? Icon(Icons.check_rounded, color: r.anaRenk)
                          : null,
                      onTap: () => Navigator.pop(context, il.ad),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
