import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:namaz_app/core/constants/iller.dart';
import 'package:namaz_app/core/utils/content_moderation.dart';
import 'package:namaz_app/core/utils/dini_gunler_util.dart';
import 'package:namaz_app/core/utils/extensions.dart';
import 'package:namaz_app/models/religious_day.dart';
import 'package:namaz_app/services/seviye_servisi.dart';

/// Gerçek Aladhan API cevaplarından (İstanbul, method=13) dini günleri çıkarır.
/// Sonuç: dini gün adı → miladi tarihler
Map<String, List<String>> _diniGunler() {
  final sonuc = <String, List<String>>{};
  final dosyalar = Directory('test/fixtures')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.json'));
  for (final f in dosyalar) {
    final data = json.decode(f.readAsStringSync())['data'] as List;
    for (final gun in data) {
      for (final ReligiousDay d in DiniGunlerUtil.parseAladhanDay(gun)) {
        sonuc.putIfAbsent(d.turkishName, () => []).add(d.dateStr);
      }
    }
  }
  return sonuc;
}

void main() {
  group('SeviyeServisi', () {
    test('unvan sınırları', () {
      expect(SeviyeServisi.unvanGetir(0), 'Talip');
      expect(SeviyeServisi.unvanGetir(999), 'Talip');
      expect(SeviyeServisi.unvanGetir(1000), 'Salik');
      expect(SeviyeServisi.unvanGetir(49999), 'Kamer');
      expect(SeviyeServisi.unvanGetir(50000), 'Süreyya');
    });
    test('ilerleme 0..1 aralığında', () {
      expect(SeviyeServisi.ilerlemeHesapla(0), 0.0);
      expect(SeviyeServisi.ilerlemeHesapla(500), closeTo(0.5, 1e-9));
      expect(SeviyeServisi.ilerlemeHesapla(60000), 1.0);
      expect(SeviyeServisi.ilerlemeHesapla(-10), 0.0);
    });
  });

  group('Türkçe büyük/küçük harf', () {
    test('trBuyuk', () {
      expect('İkindi'.trBuyuk, 'İKİNDİ');
      expect('Yatsı'.trBuyuk, 'YATSI');
      expect('Şanlıurfa'.trBuyuk, 'ŞANLIURFA');
    });
    test('trKucuk', () {
      expect('IĞDIR'.trKucuk, 'ığdır');
      expect('İSTANBUL'.trKucuk, 'istanbul');
    });
  });

  group('İl listesi', () {
    test('81 il, tekrar yok, Türkiye sınırları içinde', () {
      expect(iller.length, 81);
      expect(iller.map((i) => i.ad).toSet().length, 81);
      for (final il in iller) {
        expect(il.lat, inInclusiveRange(35.8, 42.2), reason: il.ad);
        expect(il.lng, inInclusiveRange(25.6, 44.9), reason: il.ad);
      }
      expect(ilBul('İstanbul'), isNotNull);
      expect(ilBul('Yok'), isNull);
    });
  });

  group('ContentModeration', () {
    const masumDualar = [
      "Allah'ım hasta olan arkadaşlarımıza şifa ver", // 'lan' ⊂ olan
      'Rabbim çocuklarımızı hayırlı evlat eyle', // 'oc' ⊂ çocuk
      'Hocamıza hayırlı uzun ömür nasip et', // 'oc' ⊂ hoca
      'Allahım bizi doğru yola götür', // 'göt' ⊂ götür
      'Sınavı kazanma imkanı ver Rabbim', // 'mk' ⊂ imkan
      'Kemal arkadaşıma acil şifalar diliyorum', // 'mal' ⊂ kemal
      'Yaptığım planları hayırlı eyle Rabbim', // 'lan' ⊂ plan
      'Normal doğum nasip etsin Allah', // 'mal' ⊂ normal
      'Rabbimiz, kâfirler topluluğuna karşı bize yardım et', // Bakara 286
    ];
    for (final dua in masumDualar) {
      test('kabul: $dua', () => expect(ContentModeration.metinDogrula(dua), isNull));
    }

    const uygunsuzlar = [
      'siktir git buradan arkadaşım',
      'bunlar hep salaklar ya',
      'amk bu ne biçim iş böyle',
      'ULAN ne oluyor burada böyle',
      'detaylar için www.ornek.com adresine bakın',
      'bana yazın ornek@gmail adresinden',
    ];
    for (final metin in uygunsuzlar) {
      test('red: $metin', () => expect(ContentModeration.metinDogrula(metin), isNotNull));
    }

    test('maskeleme yalnızca uygunsuz kelimeyi kapatır', () {
      expect(ContentModeration.icerikMaskele('Kemal salak değil'), 'Kemal ***** değil');
    });
  });

  group('DiniGunlerUtil — Diyanet 2025/2026 takvimiyle karşılaştırma', () {
    final gunler = _diniGunler();
    const beklenen = {
      // 2025
      'Regaib Kandili': ['2025-01-02', '2025-12-25', '2026-12-10'],
      'Mirac Kandili': ['2025-01-26', '2026-01-15'],
      'Berat Kandili': ['2025-02-13', '2026-02-02'],
      'Ramazan Başlangıcı': ['2025-03-01', '2026-02-19'],
      'Kadir Gecesi': ['2025-03-26', '2026-03-16'],
      'Ramazan Bayramı Arefesi': ['2025-03-29', '2026-03-19'],
      'Ramazan Bayramı': ['2025-03-30', '2026-03-20'],
      'Kurban Bayramı Arefesi': ['2025-06-05', '2026-05-26'],
      'Kurban Bayramı': ['2025-06-06', '2026-05-27'],
      'Hicri Yılbaşı': ['2025-06-26', '2026-06-16'],
      'Aşure Günü': ['2025-07-05', '2026-06-25'],
      'Mevlid Kandili': ['2025-09-03', '2026-08-24'],
    };
    beklenen.forEach((ad, tarihler) {
      for (final t in tarihler) {
        test('$ad $t', () => expect(gunler[ad], contains(t)));
      }
    });

    test('Kadir Gecesi her Ramazan bir kez (API tek ayda 5 kez "Lailat-ul-Qadr" döndürüyor)', () {
      expect(gunler['Kadir Gecesi'], unorderedEquals(['2025-03-26', '2026-03-16']));
    });
  });
}
