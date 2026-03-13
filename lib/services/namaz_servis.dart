import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class NamazServisi {
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

    // Her şey tamamsa konumu getir
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    ).timeout(const Duration(seconds: 6));
  }

  Future<Map<String, String>> vakitleriGetir(Position position) async {
    final url = Uri.parse(
      'https://api.aladhan.com/v1/timings?latitude=${position.latitude}&longitude=${position.longitude}&method=13',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data']['timings'];
      return _parseAladhanData(data);
    } else {
      throw Exception('API hatası: ${response.statusCode}');
    }
  }

  Future<Map<String, String>> vakitleriGetirSehirle(String sehir) async {
    final url = Uri.parse(
      'https://api.aladhan.com/v1/timingsByCity?city=$sehir&country=Turkey&method=13',
    );
    final response = await http.get(url).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data']['timings'];
      return _parseAladhanData(data);
    } else {
      throw Exception('API hatası: ${response.statusCode}');
    }
  }

  Map<String, String> _parseAladhanData(Map<String, dynamic> data) {
    return {
      "Sabah": data['Fajr'],
      "Güneş": data['Sunrise'],
      "Öğle": data['Dhuhr'],
      "İkindi": data['Asr'],
      "Akşam": data['Maghrib'],
      "Yatsı": data['Isha'],
      "GünBatımı": data['Sunset'],
    };
  }
}
