import 'package:flutter/services.dart';

/// Manyetometrenin anlık durumu (android/.../PusulaDurumu.kt).
class PusulaOkuma {
  const PusulaOkuma(this.durum, this.siddet);

  /// Android SENSOR_STATUS_*: 0 güvenilmez, 1 düşük, 2 orta, 3 yüksek
  final int durum;

  /// Ölçülen manyetik alan şiddeti (µT). Dünya'nın alanı 25-65 µT arasıdır;
  /// bunun çok dışı yakındaki bir mıknatıs/metal demektir.
  final double siddet;

  /// Kalibrasyon bozuk: rehber gösterilmeli
  bool get bozuk => durum <= 1;

  /// Çalışıyor ama hassasiyet tam değil
  bool get orta => durum == 2;

  bool get parazit => siddet < 20 || siddet > 70;
}

class PusulaKalibrasyonu {
  static const _kanal = EventChannel('namaz/pusula');

  /// Ekran açıkken dinlenir; dinleme bitince sensör bırakılır.
  static Stream<PusulaOkuma> okumalar() => _kanal.receiveBroadcastStream().map((e) {
        final m = e as Map;
        return PusulaOkuma((m['durum'] as num).toInt(), (m['siddet'] as num).toDouble());
      });
}
