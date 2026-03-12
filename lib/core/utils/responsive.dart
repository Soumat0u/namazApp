import 'package:flutter/material.dart';

/// Responsive ölçekleme yardımcı sınıfı.
/// Tasarım referans boyutu: 375 x 812 (iPhone X benzeri)
class Responsive {
  static late double _screenWidth;
  static late double _screenHeight;
  static late double _scaleWidth;
  static late double _scaleHeight;
  static late double _scaleText;

  static const double _designWidth = 375.0;
  static const double _designHeight = 812.0;

  static void init(BuildContext context) {
    final size = MediaQuery.of(context).size;
    _screenWidth = size.width;
    _screenHeight = size.height;
    _scaleWidth = _screenWidth / _designWidth;
    _scaleHeight = _screenHeight / _designHeight;
    // Yazı ölçekleme: genişlik ve yükseklik ortalaması (daha dengeli)
    _scaleText = (_scaleWidth + _scaleHeight) / 2;
  }

  /// Genişlik bazlı ölçekleme (padding, margin, icon size vb.)
  static double w(double size) => size * _scaleWidth;

  /// Yükseklik bazlı ölçekleme
  static double h(double size) => size * _scaleHeight;

  /// Yazı boyutu ölçekleme (çok büyümemesi için clamp uygulanır)
  static double sp(double size) => size * _scaleText.clamp(0.8, 1.3);

  /// Ekran genişliği
  static double get screenWidth => _screenWidth;

  /// Ekran yüksekliği
  static double get screenHeight => _screenHeight;

  /// Ölçek oranı
  static double get scale => _scaleWidth;
}
