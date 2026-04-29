class SeviyeServisi {
  static const int namazXp = 20; // Her vaktin ödülü
  static const int tamGunBonusu = 25; // 5 vakit tamamlanınca gelen ekstra
  static const int aminXp = 1; // Dua beğenme ödülü

  static final Map<int, String> unvanlar = {
    0: "Talip",
    1000: "Salik",
    3000: "Muhip",
    6500: "Sakin",
    11500: "Arif",
    18000: "Fecr",
    26000: "Züha",
    35000: "Zuhur",
    45000: "Kamer",
    50000: "Süreyya",
  };

  static String unvanGetir(int xp) {
    String sonUnvan = "Talip";
    var anahtarlar = unvanlar.keys.toList()..sort();
    for (var limit in anahtarlar) {
      if (xp >= limit) {
        sonUnvan = unvanlar[limit]!;
      } else {
        break;
      }
    }
    return sonUnvan;
  }

  static double ilerlemeHesapla(int xp) {
    var anahtarlar = unvanlar.keys.toList()..sort();
    
    // Eğer en üst seviyeye ulaşıldıysa barı dolu göster
    if (xp >= anahtarlar.last) return 1.0;

    for (int i = 0; i < anahtarlar.length - 1; i++) {
      int altLimit = anahtarlar[i];
      int ustLimit = anahtarlar[i + 1];
      
      if (xp >= altLimit && xp < ustLimit) {
        return (xp - altLimit) / (ustLimit - altLimit);
      }
    }
    return 0.0;
  }
}