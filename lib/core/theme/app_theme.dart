import 'package:flutter/material.dart';

/// Her temanın renk setini tutan veri sınıfı
class AppThemeData {
  final String id;
  final String isim;
  final Color arkaPlanRengi;
  final Color kartRengi;
  final Color anaRenk;
  final Color yaziRengi;
  final Color pasifRenk;
  final Color aktifRenk;
  final Color kirmizi;
  final Brightness brightness;

  const AppThemeData({
    required this.id,
    required this.isim,
    required this.arkaPlanRengi,
    required this.kartRengi,
    required this.anaRenk,
    required this.yaziRengi,
    required this.pasifRenk,
    required this.aktifRenk,
    required this.kirmizi,
    required this.brightness,
  });

  // ─── VARSAYILAN (AÇIK) ───
  factory AppThemeData.varsayilan() => const AppThemeData(
    id: 'varsayilan',
    isim: 'Varsayılan',
    arkaPlanRengi: Color.fromARGB(255, 255, 249, 232),
    kartRengi: Color(0xFFFFFFFF),
    anaRenk: Color(0xFFE67E22),
    yaziRengi: Color(0xFF3E2723),
    pasifRenk: Color(0xFFBCAAA4),
    aktifRenk: Color.fromARGB(255, 255, 177, 75),
    kirmizi: Color(0xFFD32F2F),
    brightness: Brightness.light,
  );

  // ─── ZÜMRÜT ───
  factory AppThemeData.zumrut() => const AppThemeData(
    id: 'zumrut',
    isim: 'Zümrüt',
    arkaPlanRengi: Color.fromARGB(255, 234, 249, 216),
    kartRengi: Color(0xFFFFFFFF),
    anaRenk: Color(0xFF2E7D32),
    yaziRengi: Color(0xFF1B5E20),
    pasifRenk: Color(0xFFBDBDBD), // Daha belirgin gri
    aktifRenk: Color.fromARGB(255, 126, 186, 133),
    kirmizi: Color(0xFFD32F2F),
    brightness: Brightness.light,
  );

  // ─── OKYANUS ───
  factory AppThemeData.okyanus() => const AppThemeData(
    id: 'okyanus',
    isim: 'Okyanus',
    arkaPlanRengi: Color.fromARGB(255, 218, 238, 251),
    kartRengi: Color(0xFFFFFFFF),
    anaRenk: Color(0xFF1565C0),
    yaziRengi: Color(0xFF0D47A1),
    pasifRenk: Color(0xFFBDBDBD), // Daha belirgin gri
    aktifRenk: Color.fromARGB(255, 130, 205, 255),
    kirmizi: Color(0xFFD32F2F),
    brightness: Brightness.light,
  );

  // ─── ZÜMRÜT KARANLIK ───
  factory AppThemeData.zumrutKaranlik() => const AppThemeData(
    id: 'zumrut_karanlik',
    isim: 'Zümrüt Karanlık',
    arkaPlanRengi: Color(0xFF121212),
    kartRengi: Color(0xFF1E1E1E),
    anaRenk: Color(0xFF4CAF50),
    yaziRengi: Color(0xFFE0E0E0),
    pasifRenk: Color(0xFF757575),
    aktifRenk: Color(0xFF81C784),
    kirmizi: Color(0xFFEF5350),
    brightness: Brightness.dark,
  );

  // ─── OKYANUS KARANLIK ───
  factory AppThemeData.okyanusKaranlik() => const AppThemeData(
    id: 'okyanus_karanlik',
    isim: 'Okyanus Karanlık',
    arkaPlanRengi: Color(0xFF121212),
    kartRengi: Color(0xFF1E1E1E),
    anaRenk: Color(0xFF42A5F5),
    yaziRengi: Color(0xFFE0E0E0),
    pasifRenk: Color(0xFF757575),
    aktifRenk: Color(0xFF90CAF9),
    kirmizi: Color(0xFFEF5350),
    brightness: Brightness.dark,
  );

  // ─── KARANLIK (VARSAYILAN KARANLIK) ───
  factory AppThemeData.karanlik() => const AppThemeData(
    id: 'karanlik',
    isim: 'Karanlık',
    arkaPlanRengi: Color(0xFF121212),
    kartRengi: Color(0xFF1E1E1E),
    anaRenk: Color(0xFFFFB74D),
    yaziRengi: Color(0xFFE0E0E0),
    pasifRenk: Color(0xFF757575),
    aktifRenk: Color(0xFFFFCC80),
    kirmizi: Color(0xFFEF5350),
    brightness: Brightness.dark,
  );

  /// Tüm mevcut temalar
  static List<AppThemeData> tumTemalar = [
    AppThemeData.varsayilan(),
    AppThemeData.karanlik(),
    AppThemeData.zumrut(),
    AppThemeData.zumrutKaranlik(),
    AppThemeData.okyanus(),
    AppThemeData.okyanusKaranlik(),
  ];

  /// ID'ye göre tema bul
  static AppThemeData getById(String id) {
    return tumTemalar.firstWhere(
      (t) => t.id == id,
      orElse: () => AppThemeData.varsayilan(),
    );
  }
}
