import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_app/providers/namaz_provider.dart';

/// Vakit kilidi ve "Vakti Kıldım" butonu bu hesaba dayanır: hangi saatte hangi vakit işaretlenebilir?
void main() {
  const v = {
    'Sabah': '05:30', 'Güneş': '07:00', 'Öğle': '12:50', 'İkindi': '15:40',
    'Akşam': '18:10', 'Yatsı': '19:35',
  };
  DateTime at(int saat, int dk, [int gun = 31]) => DateTime(2026, 10, gun, saat, dk);
  String dilim(DateTime t, {String? yarinSabah}) =>
      NamazProvider.vakitDilimiHesapla(v, t, yarinSabah: yarinSabah).vakit;

  test('gece yarısından sabaha kadar hâlâ dünkü Yatsı', () {
    expect(dilim(at(0, 10)), 'Yatsı');
    expect(dilim(at(5, 29)), 'Yatsı');
    expect(NamazProvider.vakitDilimiHesapla(v, at(3, 0)).bitis, at(5, 30));
  });

  test('her vakit kendi başlangıcında girer, bir sonrakinde çıkar', () {
    expect(dilim(at(5, 30)), 'Sabah');
    expect(dilim(at(6, 59)), 'Sabah');
    expect(dilim(at(7, 0)), 'Güneş', reason: 'Güneş doğunca Sabah çıkar');
    expect(dilim(at(12, 49)), 'Güneş');
    expect(dilim(at(12, 50)), 'Öğle');
    expect(dilim(at(15, 40)), 'İkindi');
    expect(dilim(at(18, 10)), 'Akşam');
    expect(dilim(at(19, 35)), 'Yatsı');
    expect(dilim(at(23, 59)), 'Yatsı');
  });

  test('Yatsı yarının sabah vaktinde biter (takvim varsa ondan)', () {
    expect(NamazProvider.vakitDilimiHesapla(v, at(22, 0)).bitis, at(5, 30, 32).copyWith());
    expect(NamazProvider.vakitDilimiHesapla(v, at(22, 0), yarinSabah: '05:32').bitis,
        DateTime(2026, 11, 1, 5, 32));
  });

  test('ay sonunda Yatsı bitişi ertesi ayın ilk günü', () {
    expect(NamazProvider.vakitDilimiHesapla(v, at(21, 0)).bitis, DateTime(2026, 11, 1, 5, 30));
  });

  test('eski önbellekte Güneş yoksa Sabah, Öğle girene kadar sürer', () {
    final eski = Map.of(v)..remove('Güneş');
    expect(NamazProvider.vakitDilimiHesapla(eski, at(9, 0)).vakit, 'Sabah');
  });

  test('"05:30 (+03)" biçimli saatler de çalışır', () {
    final ekli = v.map((k, s) => MapEntry(k, '$s (+03)'));
    expect(NamazProvider.vakitDilimiHesapla(ekli, at(13, 0)).vakit, 'Öğle');
  });
}
