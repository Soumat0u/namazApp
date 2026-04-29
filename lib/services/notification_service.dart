import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../core/constants/quotes.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
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
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Her 5 saatte bir rastgele ayet veya hadis bildirimi planlar
  Future<void> scheduleManeviRehberNotifications() async {
    // Önce eski planlanmış manevi rehber bildirimlerini iptal et (ID: 500-600 arası)
    for (int i = 500; i <= 600; i++) {
      await _notificationsPlugin.cancel(id: i);
    }

    final allQuotes = ManeviRehberData.getAll();
    allQuotes.shuffle(); // Karıştır

    final now = DateTime.now();
    
    // Önümüzdeki 50 slot için planla (Her slot 5 saat ara ile)
    for (int i = 0; i < 50; i++) {
      final scheduledTime = now.add(Duration(hours: (i + 1) * 5));
      
      // Quote seç (Shuffle edildiği için sırayla alabiliriz, 50 tane var zaten)
      final quote = allQuotes[i % allQuotes.length];
      
      final bool isAyet = quote.contains('(') && quote.contains(')'); // Basit bir ayrım
      final title = isAyet ? "📖 Bir Ayet" : "💬 Bir Hadis";

      await _notificationsPlugin.zonedSchedule(
        id: 500 + i,
        title: title,
        body: quote,
        scheduledDate: tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'manevi_rehber_channel',
            'Manevi Rehber',
            channelDescription: 'Her 5 saatte bir ayet ve hadis bildirimleri',
            importance: Importance.defaultImportance,
            priority: Priority.defaultPriority,
          ),
          iOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}