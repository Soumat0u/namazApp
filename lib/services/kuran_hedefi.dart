import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Günlük Kur'an okuma hedefi (sayfa). Uygulamada ekranda yeterince kalan
/// sayfalar kendiliğinden sayılır (KuranSureScreen); mushaftan okunanlar elle
/// eklenir. Son 60 günün sayısı saklanır.
class KuranHedefi extends ChangeNotifier {
  KuranHedefi._();
  static final KuranHedefi ornek = KuranHedefi._();

  static const secenekler = [1, 2, 3, 5, 10, 20];
  static const _anahtar = 'kuran_hedefi';

  /// Günlük hedef (sayfa); 0 = hedef yok
  int hedef = 0;
  Set<int> _bugunSayfalar = {};
  int _bugunElle = 0;
  String _gun = '';
  Map<String, int> gecmis = {}; // "yyyy-MM-dd" → okunan sayfa
  bool _yuklendi = false;

  static String _bugun() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  int get bugunOkunan {
    _gunuKontrolEt();
    return _bugunSayfalar.length + _bugunElle;
  }

  double get oran => hedef == 0 ? 0 : (bugunOkunan / hedef).clamp(0.0, 1.0);
  bool get tamamlandi => hedef > 0 && bugunOkunan >= hedef;

  Future<void> yukle() async {
    if (_yuklendi) return;
    final p = await SharedPreferences.getInstance();
    try {
      final m = json.decode(p.getString(_anahtar) ?? '{}') as Map<String, dynamic>;
      hedef = (m['hedef'] as num?)?.toInt() ?? 0;
      _gun = m['gun'] as String? ?? '';
      _bugunSayfalar = {for (final s in (m['sayfalar'] as List? ?? [])) (s as num).toInt()};
      _bugunElle = (m['elle'] as num?)?.toInt() ?? 0;
      gecmis = {for (final e in ((m['gecmis'] as Map?) ?? {}).entries) e.key as String: (e.value as num).toInt()};
    } catch (_) {}
    _yuklendi = true;
    _gunuKontrolEt();
    notifyListeners();
  }

  /// Gün değiştiyse bugünün sayacını sıfırla (dünkü geçmişte kalır)
  void _gunuKontrolEt() {
    final b = _bugun();
    if (_gun == b) return;
    _gun = b;
    _bugunSayfalar = {};
    _bugunElle = 0;
  }

  Future<void> hedefAyarla(int sayfa) async {
    hedef = sayfa;
    await _kaydet();
  }

  /// Uygulamada okunan bir sayfa (aynı sayfa günde bir kez sayılır)
  Future<void> sayfaOkundu(int sayfa) async {
    _gunuKontrolEt();
    if (!_bugunSayfalar.add(sayfa)) return;
    await _kaydet();
  }

  /// Mushaftan okunan sayfalar
  Future<void> elleEkle(int adet) async {
    _gunuKontrolEt();
    _bugunElle = (_bugunElle + adet).clamp(0, 604);
    await _kaydet();
  }

  Future<void> _kaydet() async {
    gecmis[_gun] = _bugunSayfalar.length + _bugunElle;
    final esik = DateFormat('yyyy-MM-dd').format(DateTime.now().subtract(const Duration(days: 60)));
    gecmis.removeWhere((k, _) => k.compareTo(esik) < 0);
    final p = await SharedPreferences.getInstance();
    await p.setString(_anahtar, json.encode({
      'hedef': hedef,
      'gun': _gun,
      'sayfalar': _bugunSayfalar.toList(),
      'elle': _bugunElle,
      'gecmis': gecmis,
    }));
    notifyListeners();
  }
}
