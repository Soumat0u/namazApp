import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import '../core/constants/quotes.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  /// Bildirime dokununca açılacak sekme ('ana' | 'sosyal'). Ana ekran dinler ve değeri tüketir.
  static final ValueNotifier<String?> acilacakSekme = ValueNotifier(null);

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
        acilacakSekme.value = details.payload ?? 'ana';
      },
    );

    // Uygulama kapalıyken bir bildirime dokunularak açıldıysa
    final acilis = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (acilis?.didNotificationLaunchApp ?? false) {
      acilacakSekme.value = acilis!.notificationResponse?.payload ?? 'ana';
    }
  }

  /// Uygulama açıkken gelen push bildirimini (FCM ön planda göstermez) yerel bildirim olarak gösterir
  Future<void> anlikGoster({required String title, required String body, String sekme = 'sosyal'}) async {
    await _notificationsPlugin.show(
      id: DateTime.now().millisecondsSinceEpoch % 100000 + 1000,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'sosyal_channel',
          'Kardeşlerim',
          channelDescription: 'Arkadaşlık istekleri, hatırlatmalar ve amîn bildirimleri',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
      ),
      payload: sekme,
    );
  }

  /// Android 14+ hassas alarm iznini varsayılan olarak vermiyor; izin yoksa
  /// bildirim yaklaşık zamanda (birkaç dakika sapmayla) gelir ama planlama hata vermez.
  Future<AndroidScheduleMode> _zamanlamaKipi() async {
    final android = _notificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return AndroidScheduleMode.exactAllowWhileIdle;
    final izin = await android.canScheduleExactNotifications() ?? true;
    return izin ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle;
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
      androidScheduleMode: await _zamanlamaKipi(),
      payload: 'ana',
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

  /// Her 5 saatte bir rastgele ayet veya hadis bildirimi planlar (gece 23:00-08:00 arası atlanır).
  /// iOS en fazla 64 bekleyen bildirim tuttuğu için vakit bildirimlerine yer bırakacak kadar planlanır.
  /// Not: Çağıran taraf (NamazProvider) öncesinde cancelAll() yapar.
  Future<void> scheduleManeviRehberNotifications({int adet = 14}) async {
    final allQuotes = ManeviRehberData.getAll();
    allQuotes.shuffle();

    final now = DateTime.now();
    final zamanlar = <DateTime>[];
    for (int adim = 1; zamanlar.length < adet && adim < adet * 4; adim++) {
      final t = now.add(Duration(hours: adim * 5));
      if (t.hour >= 8 && t.hour < 23) zamanlar.add(t);
    }

    for (int i = 0; i < zamanlar.length; i++) {
      final scheduledTime = zamanlar[i];
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
        androidScheduleMode: await _zamanlamaKipi(),
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
      androidScheduleMode: await _zamanlamaKipi(),
      matchDateTimeComponents: DateTimeComponents.time, // Her gün tekrarla
    );
  }

  /// Kaza hatırlatma bildirimini iptal eder
  Future<void> cancelKazaHatirlatma() async {
    await _notificationsPlugin.cancel(id: 700);
  }
}
