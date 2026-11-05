import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../core/constants/dualar.dart';
import 'kelime_deposu.dart';
import 'kuran_okuyucu.dart';

/// Bir duayı sesli okur. Kur'an'dan olan dualar Afâsî tilavetiyle (kelime kelime zamanlamalı),
/// Kur'an dışı dualar kayıtlı sesleri varsa onunla (kelime zamanlamalı, ayetlerdeki gibi takip),
/// yoksa telefonun Arapça yazıdan-sese motoruyla okunur. Okunan kelime [aktifKelime] (0'dan) ve
/// kelime içi [ilerleme] / ayet bazında [kuran] üzerinden izlenir.
class DuaOynatici extends ChangeNotifier {
  final Dua dua;
  KuranOkuyucu? _kuran;
  FlutterTts? _tts;
  AudioPlayer? _kayit;
  final List<StreamSubscription> _abonelikler = [];
  late final AyetKelime? _kayitZamani = dua.ses == null
      ? null
      : AyetKelime([for (final k in kelimeler) k.$1], dua.sesZamanlari);
  double _ilerleme = 0;

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
  /// Kayıtlı seste okunan kelimenin ne kadarının okunduğu (0..1). TTS'te null: süre tahmin edilir.
  double? get ilerleme => _kayitZamani == null ? null : _ilerleme;

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
    if (dua.ses != null) return _kayitCal();
    await _ttsOku();
  }

  Future<void> _kayitCal() async {
    _yukleniyor = true;
    hata = null;
    _bildir();
    try {
      final o = _kayit ??= _kayitOynaticisi();
      _caliyor = true;
      await o.play(AssetSource('sounds/dualar/${dua.ses}.mp3'));
    } catch (e) {
      debugPrint('🔊 Dua sesi hatası: $e');
      hata = 'Dua sesli okunamadı.';
      _caliyor = false;
    } finally {
      _yukleniyor = false;
      _bildir();
    }
  }

  AudioPlayer _kayitOynaticisi() {
    final o = AudioPlayer();
    _abonelikler
      ..add(o.onPlayerComplete.listen((_) => _bitti()))
      ..add(o.onPositionChanged.listen((sure) {
        if (!_caliyor) return;
        final k = _kayitZamani!.konum(sure.inMilliseconds);
        if (k == null) return;
        _ttsKelime = k.$1 - 1;
        _ilerleme = k.$2;
        _bildir();
      }));
    return o;
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
    _ilerleme = 0;
    _bildir();
  }

  Future<void> durdur() async {
    await _kuran?.durdur();
    await _tts?.stop();
    await _kayit?.stop();
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
    for (final a in _abonelikler) {
      a.cancel();
    }
    _kayit?.dispose();
    super.dispose();
  }
}
