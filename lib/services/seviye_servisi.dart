class SeviyeServisi {
  static const int namazXp = 20; // Her vaktin ödülü

  // Beğendiğin o efsane liste
  static final Map<int, String> unvanlar = {
    0: "Seccade Kaşifi",
    100: "Seccade Yolcusu",
    300: "Abdest Pro Max",
    600: "Abdest Bükücü",
    1000: "Tespih Silahşörü",
    2000: "Seccade Pilotu",
    4000: "Namaz Gurmesi",
    7000: "Cami Kuşu",
    11000: "Seccade Üstadı",
    16000: "Final Boss (Hacı Abi)",
  };

  // XP'ye göre ünvanı bulan fonksiyon
  static String unvanGetir(int xp) {
    String sonUnvan = unvanlar.values.first;
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

  // Barın doluluk oranını hesaplayan fonksiyon (0.0 - 1.0 arası)
  static double ilerlemeHesapla(int xp) {
    var anahtarlar = unvanlar.keys.toList()..sort();
    for (int i = 0; i < anahtarlar.length - 1; i++) {
      if (xp >= anahtarlar[i] && xp < anahtarlar[i + 1]) {
        return (xp - anahtarlar[i]) / (anahtarlar[i + 1] - anahtarlar[i]);
      }
    }
    return 1.0; // Max seviyeyse bar hep dolu kalsın
  }
}
