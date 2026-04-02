/// Dua Duvarı için içerik moderasyonu.
/// Uygunsuz kelimeleri filtreleyerek meclisin nezaketini korur.
class ContentModeration {
  /// Kara listedeki kelimeler (Türkçe uygunsuz içerik)
  static final List<String> _karaListe = [
    // Küfürler ve argo
    'amk', 'aq', 'mk', 'mq', 'oç', 'oc',
    'siktir', 'sikeyim', 'sikerim', 'siktiğimin',
    'orospu', 'piç', 'pezevenk', 'kahpe',
    'lan', 'ulan',
    'bok', 'yarrak', 'yarak', 'göt',
    'gerizekalı', 'salak', 'aptal', 'mal',
    // Nefret söylemi
    'gavur', 'kafir',
    // Spam kalıpları
    'http://', 'https://', 'www.',
    '.com', '.net', '.org',
    // İletişim bilgisi paylaşımı
    '@gmail', '@hotmail', '@outlook',
  ];

  /// Verilen metni kara listeye karşı kontrol eder.
  /// Uygunsuz kelime bulursa `false` döner.
  static bool icerikUygunMu(String metin) {
    final kucukHarf = metin.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
    
    for (final kelime in _karaListe) {
      if (kucukHarf.contains(kelime.toLowerCase())) {
        return false;
      }
    }
    return true;
  }

  /// Uygunsuz kelimeleri yıldızlarla maskeler (opsiyonel kullanım)
  static String icerikMaskele(String metin) {
    String maskelenmis = metin;
    for (final kelime in _karaListe) {
      final regex = RegExp(kelime, caseSensitive: false);
      maskelenmis = maskelenmis.replaceAll(regex, '*' * kelime.length);
    }
    return maskelenmis;
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
