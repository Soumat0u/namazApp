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
  final Color aktifYesil;
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
    required this.aktifYesil,
    required this.kirmizi,
    required this.brightness,
  });

  // ─── VARSAYILAN (AÇIK) ───
  factory AppThemeData.varsayilan() => const AppThemeData(
        id: 'varsayilan',
        isim: 'Varsayılan',
        arkaPlanRengi: Color(0xFFFFFDF5),
        kartRengi: Color(0xFFFFFFFF),
        anaRenk: Color(0xFFE67E22),
        yaziRengi: Color(0xFF3E2723),
        pasifRenk: Color(0xFFBCAAA4),
        aktifYesil: Color(0xFF2E7D32),
        kirmizi: Color(0xFFD32F2F),
        brightness: Brightness.light,
      );

  // ─── KARANLIK ───
  factory AppThemeData.karanlik() => const AppThemeData(
        id: 'karanlik',
        isim: 'Karanlık',
        arkaPlanRengi: Color(0xFF121212),
        kartRengi: Color(0xFF1E1E1E),
        anaRenk: Color(0xFFFFB74D),
        yaziRengi: Color(0xFFE0E0E0),
        pasifRenk: Color(0xFF757575),
        aktifYesil: Color(0xFF66BB6A),
        kirmizi: Color(0xFFEF5350),
        brightness: Brightness.dark,
      );

  // ─── ZÜMRÜT ───
  factory AppThemeData.zumrut() => const AppThemeData(
        id: 'zumrut',
        isim: 'Zümrüt',
        arkaPlanRengi: Color(0xFFF1F8E9),
        kartRengi: Color(0xFFFFFFFF),
        anaRenk: Color(0xFF2E7D32),
        yaziRengi: Color(0xFF1B5E20),
        pasifRenk: Color(0xFFA5D6A7),
        aktifYesil: Color(0xFF388E3C),
        kirmizi: Color(0xFFD32F2F),
        brightness: Brightness.light,
      );

  // ─── OKYANUS ───
  factory AppThemeData.okyanus() => const AppThemeData(
        id: 'okyanus',
        isim: 'Okyanus',
        arkaPlanRengi: Color(0xFFE3F2FD),
        kartRengi: Color(0xFFFFFFFF),
        anaRenk: Color(0xFF1565C0),
        yaziRengi: Color(0xFF0D47A1),
        pasifRenk: Color(0xFF90CAF9),
        aktifYesil: Color(0xFF2E7D32),
        kirmizi: Color(0xFFD32F2F),
        brightness: Brightness.light,
      );

  /// Tüm mevcut temalar
  static List<AppThemeData> tumTemalar = [
    AppThemeData.varsayilan(),
    AppThemeData.karanlik(),
    AppThemeData.zumrut(),
    AppThemeData.okyanus(),
  ];

  /// ID'ye göre tema bul
  static AppThemeData getById(String id) {
    return tumTemalar.firstWhere(
      (t) => t.id == id,
      orElse: () => AppThemeData.varsayilan(),
    );
  }
}
