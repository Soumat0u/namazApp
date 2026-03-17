import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    // ÇÖZÜM: v21'de initialize metodu positional argument kabul etmez, 
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse details) {
        // Bildirime tıklandığında yapılacaklar
      },
    );

    await requestPermissions();
  }

  Future<void> requestPermissions() async {
    // Android için izinler
    final androidImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
            
    if (androidImplementation != null) {
      // Android 13+ için bildirim izni
      await androidImplementation.requestNotificationsPermission();
      // Android 12+ için hassas saat izni
      await androidImplementation.requestExactAlarmsPermission();
    }

    // iOS için izinler (zaten DarwinInitializationSettings içinde isteniyor ama manuel tetiklemek daha garanti)
    final iosImplementation = _notificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosImplementation != null) {
      await iosImplementation.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'namaz_vakti_channel',
          'Namaz Vakitleri',
          channelDescription: 'Namaz vakitleri bildirim kanalı',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      // ÇÖZÜM: androidAllowWhileIdle yerine androidScheduleMode kullanılmalıdır.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }
}