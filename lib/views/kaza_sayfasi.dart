import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';

class KazaSayfasi extends StatelessWidget {
  const KazaSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final r = context.renkler;

    int toplamKaza = provider.kazaNamazlari.values.fold(
      0,
      (sum, item) => sum + item,
    );

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        title: Text(
          "Kaza Namazları",
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
      body: Column(
        children: [
          _buildToplamKart(context, toplamKaza),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(16),
                vertical: Responsive.h(8),
              ),
              itemCount: provider.vakitIsimleri.length,
              itemBuilder: (context, index) {
                String vakit = provider.vakitIsimleri[index];
                int kazaSayisi = provider.kazaNamazlari[vakit] ?? 0;
                return _buildKazaKart(context, provider, vakit, kazaSayisi);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToplamKart(BuildContext context, int toplam) {
    final r = context.renkler;
    return Container(
      margin: EdgeInsets.all(Responsive.w(16)),
      padding: EdgeInsets.all(Responsive.w(16)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            "Toplam Bekleyen Kaza",
            style: TextStyle(
              fontSize: Responsive.sp(15),
              fontWeight: FontWeight.bold,
              color: r.yaziRengi,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(12),
              vertical: Responsive.h(6),
            ),
            decoration: BoxDecoration(
              color: r.kirmizi.withOpacity(0.1),
              borderRadius: BorderRadius.circular(Responsive.w(12)),
            ),
            child: Text(
              "$toplam",
              style: TextStyle(
                fontSize: Responsive.sp(18),
                fontWeight: FontWeight.bold,
                color: r.kirmizi,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKazaKart(
    BuildContext context,
    NamazProvider provider,
    String vakit,
    int sayi,
  ) {
    final r = context.renkler;
    return Container(
      margin: EdgeInsets.only(bottom: Responsive.h(12)),
      padding: EdgeInsets.all(Responsive.w(12)),
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(12)),
        border: Border.all(color: r.pasifRenk.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            vakit,
            style: TextStyle(
              fontSize: Responsive.sp(16),
              fontWeight: FontWeight.bold,
              color: r.yaziRengi,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => provider.kazaGuncelle(vakit, -1),
                icon: Icon(
                  Icons.remove_circle_outline,
                  color: r.aktifYesil,
                  size: Responsive.w(22),
                ),
              ),
              SizedBox(
                width: Responsive.w(36),
                child: Center(
                  child: Text(
                    "$sayi",
                    style: TextStyle(
                      fontSize: Responsive.sp(18),
                      fontWeight: FontWeight.bold,
                      color: r.yaziRengi,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => provider.kazaGuncelle(vakit, 1),
                icon: Icon(
                  Icons.add_circle_outline,
                  color: r.kirmizi,
                  size: Responsive.w(22),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
