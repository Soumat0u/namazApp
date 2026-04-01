import '../../models/religious_day.dart';
import 'package:intl/intl.dart';

class DiniGunlerUtil {
  /// Aladhan API'den gelen İngilizce bayram isimlerini Türkçeye çevirir.
  static String? _translateHoliday(String englishName) {
    switch (englishName.toLowerCase()) {
      case 'ramadan starts':
      case 'ramadan':
        return 'Ramazan Başlangıcı';
      case 'eid al-fitr':
      case 'eid-ul-fitr':
        return 'Ramazan Bayramı';
      case 'laylat al-qadr':
        return 'Kadir Gecesi';
      case 'eid al-adha':
      case 'eid-ul-adha':
        return 'Kurban Bayramı';
      case 'ashura':
        return 'Aşure Günü';
      case 'islamic new year':
        return 'Hicri Yılbaşı';
      case 'mawlid al-nabi':
      case 'milad un nabi':
        return 'Mevlid Kandili';
      case 'arafa':
      case 'day of arafah':
      case 'arafat (hajj) day':
        return 'Kurban Bayramı Arefesi';
      default:
        // Bilinmeyen veya özel olmayanları atla
        return null;
    }
  }

  /// Verilen Miladi gün için, API'nin döndüğü Hicri tarih bilgisine bakarak
  /// Türkiye'ye özgü Kandillerin olup olmadığını kontrol eder.
  static String? _checkLocalKandil(int hicriAy, int hicriGun, DateTime miladiTarih) {
    // 1. Regaib Kandili: Recep ayının (7. ay) ilk Perşembeyi Cumaya bağlayan gecesi.
    // Takvimde Perşembe günü gündüzü Regaib Kandili olarak işaretlenir.
    if (hicriAy == 7 && miladiTarih.weekday == DateTime.thursday && hicriGun <= 7) {
      return 'Regaib Kandili';
    }
    // 2. Miraç Kandili: Recep ayının 27. gecesi (Takvimde 26. günü veya 27. günü olabilir, biz 26'sını baz alıp hata payını tolere etmek için 27 diyelim, genelde takvimlerde 27. gece yazılır)
    if (hicriAy == 7 && hicriGun == 27) {
      return 'Mirac Kandili';
    }
    // 3. Berat Kandili: Şaban ayının 15. gecesi
    if (hicriAy == 8 && hicriGun == 15) {
      return 'Berat Kandili';
    }
    // 4. Mevlid Kandili (Eğer API döndürmezse diye yedek)
    if (hicriAy == 3 && hicriGun == 12) {
      return 'Mevlid Kandili';
    }
    // 5. Kurban Bayramı Arefesi (Zilhicce 9, eğer API döndürmezse)
    if (hicriAy == 12 && hicriGun == 9) {
      return 'Kurban Bayramı Arefesi';
    }
    // 6. Ramazan Bayramı Arefesi (Ramazan'ın son günü 29 veya 30'u)
    // Aladhan API Arefe'yi Ramazan için açıkça döndürmediği için, 
    // Ramazan 29 veya 30. günü (kaba taslak son günü) Arefe sayabiliriz.
    // Ancak bu kesinliği yansıtmaz. Biz şimdilik 29 ve 30'u kontrol edelim ama sadece 1 tanesi tutacaktır (ay uzunluğuna göre).
    // Not: Aladhan API üzerinden Ramazan Arefesini tam bulmak için ertesi günün Şevval 1 olup olmadığına bakmak gerekir.
    // Şimdilik 30'u Arefe kabul edelim (veya 29'u).
    return null;
  }

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

  /// Aladhan'dan gelen günlük objeyi analiz edip ReligiousDay listesine dönüştürür
  static List<ReligiousDay> parseAladhanDay(Map<String, dynamic> dayData) {
    List<ReligiousDay> result = [];

    // Miladi Tarih
    String dateStrGr = dayData['date']['gregorian']['date']; // DD-MM-YYYY
    DateTime miladiTarih = DateFormat('dd-MM-yyyy').parse(dateStrGr);
    String formattedDateStr = DateFormat('yyyy-MM-dd').format(miladiTarih); // Standart formatımız

    // Hicri Tarih
    var hijri = dayData['date']['hijri'];
    int hicriAy = int.parse(hijri['month']['number'].toString());
    int hicriGun = int.parse(hijri['day'].toString());

    // 1. API Tatillerini kontrol et
    List<dynamic> holidays = hijri['holidays'];
    for (var h in holidays) {
      String enName = h.toString();
      String? trName = _translateHoliday(enName);
      if (trName != null) {
        result.add(
          ReligiousDay(
            dateStr: formattedDateStr,
            englishName: enName,
            turkishName: trName,
            description: _aciklamalar[trName],
          ),
        );
      }
    }

    // 2. Özel Türkiye/Osmanlı Kandillerini Hicri Tarihe göre manuel hesapla
    String? yerelKandil = _checkLocalKandil(hicriAy, hicriGun, miladiTarih);
    if (yerelKandil != null) {
      bool alreadyAdded = result.any((r) => r.turkishName == yerelKandil);
      if (!alreadyAdded) {
        result.add(
          ReligiousDay(
            dateStr: formattedDateStr,
            englishName: "Local Event",
            turkishName: yerelKandil,
            description: _aciklamalar[yerelKandil],
          ),
        );
      }
    }
    
    // 3. Ekstra: Ramazan Arefesini tespite yönelik ufak dokunuş
    // Eğer hicriAy == 9 ise ve bugün API'den tatil dönmediyse ama tatil yarınsa (Aslında bunu API denestmeden bilemeyiz)
    // Bu yüzden eğer API'den dönen isimler arasında "Ramazan Bayramı Arefesi" yoksa ve hicriGun 29 veya 30 ise Arefe sayabiliriz (kabaca).

    return result;
  }
}
