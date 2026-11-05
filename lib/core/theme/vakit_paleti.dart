import 'package:flutter/material.dart';

/// Vakitlerin renkleri: tek kaynak. Ana sayfadaki saat kartı
/// (vakit_background.dart) bu geçişleri olduğu gibi kullanır; sayfa arka
/// planı (sayfa_arka_plani.dart) aynı renklerden hafif bir ton alır. Böylece
/// kart, zemin ve tema birbirinden kopuk görünmez.
class VakitPaleti {
  static const Map<String, List<Color>> _gecisler = {
    'dawn': [Color(0xFF2C3E50), Color(0xFFFD746C)],
    'morning': [Color(0xFF4facfe), Color(0xFF00f2fe)],
    'day': [Color(0xFF2980B9), Color(0xFF6DD5FA)],
    'afternoon': [Color(0xFFf093fb), Color(0xFFf5576c)],
    'sunset': [Color(0xFF434343), Color(0xFF000000)],
    'night': [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
  };

  /// Saat kartının renk geçişi
  static List<Color> gecis(String vakit) => _gecisler[vakit] ?? _gecisler['night']!;

  /// Vaktin tek bir temsilci rengi (geçişin ortası)
  static Color ton(String vakit) {
    final g = gecis(vakit);
    return Color.lerp(g.first, g.last, 0.5)!;
  }
}
