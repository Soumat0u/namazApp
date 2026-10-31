import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_app/services/rozet_servisi.dart';

void main() {
  List<Rozet> hesapla({int namaz = 0, Map<String, int> gunler = const {}, int arkadas = 0}) =>
      RozetServisi.hesapla(
        toplamNamaz: namaz, gunlukKilinan: gunler, kilinanKaza: 0,
        toplamZikir: 0, duaPaylasimi: 0, arkadasSayisi: arkadas,
      );
  bool var_(List<Rozet> l, String id) => l.firstWhere((r) => r.id == id).kazanildi;

  test('ardışık tam günler sayılır, ara verilince seri yeniden başlar', () {
    expect(RozetServisi.enUzunArdisikGun(['2026-10-01', '2026-10-02', '2026-10-04']), 2);
    expect(RozetServisi.enUzunArdisikGun(['2026-10-30', '2026-10-31', '2026-11-01']), 3, reason: 'Ay geçişi');
    expect(RozetServisi.enUzunArdisikGun([]), 0);
  });

  test('7 günlük seri rozeti: 7 ardışık tam gün', () {
    final yedi = {for (int g = 1; g <= 7; g++) '2026-10-${g.toString().padLeft(2, '0')}': 5};
    expect(var_(hesapla(gunler: yedi), 'seri_7'), isTrue);
    expect(var_(hesapla(gunler: {...yedi, '2026-10-04': 4}), 'seri_7'), isFalse);
  });

  test('eşik ve ilerleme', () {
    final l = hesapla(namaz: 50, arkadas: 1);
    expect(var_(l, 'ilk_namaz'), isTrue);
    expect(var_(l, 'namaz_100'), isFalse);
    expect(l.firstWhere((r) => r.id == 'namaz_100').ilerleme, 0.5);
    expect(var_(l, 'ilk_kardes'), isTrue);
  });
}
