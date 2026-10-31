import 'package:intl/intl.dart';

extension DateTimeExt on DateTime {
  /// Zaman farkını okunabilir formata çevirir (12dk, 3sa, 5g)
  String get zamanFarki {
    final now = DateTime.now();
    final difference = now.difference(this);
    
    // Eğer cihaz saati ile sunucu saati arasında ufak farklar varsa (gelecek tarihli görünüyorsa)
    // veya fark 1 dakikadan az ise 'Az önce' döndür.
    if (difference.isNegative || difference.inSeconds < 60) {
      return 'Az önce';
    }

    if (difference.inMinutes < 60) return '${difference.inMinutes}dk';
    if (difference.inHours < 24) return '${difference.inHours}sa';
    if (difference.inDays < 7) return '${difference.inDays}g';
    return DateFormat('d MMM', 'tr_TR').format(this);
  }
}

extension TurkceMetinExt on String {
  /// Türkçe kurallarıyla büyük harf (i → İ, ı → I). Dart'ın toUpperCase'i "İKINDI" üretir.
  String get trBuyuk => replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

  /// Türkçe kurallarıyla küçük harf (İ → i, I → ı).
  String get trKucuk => replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();
}
