// Kablosuz güncelleme: yeni sürümler safak-lenovo'daki notlar sunucusundan
// gelir (GET /api/apps/namaz, /api/apps/namaz/apk; bkz. publish.sh). Sunucuda
// daha yeni bir derleme varsa alt tarafta bir çubuk çıkar; APK indirilip
// Android'in yükleyicisine verilir. İlk seferde Android, uygulamanın başka
// uygulama kurmasına izin verilmesini ister.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../core/surum.dart';
import 'package:path_provider/path_provider.dart';

enum UpdateStep { idle, downloading, needsPermission, installing, failed }

class Updater extends ChangeNotifier {
  // Anahtar derlemeye publish.sh tarafından gömülür (repoda durmaz). Boşsa
  // (ör. `flutter run`) güncelleme denetimi hiç yapılmaz.
  static const _token = String.fromEnvironment('UPDATE_TOKEN');
  static const _servers = [
    'http://100.83.213.72:8787', // Tailscale, her yerden
    'http://192.168.1.107:8787', // ev ağı, Tailscale kapalıyken
  ];
  static const _channel = MethodChannel('namaz/update');
  static const _checkEvery = Duration(minutes: 10);

  String _base = _servers.first;
  int? current; // bu derlemenin versionCode'u
  int? available; // sunucudaki daha yeni versionCode
  String? availableName;
  UpdateStep step = UpdateStep.idle;
  double? progress; // indirilirken 0..1
  String? error;
  DateTime? _checked;

  Map<String, String> get _headers => {'Authorization': 'Bearer $_token'};

  /// Sunucuya en son derlemeyi sorar (`force` yoksa birkaç dakikada bir).
  Future<void> check({bool force = false}) async {
    // Kablosuz güncelleme yalnızca test sürümünde; Play sürümü mağazadan güncellenir
    if (!Platform.isAndroid || _token.isEmpty || !denemeSurumu) return;
    if (!force && _checked != null && DateTime.now().difference(_checked!) < _checkEvery) return;
    _checked = DateTime.now();
    try {
      if (current == null) {
        final v = await _channel.invokeMapMethod<String, dynamic>('version');
        current = (v!['code'] as num).toInt();
      }
      http.Response? r;
      // önce son çalışan adres, olmazsa diğerleri
      for (final base in [_base, ..._servers.where((s) => s != _base)]) {
        try {
          r = await http
              .get(Uri.parse('$base/api/apps/namaz'), headers: _headers)
              .timeout(const Duration(seconds: 6));
          _base = base;
          break;
        } catch (_) {}
      }
      if (r == null || r.statusCode != 200) return;
      final info = jsonDecode(r.body) as Map<String, dynamic>;
      final v = (info['version'] as num).toInt();
      final newer = v > current! ? v : null;
      if (newer != available) {
        available = newer;
        availableName = info['name'] as String?;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('güncelleme denetlenemedi: $e');
    }
  }

  /// Uygulama öne geldi: kurulum izni yeni verildiyse kaldığı yerden devam et.
  Future<void> resumed() async {
    if (step == UpdateStep.needsPermission && await _canInstall()) {
      await update();
    } else {
      await check();
    }
  }

  Future<bool> _canInstall() async => await _channel.invokeMethod<bool>('canInstall') ?? false;

  /// Yeni derlemeyi indirir ve yükleyiciyi açar.
  Future<void> update() async {
    if (available == null || step == UpdateStep.downloading) return;
    if (!await _canInstall()) {
      _set(UpdateStep.needsPermission);
      await _channel.invokeMethod('allowInstall');
      return;
    }
    error = null;
    progress = 0;
    _set(UpdateStep.downloading);
    final client = http.Client();
    try {
      final dir = Directory('${(await getTemporaryDirectory()).path}/updates');
      await dir.create(recursive: true);
      final file = File('${dir.path}/namaz.apk');
      final r = await client
          .send(http.Request('GET', Uri.parse('$_base/api/apps/namaz/apk'))..headers.addAll(_headers))
          .timeout(const Duration(seconds: 20));
      if (r.statusCode != 200) throw HttpException('HTTP ${r.statusCode}');
      final total = r.contentLength ?? 0;
      final sink = file.openWrite();
      var got = 0;
      try {
        await for (final chunk in r.stream.timeout(const Duration(seconds: 30))) {
          sink.add(chunk);
          got += chunk.length;
          if (total > 0) {
            progress = got / total;
            notifyListeners();
          }
        }
      } finally {
        await sink.close();
      }
      if (total > 0 && got != total) throw const HttpException('indirme yarım kaldı');
      _set(UpdateStep.installing);
      await _channel.invokeMethod('install', {'path': file.path});
      // Yükleyici ekranda; kapatılırsa çubuk kalır, yeniden denenebilir
      _set(UpdateStep.idle);
    } catch (e) {
      error = e is TimeoutException || e is SocketException ? 'Sunucuya ulaşılamadı' : '$e';
      _set(UpdateStep.failed);
    } finally {
      client.close();
      progress = null;
    }
  }

  void _set(UpdateStep s) {
    step = s;
    notifyListeners();
  }
}
