import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class BildirimServisi {
  static final FlutterLocalNotificationsPlugin _bildirimEklentisi =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));

    const AndroidInitializationSettings androidAyarlari =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosAyarlari =
        DarwinInitializationSettings();

    const InitializationSettings ayarlar = InitializationSettings(
      android: androidAyarlari,
      iOS: iosAyarlari,
    );

    await _bildirimEklentisi.initialize(settings: ayarlar);

    // Android 12+ için tam zamanlı alarm izni iste
    await _tamZamanliAlarmIzniIste();
  }

  static Future<void> _tamZamanliAlarmIzniIste() async {
    if (Platform.isAndroid) {
      final androidPlugin = _bildirimEklentisi
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        // Kullanıcıyı sistem izin ekranına yönlendirir
        await androidPlugin.requestExactAlarmsPermission();
      }
    }
  }

  static Future<void> vakitBildirimleriniKur(
    Map<String, String> vakitler,
  ) async {
    await _bildirimEklentisi.cancelAll();
    final now = DateTime.now();
    int id = 0;

    vakitler.forEach((vakitIsmi, saatString) {
      final saatDakika = saatString.split(" ")[0].split(":");
      final int saat = int.parse(saatDakika[0]);
      final int dakika = int.parse(saatDakika[1]);

      DateTime vakitZamani = DateTime(
        now.year,
        now.month,
        now.day,
        saat,
        dakika,
      );
      if (vakitZamani.isBefore(now)) {
        vakitZamani = vakitZamani.add(const Duration(days: 1));
      }

      _bildirimZamanla(id, vakitIsmi, vakitZamani);
      id++;
    });
  }

  static Future<void> _bildirimZamanla(
    int id,
    String vakitIsmi,
    DateTime zaman,
  ) async {
    try {
      await _bildirimEklentisi.zonedSchedule(
        id: id,
        title: '$vakitIsmi Vakti',
        body: '$vakitIsmi vakti girdi, namazını kılmayı unutma.',
        scheduledDate: tz.TZDateTime.from(zaman, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'vakit_kanal_id',
            'Namaz Vakitleri',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // HATA DÜZELTİLDİ: 'allowWhileIdle' yerine 'inexactAllowWhileIdle' kullanıldı
      await _bildirimEklentisi.zonedSchedule(
        id: id,
        title: '$vakitIsmi Vakti',
        body: '$vakitIsmi vakti girdi, namazını kılmayı unutma.',
        scheduledDate: tz.TZDateTime.from(zaman, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'vakit_kanal_id',
            'Namaz Vakitleri',
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }
}
