import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_app/services/kuran_okuyucu.dart';

void main() {
  test('genel ayet numarası: ses dosyaları Mushaf sırasıyla adlandırılır', () {
    expect(KuranOkuyucu.genelAyetNo(1, 1), 1);
    expect(KuranOkuyucu.genelAyetNo(2, 1), 8, reason: "Fâtiha 7 ayet");
    expect(KuranOkuyucu.genelAyetNo(2, 255), 262, reason: "Âyetü'l-Kürsî");
    expect(KuranOkuyucu.genelAyetNo(114, 6), 6236, reason: 'Son ayet');
    expect(KuranOkuyucu.sesAdresi(112, 1), endsWith('/6222.mp3'));
  });
}
