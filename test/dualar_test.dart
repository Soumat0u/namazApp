import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_app/core/constants/dualar.dart';

void main() {
  test('her duanın Arapça metni, okunuşu ve meali dolu', () {
    for (final d in dualar) {
      expect(d.arapca.trim(), isNotEmpty, reason: d.baslik);
      expect(d.okunus.trim(), isNotEmpty, reason: d.baslik);
      expect(d.meal.trim(), isNotEmpty, reason: d.baslik);
    }
  });

  test('Kur\'an referansları doğru sureyi gösteriyor', () {
    expect(dualar.firstWhere((d) => d.baslik == 'Âyetü\'l-Kürsî').kaynak, contains('255'));
    expect(dualar.firstWhere((d) => d.baslik == 'İhlâs').ayetler.length, 4);
    expect(dualar.firstWhere((d) => d.baslik == 'Fâtiha').ayetler.length, 7);
  });

  test('tesbihat: 33\'lük üç zikir ve Âyetü\'l-Kürsî', () {
    expect(tesbihatAdimlari.where((a) => a.adet == 33).length, 3);
    expect(tesbihatAdimlari.any((a) => a.dua?.sure == 2), isTrue);
    expect(tesbihatAdimlari.every((a) => a.arapcaMetin.isNotEmpty), isTrue);
  });
}
