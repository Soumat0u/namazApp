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
    String sound = "varsayilan",
    String? ozelSesYolu,
  }) async {
    // Android'de kanal bazlı ses değişimi için her ses tipine özel kanal ID'si kullanıyoruz
    final String channelId = sound == "varsayilan" ? 'namaz_vakti_channel' : 'namaz_vakti_channel_$sound';

    await _notificationsPlugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: tz.TZDateTime.from(scheduledDate, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Namaz Vakitleri',
          channelDescription: 'Namaz vakitleri bildirim kanalı',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: _getAndroidSound(sound, ozelSesYolu),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: _getIosSound(sound),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  AndroidNotificationSound? _getAndroidSound(String sound, String? ozelSesYolu) {
    if (sound == "varsayilan") return null; // Sistem varsayılanı
    if (sound == "ozel" && ozelSesYolu != null) {
      return UriAndroidNotificationSound(ozelSesYolu);
    }
    // ÖNEMLİ: Android bildirim sesleri 'android/app/src/main/res/raw/' klasöründe olmalıdır.
    // Dosya uzantısı (örn: .mp3) eklenmemelidir.
    return RawResourceAndroidNotificationSound(sound);
  }

  String? _getIosSound(String sound) {
    if (sound == "varsayilan") return null;
    return '$sound.caf'; // iOS için .caf formatı yaygındır
  }

  Future<void> cancel(int id) async {
    await _notificationsPlugin.cancel(id: id);
  }

  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Her 5 saatte bir rastgele ayet veya hadis bildirimi planlar
  Future<void> scheduleManeviRehberNotifications() async {
    for (int i = 500; i <= 600; i++) {
      await _notificationsPlugin.cancel(id: i);
    }

    final allQuotes = ManeviRehberData.getAll();
    allQuotes.shuffle();

    final now = DateTime.now();
    for (int i = 0; i < 50; i++) {
      final scheduledTime = now.add(Duration(hours: (i + 1) * 5));
      final quote = allQuotes[i % allQuotes.length];
      final bool isAyet = quote.contains('(') && quote.contains(')');
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

  /// Kaza namazı günlük hatırlatma bildirimi kurar (ID: 700)
  Future<void> scheduleKazaHatirlatma({
    required int hour, 
    required int minute,
    String sound = "varsayilan",
    String? ozelSesYolu,
  }) async {
    await _notificationsPlugin.cancel(id: 700);
    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, hour, minute);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    
    final String channelId = sound == "varsayilan" ? 'kaza_namaz_channel' : 'kaza_namaz_channel_$sound';

    await _notificationsPlugin.zonedSchedule(
      id: 700,
      title: "⏳ Kaza Namazı Vakti",
      body: "Bugünkü kaza namazı hedefinizi kılmayı unutmayın.",
      scheduledDate: tz.TZDateTime.from(scheduled, tz.local),
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          'Kaza Namazı Hatırlatmaları',
          channelDescription: 'Günlük kaza namazı hatırlatma bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          sound: _getAndroidSound(sound, ozelSesYolu),
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: _getIosSound(sound),
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // Her gün tekrarla
    );
  }

  /// Kaza hatırlatma bildirimini iptal eder
  Future<void> cancelKazaHatirlatma() async {
    await _notificationsPlugin.cancel(id: 700);
  }
}
