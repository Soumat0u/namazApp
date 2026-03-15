enum GorevZorluk { cokKolay, kolay, orta, zor }
enum GorevTipi { gunluk, haftalik, zamansiz }

class Gorev {
  final String id;
  final String baslik;
  final String aciklama;
  final int xpOdulu;
  final GorevTipi tip;
  final GorevZorluk zorluk;
  bool tamamlandiMi;
  bool odulAlindiMi; // 🔥 Yeni: Ödülün alınıp alınmadığını takip eder
  double ilerleme;

  Gorev({
    required this.id,
    required this.baslik,
    required this.aciklama,
    required this.xpOdulu,
    required this.tip,
    required this.zorluk,
    this.tamamlandiMi = false,
    this.odulAlindiMi = false, // 🔥 Varsayılan olarak alınmadı
    this.ilerleme = 0.0,
  });

  // Telefona kaydetmek için JSON dönüşümü (odulAlindiMi eklendi)
  Map<String, dynamic> toJson() => {
    'id': id,
    'tamamlandiMi': tamamlandiMi,
    'odulAlindiMi': odulAlindiMi,
    'ilerleme': ilerleme,
  };

  // Hafızadan okurken kullanacağımız yardımcı yapı (Eğer ihtiyacın olursa)
  factory Gorev.fromJson(Map<String, dynamic> json, Gorev taslak) {
    return Gorev(
      id: taslak.id,
      baslik: taslak.baslik,
      aciklama: taslak.aciklama,
      xpOdulu: taslak.xpOdulu,
      tip: taslak.tip,
      zorluk: taslak.zorluk,
      tamamlandiMi: json['tamamlandiMi'] ?? false,
      odulAlindiMi: json['odulAlindiMi'] ?? false,
      ilerleme: (json['ilerleme'] ?? 0.0).toDouble(),
    );
  }
}