import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/constants/dualar.dart';
import 'kuran_okuyucu.dart';

/// Bir duayı sesli okur. Kur'an'dan olan dualar Afâsî tilavetiyle (kelime kelime zamanlamalı),
/// Kur'an dışı dualar telefonun Arapça yazıdan-sese motoruyla okunur; her iki durumda da
/// okunan kelime [aktifKelime] (0'dan) / ayet bazında [kuran] üzerinden izlenir.
class DuaOynatici extends ChangeNotifier {
  final Dua dua;
  KuranOkuyucu? _kuran;
  FlutterTts? _tts;

  bool _caliyor = false;
  bool _yukleniyor = false;
  String? hata;
  int? _ttsKelime;
  bool _kapatildi = false;

  /// Kur'an dışı duanın kelimeleri ve metindeki başlangıç konumları (TTS ilerlemesini kelimeye çevirmek için)
  late final List<(String, int)> kelimeler = _kelimelereAyir(dua.kurandan ? '' : dua.arapca);

  DuaOynatici(this.dua) {
    if (dua.kurandan) {
      _kuran = KuranOkuyucu([for (final a in dua.ayetler) (sure: dua.sure!, ayet: a)])..addListener(_bildir);
    }
  }

  KuranOkuyucu? get kuran => _kuran;
  bool get caliyor => _kuran?.caliyor ?? _caliyor;
  bool get yukleniyor => _kuran?.yukleniyor ?? _yukleniyor;
  /// Kur'an dışı duada okunan kelimenin sırası (0'dan)
  int? get aktifKelime => _ttsKelime;

  static List<(String, int)> _kelimelereAyir(String metin) => [
        for (final m in RegExp(r'\S+').allMatches(metin)) (m.group(0)!, m.start),
      ];

  Future<void> calDuraklat() async {
    if (_kuran != null) {
      await _kuran!.calDuraklat();
      hata = _kuran!.hata;
      _kuran!.hata = null;
      _bildir();
      return;
    }
    if (_caliyor) return durdur();
    await _ttsOku();
  }

  Future<void> _ttsOku() async {
    _yukleniyor = true;
    hata = null;
    _bildir();
    try {
      final tts = _tts ??= FlutterTts();
      final dil = await _arapcaDil(tts);
      if (dil == null) {
        hata = 'Telefonunda Arapça ses yok. Ayarlar > Metin okuma çıktısı bölümünden Arapça sesi indirebilirsin.';
        return;
      }
      await tts.setLanguage(dil);
      await tts.setSpeechRate(0.38); // Dua için yavaş ve anlaşılır
      tts.setProgressHandler((metin, bas, son, kelime) {
        // bas: okunan kelimenin metindeki konumu → kaçıncı kelime
        final i = kelimeler.lastIndexWhere((k) => k.$2 <= bas);
        if (i >= 0 && i != _ttsKelime) {
          _ttsKelime = i;
          _bildir();
        }
      });
      tts.setCompletionHandler(_bitti);
      tts.setCancelHandler(_bitti);
      tts.setErrorHandler((_) => _bitti());
      _caliyor = true;
      await tts.speak(dua.arapca);
    } catch (e) {
      debugPrint('🗣️ TTS hatası: $e');
      hata = 'Dua sesli okunamadı.';
      _caliyor = false;
    } finally {
      _yukleniyor = false;
      _bildir();
    }
  }

  static Future<String?> _arapcaDil(FlutterTts tts) async {
    for (final dil in ['ar-SA', 'ar']) {
      try {
        if (await tts.isLanguageAvailable(dil) == true) return dil;
      } catch (_) {}
    }
    return null;
  }

  void _bitti() {
    _caliyor = false;
    _ttsKelime = null;
    _bildir();
  }

  Future<void> durdur() async {
    await _kuran?.durdur();
    await _tts?.stop();
    _bitti();
  }

  void _bildir() {
    if (!_kapatildi) notifyListeners();
  }

  @override
  void dispose() {
    _kapatildi = true;
    _kuran?.dispose();
    _tts?.stop();
    super.dispose();
  }
}
