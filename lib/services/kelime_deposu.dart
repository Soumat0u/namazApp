import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

/// Bir ayetin kelimeleri ve tilavetteki zamanlamaları (Quran.com, Afâsî)
class AyetKelime {
  final List<String> kelimeler;
  /// (kelime sırası 1'den, başlangıç ms, bitiş ms)
  final List<(int, int, int)> zamanlar;
  const AyetKelime(this.kelimeler, this.zamanlar);

  /// Ses [ms] konumundayken okunan kelimenin sırası (1'den), yoksa null
  int? kelimeAt(int ms) {
    for (final (sira, bas, son) in zamanlar) {
      if (ms >= bas && ms <= son) return sira;
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
        'k': kelimeler,
        'z': [for (final (s, b, e) in zamanlar) [s, b, e]],
      };

  factory AyetKelime.fromJson(Map<String, dynamic> j) => AyetKelime(
        List<String>.from(j['k']),
        [for (final z in j['z'] as List) ((z[0] as num).toInt(), (z[1] as num).toInt(), (z[2] as num).toInt())],
      );
}

/// Surelerin kelime/zaman verisini Quran.com API'den alır ve telefona kaydeder (sonra internetsiz kullanılır)
class KelimeDeposu {
  static final Map<int, Map<int, AyetKelime>> _bellek = {};

  static Future<File> _dosya(int sure) async {
    final kok = await getApplicationDocumentsDirectory();
    final dizin = Directory('${kok.path}/kuran_kelime');
    if (!await dizin.exists()) await dizin.create(recursive: true);
    return File('${dizin.path}/$sure.json');
  }

  /// Önce bellek, sonra telefondaki kayıt, en son internet. Hiçbiri yoksa null.
  static Future<Map<int, AyetKelime>?> yukle(int sure) async {
    if (_bellek.containsKey(sure)) return _bellek[sure];
    try {
      final f = await _dosya(sure);
      if (await f.exists()) {
        final ham = json.decode(await f.readAsString()) as Map<String, dynamic>;
        return _bellek[sure] = {for (final e in ham.entries) int.parse(e.key): AyetKelime.fromJson(e.value)};
      }
      final veri = await _indir(sure);
      await f.writeAsString(json.encode({for (final e in veri.entries) '${e.key}': e.value.toJson()}));
      return _bellek[sure] = veri;
    } catch (e) {
      debugPrint('🔤 Kelime verisi alınamadı ($sure): $e');
      return null;
    }
  }

  static Future<Map<int, AyetKelime>> _indir(int sure) async {
    final sonuc = <int, AyetKelime>{};
    int? sayfa = 1;
    while (sayfa != null) {
      final url = Uri.parse('https://api.quran.com/api/v4/verses/by_chapter/$sure'
          '?words=true&audio=7&per_page=50&page=$sayfa&word_fields=text_uthmani');
      final cevap = await http.get(url).timeout(const Duration(seconds: 20));
      if (cevap.statusCode != 200) throw Exception('HTTP ${cevap.statusCode}');
      final d = json.decode(utf8.decode(cevap.bodyBytes)) as Map<String, dynamic>;
      for (final v in d['verses'] as List) {
        final ayet = int.parse((v['verse_key'] as String).split(':')[1]);
        final kelimeler = [
          for (final w in v['words'] as List)
            if (w['char_type_name'] == 'word') w['text_uthmani'] as String,
        ];
        final zamanlar = [
          for (final s in (v['audio']?['segments'] as List? ?? const []))
            if ((s as List).length >= 4) ((s[1] as num).toInt(), (s[2] as num).toInt(), (s[3] as num).toInt()),
        ];
        sonuc[ayet] = AyetKelime(kelimeler, zamanlar);
      }
      sayfa = d['pagination']?['next_page'] as int?;
    }
    return sonuc;
  }
}
