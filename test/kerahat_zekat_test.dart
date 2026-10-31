import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_app/providers/namaz_provider.dart';
import 'package:namaz_app/views/zekat_screen.dart';

void main() {
  const v = {'Sabah': '05:30', 'Güneş': '07:00', 'Öğle': '12:50', 'İkindi': '15:40', 'Akşam': '18:10', 'Yatsı': '19:35'};
  DateTime at(int s, int d) => DateTime(2026, 10, 31, s, d);
  String? neden(DateTime t) => NamazProvider.kerahatHesapla(v, t)?.neden;

  test('kerahat vakitleri: doğuş, istiva, batış (45 dk)', () {
    expect(neden(at(6, 59)), isNull);
    expect(neden(at(7, 0)), 'Güneş doğuyor');
    expect(NamazProvider.kerahatHesapla(v, at(7, 10))!.bitis, at(7, 45));
    expect(neden(at(7, 45)), isNull);
    expect(neden(at(12, 5)), 'Güneş tam tepede (istiva)');
    expect(neden(at(12, 50)), isNull, reason: 'Öğle girince biter');
    expect(neden(at(17, 25)), 'Güneş batıyor');
    expect(neden(at(15, 0)), isNull);
  });

  test('zekât: nisap altında gerekmez, üstünde %2,5', () {
    const az = ZekatHesabi(altinFiyati: 3000, nakit: 100000); // nisap 240.540 ₺
    expect(az.zekatGerekli, isFalse);
    const cok = ZekatHesabi(altinFiyati: 3000, altinGram: 50, nakit: 200000, borc: 50000);
    expect(cok.netVarlik, 300000);
    expect(cok.zekat, closeTo(7500, 0.01));
    expect(const ZekatHesabi(nakit: 1e9).zekatGerekli, isFalse, reason: 'Altın fiyatı yoksa hesaplanmaz');
  });
}
