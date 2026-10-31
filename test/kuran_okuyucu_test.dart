import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_app/services/kelime_deposu.dart';
import 'package:namaz_app/services/kuran_okuyucu.dart';

void main() {
  test('genel ayet numarası: ses dosyaları Mushaf sırasıyla adlandırılır', () {
    expect(KuranOkuyucu.genelAyetNo(1, 1), 1);
    expect(KuranOkuyucu.genelAyetNo(2, 1), 8, reason: "Fâtiha 7 ayet");
    expect(KuranOkuyucu.genelAyetNo(2, 255), 262, reason: "Âyetü'l-Kürsî");
    expect(KuranOkuyucu.genelAyetNo(114, 6), 6236, reason: 'Son ayet');
    expect(KuranOkuyucu.sesAdresi(112, 1), endsWith('/112001.mp3'));
    expect(KuranOkuyucu.dosyaAdi(2, 255), '002255');
  });

  test('ses konumundan okunan kelime bulunur (Quran.com zamanlaması)', () {
    // İhlâs 1: [kelime, başlangıç, bitiş] ms
    const a = AyetKelime(['قُلْ', 'هُوَ', 'ٱللَّهُ', 'أَحَدٌ'], [(1, 30, 390), (2, 400, 790), (3, 800, 1640), (4, 1650, 2300)]);
    expect(a.kelimeAt(10), isNull);
    expect(a.kelimeAt(100), 1);
    expect(a.kelimeAt(1000), 3);
    expect(a.kelimeAt(2300), 4);
    expect(AyetKelime.fromJson(a.toJson()).zamanlar, a.zamanlar, reason: 'Telefona kaydedip geri okuma');
  });
}
