import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class NamazServisi {
  // 1. Kullanıcının Konumunu Bulan Fonksiyon
  Future<Position> _getGeoLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Servis kontrolü
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return Future.error('Konum servisleri kapalı.');
    }

    // İzin kontrolü
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return Future.error('Konum izni reddedildi.');
      }
    }

    // Kalıcı reddetme kontrolü
    if (permission == LocationPermission.deniedForever) {
      return Future.error('Konum izinleri kalıcı olarak reddedildi.');
    }

    // Her şey tamamsa konumu getir
    return await Geolocator.getCurrentPosition();
  }

  // 2. Koordinatlara Göre Vakitleri Çeken Fonksiyon
  Future<Map<String, String>> vakitleriGetir() async {
    try {
      Position position = await _getGeoLocation();

      // API'ye enlem ve boylam gönderiyoruz
      final url = Uri.parse(
        'https://api.aladhan.com/v1/timings?latitude=${position.latitude}&longitude=${position.longitude}&method=13',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body)['data']['timings'];
        return {
          "Sabah": data['Fajr'],
          "Öğle": data['Dhuhr'],
          "İkindi": data['Asr'],
          "Akşam": data['Maghrib'],
          "Yatsı": data['Isha'],
        };
      } else {
        throw Exception('API hatası: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Konum veya API hatası: $e');
    }
  }
}
