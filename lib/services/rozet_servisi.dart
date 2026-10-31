import 'package:flutter/material.dart';

class Rozet {
  final String id;
  final String ad;
  final String aciklama;
  final IconData ikon;
  final bool kazanildi;
  /// 0..1 arası ilerleme (kazanılmadıysa ne kadar yaklaşıldığı)
  final double ilerleme;

  const Rozet({
    required this.id,
    required this.ad,
    required this.aciklama,
    required this.ikon,
    required this.kazanildi,
    required this.ilerleme,
  });
}

/// Rozetler yerel istatistiklerden hesaplanır; ayrıca saklanmaz (veri değiştikçe kendiliğinden güncellenir)
class RozetServisi {
  /// [gunlukKilinan]: "yyyy-MM-dd" → o gün kılınan vakit sayısı (bugün dahil)
  static List<Rozet> hesapla({
    required int toplamNamaz,
    required Map<String, int> gunlukKilinan,
    required int kilinanKaza,
    required int toplamZikir,
    required int duaPaylasimi,
    required int arkadasSayisi,
  }) {
    final tamGunler = gunlukKilinan.entries.where((e) => e.value >= 5).map((e) => e.key).toList()..sort();
    final enUzunSeri = enUzunArdisikGun(tamGunler);

    Rozet r(String id, String ad, String aciklama, IconData ikon, num deger, num hedef) => Rozet(
          id: id,
          ad: ad,
          aciklama: aciklama,
          ikon: ikon,
          kazanildi: deger >= hedef,
          ilerleme: (deger / hedef).clamp(0, 1).toDouble(),
        );

    return [
      r('ilk_namaz', 'İlk Adım', 'İlk namazını işaretle', Icons.flag_rounded, toplamNamaz, 1),
      r('ilk_tam_gun', 'Tam Gün', 'Bir günün 5 vaktini de kıl', Icons.wb_sunny_rounded, tamGunler.length, 1),
      r('seri_7', 'Bir Hafta', '7 gün üst üste 5 vakit', Icons.local_fire_department_rounded, enUzunSeri, 7),
      r('seri_30', 'Bir Ay', '30 gün üst üste 5 vakit', Icons.whatshot_rounded, enUzunSeri, 30),
      r('namaz_100', 'Yüz Secde', '100 vakit namaz', Icons.mosque_rounded, toplamNamaz, 100),
      r('namaz_1000', 'Bin Secde', '1000 vakit namaz', Icons.auto_awesome_rounded, toplamNamaz, 1000),
      r('ilk_kaza', 'Telafi', 'İlk kaza namazını kıl', Icons.history_rounded, kilinanKaza, 1),
      r('kaza_100', 'Borç Eriten', '100 kaza namazı kıl', Icons.task_alt_rounded, kilinanKaza, 100),
      r('zikir_1000', 'Zâkir', 'Toplam 1000 zikir', Icons.radio_button_checked_rounded, toplamZikir, 1000),
      r('ilk_dua', 'Dua Eden', 'Meclis\'te ilk duanı paylaş', Icons.volunteer_activism_rounded, duaPaylasimi, 1),
      r('ilk_kardes', 'Kardeşlik', 'İlk arkadaşını ekle', Icons.handshake_rounded, arkadasSayisi, 1),
      r('kardes_5', 'Cemaat', '5 arkadaş edin', Icons.groups_rounded, arkadasSayisi, 5),
    ];
  }

  /// Sıralı "yyyy-MM-dd" listesinde en uzun ardışık gün sayısı
  static int enUzunArdisikGun(List<String> siraliGunler) {
    int enUzun = 0, mevcut = 0;
    DateTime? onceki;
    for (final g in siraliGunler) {
      final p = g.split('-').map(int.parse).toList();
      final gun = DateTime.utc(p[0], p[1], p[2]);
      mevcut = (onceki != null && gun.difference(onceki).inDays == 1) ? mevcut + 1 : 1;
      if (mevcut > enUzun) enUzun = mevcut;
      onceki = gun;
    }
    return enUzun;
  }
}
