import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart' as quran;

import 'kelime_deposu.dart';

/// Ayet ayet Kur'an tilaveti, kelime kelime takip.
/// [aktifIndex] okunan ayet, [aktifKelime] o ayette okunan kelimenin sırasıdır (1'den);
/// ekran bunları dinleyip vurgular ve kaydırır.
/// Ses ve kelime zamanlamaları: Quran.com (Mişârî Râşid el-Afâsî).
class KuranOkuyucu extends ChangeNotifier {
  final AudioPlayer _oynatici = AudioPlayer();
  final List<({int sure, int ayet})> ayetler;
  final List<StreamSubscription> _abonelikler = [];

  int? _aktifIndex;

  /// Okunan yer: ayet sırası, kelime (1'den) ve kelime içi ilerleme (0..1).
  /// Her karede güncellenir; yalnızca o ayetin metni dinler (sayfanın tamamı yeniden çizilmez).
  final ValueNotifier<({int index, int kelime, double ilerleme})?> konum = ValueNotifier(null);
  bool _caliyor = false;
  bool _yukleniyor = false;
  String? hata;
  bool _kapatildi = false;

  /// Sure → ayet → kelimeler/zamanlar. Yüklenene kadar (veya internet yoksa) null: ayet düzeyinde vurgulanır.
  final Map<int, Map<int, AyetKelime>> kelimeVerisi = {};

  KuranOkuyucu(this.ayetler) {
    _abonelikler
      ..add(_oynatici.onPlayerComplete.listen((_) => _sonraki()))
      ..add(_oynatici.onPositionChanged.listen(_konumDegisti));
    for (final s in {for (final a in ayetler) a.sure}) {
      KelimeDeposu.yukle(s).then((v) {
        if (v != null) {
          kelimeVerisi[s] = v;
          _bildir();
        }
      });
    }
  }

  /// Bir surenin tüm ayetleri için
  factory KuranOkuyucu.sure(int sure) =>
      KuranOkuyucu([for (int a = 1; a <= quran.getVerseCount(sure); a++) (sure: sure, ayet: a)]);

  int? get aktifIndex => _aktifIndex;
  int? get aktifKelime => konum.value?.kelime;

  /// Okuma hızı (0.5–1.5). Kelime zamanlaması kaydın kendi zamanıyla ölçüldüğü için ışık kaymaz.
  double _hiz = 1.0;
  double get hiz => _hiz;
  Future<void> hizAyarla(double hiz) async {
    _hiz = hiz;
    try {
      await _oynatici.setPlaybackRate(hiz);
    } catch (_) {}
    _bildir();
  }
  ({int sure, int ayet})? get aktifAyet => _aktifIndex == null ? null : ayetler[_aktifIndex!];
  bool get caliyor => _caliyor;
  bool get yukleniyor => _yukleniyor;

  AyetKelime? kelimeler(int sure, int ayet) => kelimeVerisi[sure]?[ayet];

  /// Mushaf'taki genel ayet sırası (1..6236)
  static int genelAyetNo(int sure, int ayet) {
    var toplam = 0;
    for (int s = 1; s < sure; s++) {
      toplam += quran.getVerseCount(s);
    }
    return toplam + ayet;
  }

  /// "002255" biçimi: Quran.com ses dosyalarının adı
  static String dosyaAdi(int sure, int ayet) =>
      '${sure.toString().padLeft(3, '0')}${ayet.toString().padLeft(3, '0')}';

  static String sesAdresi(int sure, int ayet) => 'https://verses.quran.com/Alafasy/mp3/${dosyaAdi(sure, ayet)}.mp3';

  void _konumDegisti(Duration sure) {
    final i = _aktifIndex;
    if (i == null || _kapatildi) return;
    final a = ayetler[i];
    final k = kelimeler(a.sure, a.ayet)?.konum(sure.inMilliseconds);
    if (k != null) konum.value = (index: i, kelime: k.$1, ilerleme: k.$2);
  }

  Future<void> baslat([int index = 0]) async {
    if (index < 0 || index >= ayetler.length) return;
    _aktifIndex = index;
    konum.value = null;
    _caliyor = true;
    _yukleniyor = true;
    hata = null;
    _bildir();
    try {
      final a = ayetler[index];
      // İndirilmişse telefondan (internetsiz), yoksa internetten çal
      final yerel = await KuranSesDeposu.dosya(a.sure, a.ayet);
      await _oynatici.play(await yerel.exists() ? DeviceFileSource(yerel.path) : UrlSource(sesAdresi(a.sure, a.ayet)));
      if (_hiz != 1.0) await _oynatici.setPlaybackRate(_hiz);
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
    konum.value = null;
    _bildir();
  }

  void _sonraki() {
    final i = (_aktifIndex ?? -1) + 1;
    if (i < ayetler.length) {
      baslat(i);
    } else {
      _caliyor = false;
      _aktifIndex = null;
      konum.value = null;
      _bildir();
    }
  }

  void _bildir() {
    if (!_kapatildi) notifyListeners();
  }

  @override
  void dispose() {
    _kapatildi = true;
    konum.dispose();
    for (final a in _abonelikler) {
      a.cancel();
    }
    _oynatici.dispose();
    super.dispose();
  }
}

/// Tilavet seslerini telefona indirir: indirilen sureler internetsiz dinlenebilir
class KuranSesDeposu {
  static Directory? _klasor;

  static Future<Directory> _dizin() async {
    if (_klasor != null) return _klasor!;
    final kok = await getApplicationDocumentsDirectory();
    _klasor = Directory('${kok.path}/kuran_ses_alafasy');
    if (!await _klasor!.exists()) await _klasor!.create(recursive: true);
    return _klasor!;
  }

  static Future<File> dosya(int sure, int ayet) async =>
      File('${(await _dizin()).path}/${KuranOkuyucu.dosyaAdi(sure, ayet)}.mp3');

  static Future<bool> indirildiMi(int sure) async {
    for (int a = 1; a <= quran.getVerseCount(sure); a++) {
      if (!await (await dosya(sure, a)).exists()) return false;
    }
    return true;
  }

  /// Surenin eksik ayet seslerini ve kelime zamanlamalarını indirir; [ilerleme] 0..1. Hata olursa mesaj döner.
  static Future<String?> indir(int sure, {void Function(double)? ilerleme}) async {
    final adet = quran.getVerseCount(sure);
    try {
      if (await KelimeDeposu.yukle(sure) == null) throw Exception('Kelime verisi alınamadı');
      for (int a = 1; a <= adet; a++) {
        final f = await dosya(sure, a);
        if (!await f.exists()) {
          final cevap = await http.get(Uri.parse(KuranOkuyucu.sesAdresi(sure, a))).timeout(const Duration(seconds: 30));
          if (cevap.statusCode != 200) throw Exception('HTTP ${cevap.statusCode}');
          // Yarım kalan dosya "indirilmiş" sayılmasın: önce geçici dosyaya yaz
          final gecici = File('${f.path}.part');
          await gecici.writeAsBytes(cevap.bodyBytes);
          await gecici.rename(f.path);
        }
        ilerleme?.call(a / adet);
      }
      return null;
    } catch (e) {
      debugPrint('⬇️ Sure indirme hatası: $e');
      return 'İndirme tamamlanamadı. İnternet bağlantınızı kontrol edin.';
    }
  }

  static Future<void> sil(int sure) async {
    for (int a = 1; a <= quran.getVerseCount(sure); a++) {
      final f = await dosya(sure, a);
      if (await f.exists()) await f.delete();
    }
  }
}
