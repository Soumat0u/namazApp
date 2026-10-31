import 'extensions.dart';

/// Dua Duvarı için içerik moderasyonu.
/// Uygunsuz kelimeleri filtreleyerek meclisin nezaketini korur.
///
/// Kelimeler metnin içinde parça olarak değil, kelime bazında aranır;
/// aksi halde "olan", "çocuk", "hoca", "götür", "imkan" gibi masum kelimeler de yakalanır.
class ContentModeration {
  /// Sadece birebir aynı kelime olarak geçtiğinde engellenenler (kısa / başka kelimelerin içinde geçebilenler)
  static const Set<String> _tamKelimeler = {
    'amk', 'aq', 'mk', 'mq', 'oç', 'oc',
    'piç', 'lan', 'ulan', 'bok', 'yarak', 'göt', 'mal',
  };

  /// Kelimenin başında geçtiğinde engellenenler (çekim ekleri de yakalansın diye: "salaklar", "orospular")
  static const List<String> _kokler = [
    'siktir', 'sikeyim', 'sikerim', 'siktiğimin',
    'orospu', 'pezevenk', 'kahpe', 'yarrak',
    'gerizekalı', 'salak', 'aptal',
    // Nefret söylemi
    'gavur',
  ];

  /// Metnin herhangi bir yerinde geçtiğinde engellenen spam / iletişim kalıpları
  static const List<String> _spamKaliplari = [
    'http://', 'https://', 'www.',
    '.com', '.net', '.org',
    '@gmail', '@hotmail', '@outlook',
  ];

  static final RegExp _ayirici = RegExp(r"[^a-zçğıöşüâîû0-9]+");

  static List<String> _kelimeler(String metin) =>
      metin.trKucuk.split(_ayirici).where((k) => k.isNotEmpty).toList();

  static bool _uygunsuzKelimeMi(String kelime) =>
      _tamKelimeler.contains(kelime) || _kokler.any(kelime.startsWith);

  /// Verilen metni kara listeye karşı kontrol eder.
  /// Uygunsuz kelime bulursa `false` döner.
  static bool icerikUygunMu(String metin) {
    final kucukHarf = metin.trKucuk;
    if (_spamKaliplari.any(kucukHarf.contains)) return false;
    return !_kelimeler(metin).any(_uygunsuzKelimeMi);
  }

  /// Uygunsuz kelimeleri yıldızlarla maskeler (opsiyonel kullanım)
  static String icerikMaskele(String metin) {
    return metin.splitMapJoin(
      RegExp(r"[A-Za-zÇĞİÖŞÜÂÎÛçğıöşüâîû0-9]+"),
      onMatch: (m) {
        final kelime = m[0]!;
        return _uygunsuzKelimeMi(kelime.trKucuk) ? '*' * kelime.length : kelime;
      },
    );
  }

  /// Minimum uzunluk ve anlamlılık kontrolü
  static String? metinDogrula(String metin) {
    final temiz = metin.trim();
    if (temiz.isEmpty) return 'Dua metni boş olamaz.';
    if (temiz.length < 10) return 'Dua en az 10 karakter olmalıdır.';
    if (temiz.length > 500) return 'Dua en fazla 500 karakter olabilir.';
    if (!icerikUygunMu(temiz)) return 'Duanız uygunsuz içerik barındırıyor. Lütfen meclisin nezaketine uygun bir dil kullanın.';
    return null; // Hata yok
  }
}
