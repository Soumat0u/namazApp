import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Bir duanın ezber durumu (aralıklı tekrar / Leitner kutuları)
class EzberDurumu {
  /// 0: yeni başlandı … 5: ezberlendi
  final int kutu;
  /// Bir sonraki tekrar günü ("yyyy-MM-dd")
  final String sonraki;
  const EzberDurumu(this.kutu, this.sonraki);

  static const enUstKutu = 5;
  bool get ezberlendi => kutu >= enUstKutu;
  bool get tekrarZamani => sonraki.compareTo(EzberServisi.bugun()) <= 0;
}

/// Duaların ezber takibi. Her "Bildim" bir üst kutuya taşır ve tekrar aralığını
/// uzatır (1, 3, 7, 14, 30 gün); "Zorlandım" iki kutu geri alır ve yarın sorar.
class EzberServisi extends ChangeNotifier {
  EzberServisi._();
  static final EzberServisi ornek = EzberServisi._();

  static const _anahtar = 'dua_ezber';
  static const _araliklar = [1, 3, 7, 14, 30, 30];
  static String bugun() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  Map<String, EzberDurumu> _durumlar = {};
  bool _yuklendi = false;

  Future<void> yukle() async {
    if (_yuklendi) return;
    final p = await SharedPreferences.getInstance();
    try {
      final m = json.decode(p.getString(_anahtar) ?? '{}') as Map<String, dynamic>;
      _durumlar = {
        for (final e in m.entries) e.key: EzberDurumu((e.value['kutu'] as num).toInt(), e.value['sonraki'] as String),
      };
    } catch (_) {}
    _yuklendi = true;
    notifyListeners();
  }

  EzberDurumu? durum(String dua) => _durumlar[dua];

  /// Tekrar günü gelmiş dualar
  List<String> get tekrarBekleyenler => [
        for (final e in _durumlar.entries)
          if (e.value.tekrarZamani) e.key,
      ];

  Future<void> sonuc(String dua, {required bool bildi}) async {
    final eski = _durumlar[dua]?.kutu ?? 0;
    final kutu = bildi ? (eski + 1).clamp(0, EzberDurumu.enUstKutu) : (eski - 2).clamp(0, EzberDurumu.enUstKutu);
    final gun = bildi ? _araliklar[kutu] : 1;
    final t = DateTime.now();
    _durumlar[dua] = EzberDurumu(kutu, DateFormat('yyyy-MM-dd').format(DateTime(t.year, t.month, t.day + gun)));
    await _kaydet();
  }

  Future<void> sifirla(String dua) async {
    _durumlar.remove(dua);
    await _kaydet();
  }

  Future<void> _kaydet() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_anahtar, json.encode({
      for (final e in _durumlar.entries) e.key: {'kutu': e.value.kutu, 'sonraki': e.value.sonraki},
    }));
    notifyListeners();
  }
}
