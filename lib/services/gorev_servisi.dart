import '../models/gorev_model.dart';

class GorevServisi {
  static List<Gorev> tumGorevleriGetir() {
    return [
      // ZAMANSIZ (KALICI)
      Gorev(id: 'z_ilk_namaz', baslik: 'İlk Adım', aciklama: 'İlk namaz vaktini işaretle.', xpOdulu: 50, tip: GorevTipi.zamansiz, zorluk: GorevZorluk.cokKolay),
      Gorev(id: 'z_tanisma', baslik: 'Tanışma', aciklama: 'Rütbe tablosuna göz at.', xpOdulu: 20, tip: GorevTipi.zamansiz, zorluk: GorevZorluk.cokKolay),
      
      // GÜNLÜK (KADEMELİ)
      Gorev(id: 'g_merhaba', baslik: 'Güne Merhaba', aciklama: 'Uygulamayı bugün ilk kez aç.', xpOdulu: 10, tip: GorevTipi.gunluk, zorluk: GorevZorluk.cokKolay),
      Gorev(id: 'g_ilk_vakit', baslik: 'Disiplin Başlangıcı', aciklama: 'Bugün 1 vakit işaretle.', xpOdulu: 15, tip: GorevTipi.gunluk, zorluk: GorevZorluk.kolay),
      Gorev(id: 'g_full_house', baslik: 'Kusursuz Gün', aciklama: '5 vaktin tamamını işaretle.', xpOdulu: 60, tip: GorevTipi.gunluk, zorluk: GorevZorluk.zor),

      // HAFTALIK
      Gorev(id: 'h_sampiyon', baslik: 'Haftalık Şampiyon', aciklama: 'Bu hafta 30 vakit işaretle.', xpOdulu: 250, tip: GorevTipi.haftalik, zorluk: GorevZorluk.zor),
    ];
  }
}