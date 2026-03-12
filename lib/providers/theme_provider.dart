import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/theme/app_theme.dart';

class ThemeProvider extends ChangeNotifier {
  AppThemeData _aktifTema = AppThemeData.varsayilan();

  AppThemeData get aktifTema => _aktifTema;

  List<AppThemeData> get tumTemalar => AppThemeData.tumTemalar;

  ThemeProvider() {
    _temayiYukle();
  }

  Future<void> _temayiYukle() async {
    final prefs = await SharedPreferences.getInstance();
    final temaId = prefs.getString('secili_tema') ?? 'varsayilan';
    _aktifTema = AppThemeData.getById(temaId);
    notifyListeners();
  }

  Future<void> temaDegistir(String temaId) async {
    _aktifTema = AppThemeData.getById(temaId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('secili_tema', temaId);
    notifyListeners();
  }

  ThemeData buildThemeData() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: _aktifTema.arkaPlanRengi,
      primaryColor: _aktifTema.anaRenk,
      brightness: _aktifTema.brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _aktifTema.anaRenk,
        brightness: _aktifTema.brightness,
        surface: _aktifTema.arkaPlanRengi,
      ),
      fontFamily: 'Roboto',
      textTheme: TextTheme(
        bodyMedium: TextStyle(color: _aktifTema.yaziRengi, fontSize: 16),
        bodyLarge: TextStyle(
          color: _aktifTema.yaziRengi,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        displayLarge: TextStyle(
          color: _aktifTema.yaziRengi,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
