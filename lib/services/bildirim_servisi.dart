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

    await _bildirimEklentisi.initialize(
      settings: ayarlar,
    );

    await _bildirimIzniIste();
    await _tamZamanliAlarmIzniIste();
    print("🚀 Bildirim Servisi Başlatıldı");
  }

  static Future<void> _bildirimIzniIste() async {
    if (Platform.isAndroid) {
      final androidPlugin = _bildirimEklentisi
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestNotificationsPermission();
      }
    }
  }

  static Future<void> _tamZamanliAlarmIzniIste() async {
    if (Platform.isAndroid) {
      final androidPlugin = _bildirimEklentisi
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.requestExactAlarmsPermission();
      }
    }
  }

  static Future<void> vakitBildirimleriniKur(
    Map<String, String> vakitler,
  ) async {
    await _bildirimEklentisi.cancelAll();
    final istanbulSimdi = tz.TZDateTime.now(tz.local);
    int id = 0;

    vakitler.forEach((vakitIsmi, saatString) async {
      final temizSaatString = saatString.split(" ")[0];
      final saatDakika = temizSaatString.split(":");
      final int saat = int.parse(saatDakika[0]);
      final int dakika = int.parse(saatDakika[1]);

      var vakitZamani = tz.TZDateTime(
        tz.local,
        istanbulSimdi.year,
        istanbulSimdi.month,
        istanbulSimdi.day,
        saat,
        dakika,
      );

      if (vakitZamani.isBefore(istanbulSimdi)) {
        vakitZamani = vakitZamani.add(const Duration(days: 1));
      }

      await _bildirimZamanla(id, vakitIsmi, vakitZamani);
      print("✅ $vakitIsmi için alarm: ${vakitZamani.toString()}");
      id++;
    });
    print("🔔 Tüm vakit alarmları başarıyla kaydedildi!");
  }

  static Future<void> _bildirimZamanla(
    int id,
    String vakitIsmi,
    tz.TZDateTime zaman,
  ) async {
    final androidDetaylar = const AndroidNotificationDetails(
      'vakit_kanal_id',
      'Namaz Vakitleri',
      channelDescription: 'Vakit girdiğinde hatırlatır',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    final NotificationDetails platformDetaylar = NotificationDetails(
      android: androidDetaylar,
    );

    try {
      await _bildirimEklentisi.zonedSchedule(
        id: id,
        title: '🕌 $vakitIsmi Vakti',
        body: '$vakitIsmi vakti girdi, namazını kılmayı unutma.',
        scheduledDate: zaman,
        notificationDetails: platformDetaylar,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      print("⚠️ Alarm Hatası: $e");
      await _bildirimEklentisi.zonedSchedule(
        id: id,
        title: '🕌 $vakitIsmi Vakti',
        body: '$vakitIsmi vakti girdi, namazını kılmayı unutma.',
        scheduledDate: zaman,
        notificationDetails: platformDetaylar,
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  // 🔥 HATASI DÜZELTİLMİŞ TEST METODU 🔥
  static Future<void> testBildirimiKur() async {
    final simdi = tz.TZDateTime.now(tz.local);
    final testZamani = simdi.add(const Duration(seconds: 60)); // 60 saniye sonrası

    final androidDetaylar = const AndroidNotificationDetails(
      'test_kanal_id',
      'Test Bildirimleri',
      channelDescription: 'Sistem testi için',
      importance: Importance.max,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
      fullScreenIntent: true,
      category: AndroidNotificationCategory.alarm,
      visibility: NotificationVisibility.public,
    );

    final platformDetaylar = NotificationDetails(android: androidDetaylar);

    try {
      await _bildirimEklentisi.zonedSchedule(
        id: 999, // Hata veren yerler isimli parametrelere çevrildi
        title: '🚀 Test Başarılı!',
        body: 'Kanka uygulama kapalıyken (Killed State) bildirim atmayı başardık!',
        scheduledDate: testZamani,
        notificationDetails: platformDetaylar,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      print("⏳ TEST ALARMI KURULDU: $testZamani. Lütfen uygulamayı HEMEN KAPATIN.");
    } catch (e) {
      print("⚠️ Test Alarmı Hatası: $e");
    }
  }

  static Future<void> bildirimleriIptalEt() async {
    await _bildirimEklentisi.cancelAll();
    print("🔕 Tüm bildirimler iptal edildi.");
  }
}