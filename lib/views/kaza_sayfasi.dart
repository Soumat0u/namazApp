import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/namaz_provider.dart';

class KazaSayfasi extends StatelessWidget {
  const KazaSayfasi({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NamazProvider>();

    // Toplam kaza sayısını hesapla
    int toplamKaza = provider.kazaNamazlari.values.fold(
      0,
      (sum, item) => sum + item,
    );

    return Scaffold(
      backgroundColor: AppColors.arkaPlanRengi,
      appBar: AppBar(
        title: const Text(
          "Kaza Namazları",
          style: TextStyle(
            color: AppColors.yaziRengi,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildToplamKart(toplamKaza),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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

  Widget _buildToplamKart(int toplam) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.kartRengi,
        borderRadius: BorderRadius.circular(20),
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
          const Text(
            "Toplam Bekleyen Kaza",
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.yaziRengi,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.kirmizi.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              "$toplam",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.kirmizi,
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
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.kartRengi,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: AppColors.pasifRenk.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            vakit,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.yaziRengi,
            ),
          ),
          Row(
            children: [
              IconButton(
                onPressed: () => provider.kazaGuncelle(vakit, -1),
                icon: const Icon(
                  Icons.remove_circle_outline,
                  color: AppColors.aktifYesil,
                ),
              ),
              SizedBox(
                width: 40,
                child: Center(
                  child: Text(
                    "$sayi",
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              IconButton(
                onPressed: () => provider.kazaGuncelle(vakit, 1),
                icon: const Icon(
                  Icons.add_circle_outline,
                  color: AppColors.kirmizi,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
