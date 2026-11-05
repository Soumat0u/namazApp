import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/religious_day.dart';
import '../core/utils/dini_gunler_util.dart';

class NamazServisi {
  // Aynı ay için hem vakit takvimi hem dini günler istendiğinde tek istek atılsın
  final Map<String, Future<List<dynamic>>> _takvimOnbellegi = {};

  // izinIste parametresi: Sadece kullanıcı butona bastığında true olur.
  Future<Position?> konumGetir({bool izinIste = false}) async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Konum servisleri kapalı.');
    }

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      if (izinIste) {
        // Sadece kullanıcı tetiklediyse izin ekranını çıkar
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Konum izni reddedildi.');
        }
      } else {
        // Uygulama yeni açıldı, izin yok, kullanıcıyı darlama (Cache kullanılacak)
        return null;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Konum izinleri kalıcı olarak kapatılmış. Ayarlardan açmalısınız.',
      );
    }

    // Vakit hesabı için şehir seviyesinde doğruluk yeterli; kapalı alanda hızlı sonuç verir.
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } on TimeoutException {
      // GPS zamanında cevap vermezse son bilinen konumu kullan
      final sonKonum = await Geolocator.getLastKnownPosition();
      if (sonKonum != null) return sonKonum;
      rethrow;
    }
  }

  Future<Map<String, String>> vakitleriGetir(Position position) async {
    final url = Uri.https('api.aladhan.com', '/v1/timings', {
      'latitude': '${position.latitude}',
      'longitude': '${position.longitude}',
      'method': '13',
    });
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data']['timings'];
      return _parseAladhanData(data);
    } else {
      throw Exception('API hatası: ${response.statusCode}');
    }
  }

  Map<String, String> _parseAladhanData(Map<String, dynamic> data) {
    // Takvim uç noktası saatleri "05:12 (+03)" biçiminde döner
    String temiz(String? s) => (s ?? '').split(' ').first;
    return {
      "Sabah": temiz(data['Fajr']),
      "Güneş": temiz(data['Sunrise']),
      "Öğle": temiz(data['Dhuhr']),
      "İkindi": temiz(data['Asr']),
      "Akşam": temiz(data['Maghrib']),
      "Yatsı": temiz(data['Isha']),
      "GünBatımı": temiz(data['Sunset']),
    };
  }

  /// Aylık takvimi ham haliyle getirir (vakitler + hicri tarih).
  Future<List<dynamic>> _aylikTakvim(int year, int month, Position position) {
    final anahtar =
        '${position.latitude.toStringAsFixed(3)},${position.longitude.toStringAsFixed(3)},$year,$month';
    return _takvimOnbellegi.putIfAbsent(anahtar, () async {
      final url = Uri.https('api.aladhan.com', '/v1/calendar/$year/$month', {
        'latitude': '${position.latitude}',
        'longitude': '${position.longitude}',
        'method': '13',
      });
      try {
        final response = await http.get(url).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw Exception('API hatası: ${response.statusCode}');
        }
        return json.decode(response.body)['data'] as List<dynamic>;
      } catch (e) {
        _takvimOnbellegi.remove(anahtar); // Hatalı sonucu önbellekte tutma
        rethrow;
      }
    });
  }

  /// Ayın her günü için vakitleri döner. Anahtar: "yyyy-MM-dd"
  Future<Map<String, Map<String, String>>> aylikVakitleriGetir(
    int year,
    int month,
    Position position,
  ) async {
    final gunler = await _aylikTakvim(year, month, position);
    final sonuc = <String, Map<String, String>>{};
    for (final gun in gunler) {
      final parcalar = (gun['date']['gregorian']['date'] as String).split('-'); // DD-MM-YYYY
      final anahtar = '${parcalar[2]}-${parcalar[1]}-${parcalar[0]}';
      sonuc[anahtar] = _parseAladhanData(Map<String, dynamic>.from(gun['timings']));
    }
    return sonuc;
  }

  /// Ayın her günü için Diyanet'e göre hicrî ay ve gün. Anahtar: "yyyy-MM-dd"
  Future<Map<String, ({int ay, int gun})>> hicriTarihleriGetir(int year, int month, {required Position position}) async {
    final gunler = await _aylikTakvim(year, month, position);
    return {
      for (final gun in gunler)
        () {
          final p = (gun['date']['gregorian']['date'] as String).split('-'); // DD-MM-YYYY
          return '${p[2]}-${p[1]}-${p[0]}';
        }(): DiniGunlerUtil.diyanetHicriTarih(Map<String, dynamic>.from(gun)),
    };
  }

  Future<List<ReligiousDay>> diniGunleriGetir(int year, int month, {required Position position}) async {
    try {
      final days = await _aylikTakvim(year, month, position);
      List<ReligiousDay> diniGunler = [];
      for (var dayData in days) {
        diniGunler.addAll(DiniGunlerUtil.parseAladhanDay(dayData));
      }
      return diniGunler;
    } catch (e) {
      return [];
    }
  }
}
