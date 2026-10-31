import '../../models/religious_day.dart';
import 'package:intl/intl.dart';

/// Hicri gün/ay çifti
typedef _HicriGun = ({int ay, int gun});

class DiniGunlerUtil {
  /// Aladhan'ın hicri takvimi (Suudi HJCoSA) bazı aylarda Diyanet'ten bir gün önce başlar.
  /// Anahtar: "hicriYıl-hicriAy", değer: Diyanet gün numarası için eklenecek fark.
  /// Diyanet Ramazan 1447'yi 19 Şubat 2026'da başlattı, Aladhan 18 Şubat diyor.
  static const Map<String, int> _diyanetFarki = {
    '1447-9': -1,
  };

  // Gündüz idrak edilen günler (o günün hicri tarihine göre)
  static const Map<_HicriGun, String> _gunduzGunleri = {
    (ay: 9, gun: 1): 'Ramazan Başlangıcı',
    (ay: 10, gun: 1): 'Ramazan Bayramı',
    (ay: 12, gun: 9): 'Kurban Bayramı Arefesi',
    (ay: 12, gun: 10): 'Kurban Bayramı',
    (ay: 1, gun: 1): 'Hicri Yılbaşı',
    (ay: 1, gun: 10): 'Aşure Günü',
  };

  // Gece idrak edilenler: hicri gün akşam başladığı için takvimde bir önceki miladi güne yazılır.
  // Anahtar = ertesi günün hicri tarihi.
  static const Map<_HicriGun, String> _geceler = {
    (ay: 7, gun: 27): 'Mirac Kandili',
    (ay: 8, gun: 15): 'Berat Kandili',
    (ay: 9, gun: 27): 'Kadir Gecesi',
    (ay: 3, gun: 12): 'Mevlid Kandili',
    (ay: 10, gun: 1): 'Ramazan Bayramı Arefesi',
  };

  static const Map<String, String> _aciklamalar = {
    'Regaib Kandili': 'Rahmet, bereket ve mağfiret mevsimi olan üç ayların başlangıcını müjdeler. Allah\'ın lütfunun bol bol ihsan edildiği gecedir.',
    'Mirac Kandili': 'Peygamber Efendimizin (s.a.s) Mescid-i Haram\'dan Mescid-i Aksa\'ya, oradan da semaya yükseldiği mucizevi gecedir. Beş vakit namaz bu gece farz kılınmıştır.',
    'Berat Kandili': 'Şaban ayının 15. gecesidir. Günahlardan arınma, temize çıkma, ilahi af ve rahmete nail olma gecesidir.',
    'Ramazan Başlangıcı': 'On bir ayın sultanı, rahmet, bereket ve Kur\'an ayı olan Ramazan\'ın ilk günüdür. Kardeşlik ve dayanışma ayıdır.',
    'Kadir Gecesi': 'Kur\'an-ı Kerim\'in indirilmeye başlandığı, Yüce Allah\'ın ifadesiyle "bin aydan daha hayırlı" olan mübarek gecedir.',
    'Ramazan Bayramı': 'Bir aylık Ramazan orucunun ardından tutulan manevi şükrün ve sevincin paylaşıldığı günlerdir.',
    'Kurban Bayramı': 'Hz. İbrahim\'in teslimiyetini hatırlatan, Allah\'a yakınlaşma, fedakârlık, paylaşma ve yardımlaşma günleridir.',
    'Hicri Yılbaşı': 'Muharrem ayının ilk günüdür. Peygamber Efendimizin Mekke\'den Medine\'ye hicretini esas alan İslami takvimin yılbaşıdır.',
    'Aşure Günü': 'Muharrem ayının 10. günüdür. Tarihte pek çok peygamberin sıkıntılarından kurtulduğu, bereketin ve paylaşmanın simgesi bir gündür.',
    'Mevlid Kandili': 'Peygamber Efendimiz Hz. Muhammed\'in (s.a.s) dünyayı şereflendirdiği (doğduğu) gecedir.',
    'Kurban Bayramı Arefesi': 'Kurban Bayramı\'ndan bir önceki gündür. Hac ibadetini yapanların Arafat\'ta vakfeye durduğu, duaların kabul edildiği mübarek bir gündür.',
    'Ramazan Bayramı Arefesi': 'Ramazan Bayramı\'ndan bir önceki gündür. Bir aylık oruç ibadetinin tamamlandığı, bayram sevincinin başladığı hazırlık günüdür.',
  };

  /// API'nin hicri tarihini Diyanet takvimine çevirir; ayın gün sayısını da döner.
  static ({int ay, int gun, int ayUzunlugu}) _diyanetHicri(Map<String, dynamic> hijri) {
    int ay = int.parse(hijri['month']['number'].toString());
    int gun = int.parse(hijri['day'].toString());
    int ayUzunlugu = int.tryParse(hijri['month']['days']?.toString() ?? '') ?? 30;
    final yil = hijri['year'].toString();

    final fark = _diyanetFarki['$yil-$ay'] ?? 0;
    if (fark != 0) {
      gun += fark;
      ayUzunlugu += fark;
      if (gun < 1) {
        // Diyanet'e göre hâlâ bir önceki ayın son günü
        ay = ay == 1 ? 12 : ay - 1;
        gun = 30;
        ayUzunlugu = 30;
      }
    }
    return (ay: ay, gun: gun, ayUzunlugu: ayUzunlugu);
  }

  /// Aladhan'dan gelen günlük objeyi analiz edip ReligiousDay listesine dönüştürür.
  /// Tarihler Diyanet'in takvim kuralına göre hesaplanır (kandiller bir önceki akşam).
  static List<ReligiousDay> parseAladhanDay(Map<String, dynamic> dayData) {
    final String dateStrGr = dayData['date']['gregorian']['date']; // DD-MM-YYYY
    final DateTime miladiTarih = DateFormat('dd-MM-yyyy').parse(dateStrGr);
    final String formattedDateStr = DateFormat('yyyy-MM-dd').format(miladiTarih);

    final bugun = _diyanetHicri(dayData['date']['hijri']);
    final _HicriGun yarin = bugun.gun >= bugun.ayUzunlugu
        ? (ay: bugun.ay == 12 ? 1 : bugun.ay + 1, gun: 1)
        : (ay: bugun.ay, gun: bugun.gun + 1);

    final isimler = <String>[];

    final gunduz = _gunduzGunleri[(ay: bugun.ay, gun: bugun.gun)];
    if (gunduz != null) isimler.add(gunduz);

    final gece = _geceler[yarin];
    if (gece != null) isimler.add(gece);

    // Regaib Kandili: Recep ayının ilk Cuma gecesi → o Cuma'dan önceki Perşembe
    if (miladiTarih.weekday == DateTime.thursday && yarin.ay == 7 && yarin.gun <= 7) {
      isimler.add('Regaib Kandili');
    }

    return [
      for (final ad in isimler)
        ReligiousDay(
          dateStr: formattedDateStr,
          englishName: 'Hijri ${bugun.gun}/${bugun.ay}',
          turkishName: ad,
          description: _aciklamalar[ad],
        ),
    ];
  }
}
