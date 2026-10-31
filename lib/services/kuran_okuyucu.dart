import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:quran/quran.dart' as quran;

/// Ayet ayet Kur'an tilaveti. Ayetler sırayla çalınır; [aktifIndex] o an okunan ayeti gösterir
/// (ekran bunu dinleyip vurgular ve kaydırır).
/// Ses: Islamic Network CDN, Mişârî Râşid el-Afâsî (ayet başına bir mp3, ücretsiz).
class KuranOkuyucu extends ChangeNotifier {
  static const String _kari = 'ar.alafasy';

  final AudioPlayer _oynatici = AudioPlayer();
  final List<({int sure, int ayet})> ayetler;
  late final StreamSubscription<void> _bitisAboneligi;

  int? _aktifIndex;
  bool _caliyor = false;
  bool _yukleniyor = false;
  String? hata;
  bool _kapatildi = false;

  KuranOkuyucu(this.ayetler) {
    _bitisAboneligi = _oynatici.onPlayerComplete.listen((_) => _sonraki());
  }

  /// Bir surenin tüm ayetleri için
  factory KuranOkuyucu.sure(int sure) =>
      KuranOkuyucu([for (int a = 1; a <= quran.getVerseCount(sure); a++) (sure: sure, ayet: a)]);

  int? get aktifIndex => _aktifIndex;
  ({int sure, int ayet})? get aktifAyet => _aktifIndex == null ? null : ayetler[_aktifIndex!];
  bool get caliyor => _caliyor;
  bool get yukleniyor => _yukleniyor;

  /// Mushaf'taki genel ayet sırası (1..6236): CDN dosyaları bu numarayla adlandırılmış
  static int genelAyetNo(int sure, int ayet) {
    var toplam = 0;
    for (int s = 1; s < sure; s++) {
      toplam += quran.getVerseCount(s);
    }
    return toplam + ayet;
  }

  static String sesAdresi(int sure, int ayet) =>
      'https://cdn.islamic.network/quran/audio/128/$_kari/${genelAyetNo(sure, ayet)}.mp3';

  Future<void> baslat([int index = 0]) async {
    if (index < 0 || index >= ayetler.length) return;
    _aktifIndex = index;
    _caliyor = true;
    _yukleniyor = true;
    hata = null;
    _bildir();
    try {
      final a = ayetler[index];
      await _oynatici.play(UrlSource(sesAdresi(a.sure, a.ayet)));
    } catch (e) {
      debugPrint('🔊 Tilavet hatası: $e');
      hata = 'Ses yüklenemedi. İnternet bağlantınızı kontrol edin.';
      _caliyor = false;
    } finally {
      _yukleniyor = false;
      _bildir();
    }
  }

  Future<void> duraklat() async {
    await _oynatici.pause();
    _caliyor = false;
    _bildir();
  }

  Future<void> devamEt() async {
    if (_aktifIndex == null) return baslat();
    await _oynatici.resume();
    _caliyor = true;
    _bildir();
  }

  Future<void> calDuraklat() => _caliyor ? duraklat() : devamEt();

  Future<void> durdur() async {
    await _oynatici.stop();
    _caliyor = false;
    _aktifIndex = null;
    _bildir();
  }

  void _sonraki() {
    final i = (_aktifIndex ?? -1) + 1;
    if (i < ayetler.length) {
      baslat(i);
    } else {
      _caliyor = false;
      _aktifIndex = null;
      _bildir();
    }
  }

  void _bildir() {
    if (!_kapatildi) notifyListeners();
  }

  @override
  void dispose() {
    _kapatildi = true;
    _bitisAboneligi.cancel();
    _oynatici.dispose();
    super.dispose();
  }
}
