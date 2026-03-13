import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../theme/app_theme.dart';

/// BuildContext extension ile dinamik tema renklerine erişim sağlar.
/// Kullanım: `final renkler = context.renkler;` sonra `renkler.arkaPlanRengi` vb.
extension AppColorsExtension on BuildContext {
  AppThemeColors get renkler {
    final tema = watch<ThemeProvider>().aktifTema;
    return AppThemeColors(tema);
  }

  /// listen: false versiyonu (callback, initState gibi yerlerde)
  AppThemeColors get renklerOku {
    final tema = read<ThemeProvider>().aktifTema;
    return AppThemeColors(tema);
  }
}

class AppThemeColors {
  final AppThemeData _tema;

  AppThemeColors(this._tema);

  Color get arkaPlanRengi => _tema.arkaPlanRengi;
  Color get kartRengi => _tema.kartRengi;
  Color get anaRenk => _tema.anaRenk;
  Color get yaziRengi => _tema.yaziRengi;
  Color get pasifRenk => _tema.pasifRenk;
  Color get aktifYesil => _tema.aktifYesil;
  Color get kirmizi => _tema.kirmizi;
}

/// Geriye uyumluluk için statik renkler (varsayılan tema).
/// Tercihen context.renkler kullanın.
class AppColors {
  static const Color arkaPlanRengi = Color(0xFFFFFDF5);
  static const Color kartRengi = Color(0xFFFFFFFF);
  static const Color anaRenk = Color(0xFFE67E22);
  static const Color yaziRengi = Color(0xFF3E2723);
  static const Color pasifRenk = Color(0xFFBCAAA4);
  static const Color aktifYesil = Color(0xFF2E7D32);
  static const Color kirmizi = Color(0xFFD32F2F);
}
