import 'dart:async';
import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:namaz_app/models/religious_day.dart';
import 'package:namaz_app/models/user_profile.dart';
import 'package:namaz_app/providers/namaz_provider.dart';
import 'package:namaz_app/services/firebase_service.dart';
import 'package:namaz_app/services/namaz_servis.dart';
import 'package:namaz_app/services/notification_service.dart';

// ─────────────────────────── Sahte servisler ───────────────────────────

final _pos = Position(
  latitude: 41.0, longitude: 29.0, timestamp: DateTime.now(), accuracy: 0,
  altitude: 0, heading: 0, speed: 0, speedAccuracy: 0, altitudeAccuracy: 0, headingAccuracy: 0,
);

class FakeNamazServisi extends NamazServisi {
  Object? konumHatasi;
  Map<String, String> vakit;
  /// aylikVakitleriGetir'in döneceği günler ("yyyy-MM-dd" → vakitler)
  Map<String, Map<String, String>> takvim;
  final List<Position> istenenKonumlar = [];

  FakeNamazServisi(this.vakit, {this.konumHatasi, this.takvim = const {}});

  @override
  Future<Position?> konumGetir({bool izinIste = false}) async {
    if (konumHatasi != null) throw konumHatasi!;
    return _pos;
  }

  @override
  Future<Map<String, String>> vakitleriGetir(Position position) async {
    istenenKonumlar.add(position);
    return vakit;
  }

  @override
  Future<Map<String, Map<String, String>>> aylikVakitleriGetir(int year, int month, Position position) async => {
        for (final e in takvim.entries)
          if (e.key.startsWith('$year-${month.toString().padLeft(2, '0')}')) e.key: e.value,
      };

  @override
  Future<List<ReligiousDay>> diniGunleriGetir(int year, int month, {required Position position}) async => [];
}

class FakeNotificationService implements NotificationService {
  final Map<int, DateTime?> planli = {};

  @override
  Future<void> cancelAll() async => planli.clear();

  @override
  Future<void> cancel(int id) async => planli.remove(id);

  @override
  Future<void> scheduleNotification({
    required int id, required String title, required String body,
    required DateTime scheduledDate, String sound = 'varsayilan', String? ozelSesYolu,
  }) async => planli[id] = scheduledDate;

  @override
  Future<void> scheduleManeviRehberNotifications({int adet = 14}) async {}

  @override
  Future<void> scheduleKazaHatirlatma({
    required int hour, required int minute, String sound = 'varsayilan', String? ozelSesYolu,
  }) async => planli[700] = null;

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

class FakeUser implements User {
  @override
  final String uid;
  @override
  final String? displayName;
  FakeUser(this.uid, this.displayName);
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class FakeFirebaseService implements FirebaseService {
  User? kullanici;
  /// true/false: profil var/yok, null: bağlantı hatası
  bool? profilVar = false;
  int buluttakiXp = 0;
  int buluttakiSeri = 0;
  final Set<String> alinmisKullaniciAdlari = {};
  final List<int> gonderilenXp = [];
  final List<int> gonderilenSeri = [];
  int olusturulanProfil = 0;

  @override
  User? get currentUser => kullanici;

  @override
  Future<bool?> hasUserProfile(String uid) async => profilVar;

  @override
  Future<bool> isUsernameAvailable(String username) async => !alinmisKullaniciAdlari.contains(username);

  UserProfile _profil(String uid) => UserProfile(
      uid: uid, username: 'ali', displayName: 'Ali', totalXp: buluttakiXp,
      unvan: 'Muhip', streak: buluttakiSeri, createdAt: DateTime(2026, 1, 1));

  @override
  Stream<UserProfile?> getUserProfile(String uid) => Stream.value(_profil(uid));

  @override
  Future<UserProfile?> getUserProfileFuture(String uid) async => profilVar == null ? null : _profil(uid);

  @override
  Future<({User? user, String? error})> signInWithEmail({required String email, required String password}) async =>
      (user: kullanici, error: null);

  @override
  Future<User?> signInWithGoogle() async => kullanici;

  @override
  Future<void> updateUserStats({required String uid, required int totalXp, required int streak}) async {
    gonderilenXp.add(totalXp);
    gonderilenSeri.add(streak);
  }

  @override
  Future<void> createUserProfile({
    required String uid, required String username, required String displayName,
    int initialXp = 0, int initialStreak = 0,
  }) async {
    olusturulanProfil++;
    profilVar = true;
    alinmisKullaniciAdlari.add(username);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => Future.value();
}

// ─────────────────────────── Yardımcılar ───────────────────────────

final _fmt = DateFormat('yyyy-MM-dd');
String _gun(DateTime d) => _fmt.format(d);
DateTime _bugun() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

/// Sabah 00:00 → "sanal gün" her zaman bugündür; tüm vakitler geçmiştir.
const _gecmisVakitler = {
  'Sabah': '00:00', 'Güneş': '00:01', 'Öğle': '00:02', 'İkindi': '00:03',
  'Akşam': '00:04', 'Yatsı': '00:05', 'GünBatımı': '00:04',
};

const _normalVakitler = {
  'Sabah': '05:00', 'Güneş': '07:00', 'Öğle': '12:00', 'İkindi': '15:00',
  'Akşam': '18:00', 'Yatsı': '19:30', 'GünBatımı': '18:00',
};

/// Yarından itibaren 10 günlük takvim
Map<String, Map<String, String>> _gelecekTakvim() => {
      for (int g = 1; g <= 10; g++)
        _gun(DateTime(_bugun().year, _bugun().month, _bugun().day + g)): _normalVakitler,
    };

Future<void> _bekle() async {
  for (var i = 0; i < 40; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

Future<NamazProvider> _baslat({
  required Map<String, Object> prefs,
  required FakeNamazServisi namaz,
  FakeNotificationService? bildirim,
  FakeFirebaseService? firebase,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = NamazProvider(namaz, bildirim ?? FakeNotificationService(), firebase ?? FakeFirebaseService());
  await _bekle();
  return p;
}

const _vakitler = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];

Map<String, Object> _hazirGun(DateTime sonReset, {bool kilindi = true, Map<String, String> vakit = _gecmisVakitler}) => {
      'cached_vakitler': json.encode(vakit),
      'lastResetDate': _gun(sonReset),
      'ilk_acilis_tarihi': _gun(sonReset),
      for (final v in _vakitler) 'kildi_$v': kilindi,
      'streakCount': 5,
    };

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR', null);
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      m.setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
    }
  });

  group('Gün sıfırlama', () {
    test('GPS başarılı → dünün işaretleri sıfırlanır', () async {
      final dun = DateTime.now().subtract(const Duration(days: 1));
      final p = await _baslat(prefs: _hazirGun(dun), namaz: FakeNamazServisi(_gecmisVakitler));
      expect(p.kildiMi.values.any((v) => v), isFalse);
      expect(p.sonSifirlamaTarihi, _gun(DateTime.now()));
      p.dispose();
    });

    test('GPS zaman aşımı / çevrimdışı açılış → gün yine de sıfırlanır', () async {
      final dun = DateTime.now().subtract(const Duration(days: 1));
      final p = await _baslat(
        prefs: _hazirGun(dun),
        namaz: FakeNamazServisi(_gecmisVakitler, konumHatasi: TimeoutException('GPS')),
      );
      expect(p.kildiMi.values.any((v) => v), isFalse);
      expect(p.gunlukDetaylar[_gun(dun)], isNotNull, reason: 'Dünün kaydı istatistiğe yazılmalı');
      p.dispose();
    });

    test('Uygulama 5 gün açılmadı → 5 günlük kaçırılan vakit kazaya eklenir', () async {
      final besGunOnce = DateTime.now().subtract(const Duration(days: 5));
      final p = await _baslat(prefs: _hazirGun(besGunOnce, kilindi: false), namaz: FakeNamazServisi(_gecmisVakitler));
      for (final v in _vakitler) {
        expect(p.kazaBorclariMap[v]?['toplamBorc'], 5, reason: v);
      }
      expect(p.streakCount, 0);
      p.dispose();
    });

    test('Son gün tam kılınmış + 2 gün açılmamış → sadece açılmayan günler eklenir', () async {
      final ucGunOnce = DateTime.now().subtract(const Duration(days: 3));
      final p = await _baslat(prefs: _hazirGun(ucGunOnce), namaz: FakeNamazServisi(_gecmisVakitler));
      expect(p.kazaBorclariMap['Sabah']?['toplamBorc'], 2);
      expect(p.streakCount, 0, reason: 'Arada gün atlandığı için seri bozulmalı');
      p.dispose();
    });

    test('Çok uzun ara → otomatik kaza en fazla 30 gün', () async {
      final kirkGunOnce = DateTime.now().subtract(const Duration(days: 40));
      final p = await _baslat(prefs: _hazirGun(kirkGunOnce, kilindi: false), namaz: FakeNamazServisi(_gecmisVakitler));
      expect(p.kazaBorclariMap['Sabah']?['toplamBorc'], 30);
      p.dispose();
    });

    test('Dün eksik kaldı → ayda bir seri dondurma hakkı seriyi korur', () async {
      final dun = DateTime.now().subtract(const Duration(days: 1));
      final p = await _baslat(prefs: _hazirGun(dun, kilindi: false), namaz: FakeNamazServisi(_gecmisVakitler));
      expect(p.streakCount, 5, reason: 'Dondurma hakkı kullanıldı');
      expect(p.seriDondurmaMesaji, isNotNull);
      expect(await p.seriDondurmaHakkiVar(), isFalse);
      p.dispose();
    });

    test('Bu ay dondurma hakkı kullanıldıysa eksik gün seriyi bozar', () async {
      final dun = DateTime.now().subtract(const Duration(days: 1));
      final p = await _baslat(
        prefs: {..._hazirGun(dun, kilindi: false), 'seri_dondurma_ay': _gun(DateTime.now()).substring(0, 7)},
        namaz: FakeNamazServisi(_gecmisVakitler),
      );
      expect(p.streakCount, 0);
      p.dispose();
    });

    test('Dün tam kılınmış → seri korunur, kaza eklenmez', () async {
      final dun = DateTime.now().subtract(const Duration(days: 1));
      final p = await _baslat(prefs: _hazirGun(dun), namaz: FakeNamazServisi(_gecmisVakitler));
      expect(p.streakCount, 5);
      expect(p.kazaBorclariMap['Sabah']?['toplamBorc'] ?? 0, 0);
      p.dispose();
    });
  });

  group('Vakit dilimi ve geçmiş vakitleri işaretleme', () {
    // Güneş doğmuş, Öğle henüz girmemiş (23:59'a kadar her saatte geçerli)
    const guneslVakitler = {
      'Sabah': '00:00', 'Güneş': '00:01', 'Öğle': '23:59', 'İkindi': '23:59',
      'Akşam': '23:59', 'Yatsı': '23:59', 'GünBatımı': '23:59',
    };

    test('Güneş doğduktan sonra Sabah vakti biter, Öğle girmemişse işaretlenemez', () async {
      final p = await _baslat(
        prefs: {'cached_vakitler': json.encode(guneslVakitler), 'lastResetDate': _gun(DateTime.now())},
        namaz: FakeNamazServisi(guneslVakitler),
      );
      expect(p.aktifVakit, 'Güneş');
      expect(p.vakitIsaretlenebilirMi('Sabah'), isFalse);
      expect(p.vakitIsaretlenebilirMi('Öğle'), isFalse);

      await p.vaktiKildimIsaretle('Öğle', true);
      expect(p.kildiMi['Öğle'], isFalse, reason: 'Vakti girmemiş namaz işaretlenemez');
      await p.vaktiKildimIsaretle('Güneş', true);
      expect(p.kildiMi.containsKey('Güneş'), isFalse);

      // Geçmiş vakit sonradan işaretlenemez
      await p.vaktiKildimIsaretle('Sabah', true);
      expect(p.kildiMi['Sabah'], isFalse, reason: 'Vakti çıkmış namaz işaretlenemez');
      p.dispose();
    });
  });

  test('Şu anki vakit büyük butonla işaretlenebilir', () async {
    final n = DateTime.now();
    String hm(int dk) {
      final t = n.add(Duration(minutes: dk));
      return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
    }
    // Sabah ve Güneş geçti, Öğle 1 dk önce girdi, diğerleri ileride (gece yarısına yakınsa atla)
    if (n.hour < 1 || n.hour >= 22) return;
    final v = {
      'Sabah': hm(-50), 'Güneş': hm(-40), 'Öğle': hm(-1), 'İkindi': hm(60),
      'Akşam': hm(70), 'Yatsı': hm(80), 'GünBatımı': hm(70),
    };
    final p = await _baslat(
      prefs: {'cached_vakitler': json.encode(v), 'lastResetDate': _gun(n)},
      namaz: FakeNamazServisi(v),
    );
    expect(p.aktifVakit, 'Öğle');
    await p.vaktiKildimIsaretle(p.aktifVakit, true);
    expect(p.kildiMi['Öğle'], isTrue);
    p.dispose();
  });

  group('Bildirimler', () {
    test('Bugünün vakitleri geçtiyse yarının vakit bildirimleri takvimden kurulur', () async {
      final bildirim = FakeNotificationService();
      final p = await _baslat(
        prefs: {'cached_vakitler': json.encode(_gecmisVakitler), 'lastResetDate': _gun(DateTime.now())},
        namaz: FakeNamazServisi(_gecmisVakitler, takvim: _gelecekTakvim()),
        bildirim: bildirim,
      );
      final yarin = DateTime(_bugun().year, _bugun().month, _bugun().day + 1);
      expect(bildirim.planli[10], DateTime(yarin.year, yarin.month, yarin.day, 5, 0),
          reason: 'Yarının Sabah bildirimi');
      // 6 gün x 5 vakit (bugünkülerin hepsi geçti)
      expect(bildirim.planli.keys.where((id) => id < 100).length, 30);
      expect(bildirim.planli.length, lessThanOrEqualTo(64 - 14), reason: 'iOS 64 bildirim sınırı');
      p.dispose();
    });

    test('Sabah hatırlatması güneş doğmadan 20 dk önce, Yatsı hatırlatması sabahtan önce', () async {
      final bildirim = FakeNotificationService();
      final p = await _baslat(
        prefs: {'cached_vakitler': json.encode(_gecmisVakitler), 'lastResetDate': _gun(DateTime.now())},
        namaz: FakeNamazServisi(_gecmisVakitler, takvim: _gelecekTakvim()),
        bildirim: bildirim,
      );
      final yarin = DateTime(_bugun().year, _bugun().month, _bugun().day + 1);
      // Yarının Sabah'ı (g=1, i=0) → ID 120, Güneş 07:00 - 20 dk
      expect(bildirim.planli[120], DateTime(yarin.year, yarin.month, yarin.day, 6, 40));
      // Bugünün Yatsı'sı (g=0, i=4) → ID 114: sabaha karşı değil, gece 23:00'te
      if (DateTime.now().hour < 23) {
        expect(bildirim.planli[114], DateTime(_bugun().year, _bugun().month, _bugun().day, 23));
      }
      // Yarının Yatsı'sı (19:30) → yarın 23:00
      expect(bildirim.planli[124], DateTime(yarin.year, yarin.month, yarin.day, 23));

      // Yatsı kılındı olarak işaretlenince hatırlatması kalkar
      await p.vaktiKildimIsaretle('Yatsı', true);
      expect(bildirim.planli.containsKey(114), isFalse);
      p.dispose();
    });

    test('Oruç modu: sahur ve iftar bildirimleri kurulur, iOS 64 sınırı aşılmaz', () async {
      final bildirim = FakeNotificationService();
      final p = await _baslat(
        prefs: {'cached_vakitler': json.encode(_gecmisVakitler), 'lastResetDate': _gun(DateTime.now())},
        namaz: FakeNamazServisi(_gecmisVakitler, takvim: _gelecekTakvim()),
        bildirim: bildirim,
      );
      await p.orucModuDegistir(true);
      final yarin = DateTime(_bugun().year, _bugun().month, _bugun().day + 1);
      // Yarın (g=1): sahur 05:00 - 45 dk, iftar 18:00
      expect(bildirim.planli[602], DateTime(yarin.year, yarin.month, yarin.day, 4, 15));
      expect(bildirim.planli[603], DateTime(yarin.year, yarin.month, yarin.day, 18));
      expect(bildirim.planli.length + 4, lessThanOrEqualTo(64), reason: '+4 manevi bildirim');
      p.dispose();
    });

    test('Kaza orucu tutulunca borç düşer ve bugün oruçlu sayılır', () async {
      final p = await _baslat(prefs: {}, namaz: FakeNamazServisi(_gecmisVakitler));
      await p.kazaOrucBorcuAyarla(3);
      await p.kazaOrucuTuttum();
      expect(p.kazaOrucBorcu, 2);
      expect(p.bugunOrucTutuldu, isTrue);
      expect(p.toplamXp, NamazProvider.orucXp);
      p.dispose();
    });

    test('Kaza hatırlatıcısı bir namaz işaretlenince silinmez', () async {
      final bildirim = FakeNotificationService();
      final p = await _baslat(
        prefs: {'cached_vakitler': json.encode(_gecmisVakitler), 'lastResetDate': _gun(DateTime.now())},
        namaz: FakeNamazServisi(_gecmisVakitler),
        bildirim: bildirim,
      );
      await p.kazaHatirlatmaAyarla(saat: 20, dakika: 0);
      await p.vaktiKildimIsaretle('Yatsı', true);
      expect(bildirim.planli.containsKey(700), isTrue);
      p.dispose();

      // Uygulama yeniden açıldığında da kurulur
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('kaza_hatirlatma_acik'), isTrue);
    });
  });

  group('Şehir seçimi', () {
    test('Şehir seçilince il merkezinin koordinatı kullanılır ve GPS seçimi ezmez', () async {
      final namaz = FakeNamazServisi(_gecmisVakitler);
      final p = await _baslat(prefs: {}, namaz: namaz);
      expect(await p.sehirSec('Van'), isNull);
      expect(p.seciliSehir, 'Van');
      expect(p.konumBilgisi, 'TÜRKİYE, VAN');
      expect(namaz.istenenKonumlar.last.latitude, closeTo(38.49, 0.01));

      namaz.istenenKonumlar.clear();
      await p.konumVeApiIstegi(kullaniciTetikledi: false);
      expect(p.seciliSehir, 'Van', reason: 'Açılıştaki GPS isteği seçimi silmemeli');
      expect(namaz.istenenKonumlar.single.longitude, closeTo(43.41, 0.01));
      p.dispose();
    });

    test('İzin yok / GPS hatası → Elazığ değil, şehir seçme uyarısı', () async {
      final p = await _baslat(
        prefs: {},
        namaz: FakeNamazServisi(_gecmisVakitler, konumHatasi: Exception('Konum servisleri kapalı.')),
      );
      expect(p.vakitler, isNull);
      expect(p.konumBilgisi, isNot(contains('ELAZIĞ')));
      expect(p.hataMesaji, contains('şehir seçin'));
      p.dispose();
    });
  });

  group('Hesap / bulut senkronu', () {
    test('Yeni cihazda giriş → buluttaki XP korunur', () async {
      final fb = FakeFirebaseService()
        ..kullanici = FakeUser('u1', 'Ali')
        ..profilVar = true
        ..buluttakiXp = 5000;
      final p = await _baslat(prefs: {'firebase_handle': 'ali'}, namaz: FakeNamazServisi(_gecmisVakitler), firebase: fb);
      await p.emailIleGirisYap(email: 'ali@x.com', password: '123456');
      expect(fb.gonderilenXp, isNot(contains(0)));
      expect(p.toplamXp, 5000);
      p.dispose();
    });

    test('Başka hesaba geçince önceki hesabın yerel XP\'si devralınmaz', () async {
      final fb = FakeFirebaseService()
        ..kullanici = FakeUser('u2', 'Veli')
        ..profilVar = true
        ..buluttakiXp = 50;
      final p = await _baslat(
        prefs: {'toplam_xp': 300, 'xp_sahibi_uid': 'u1', 'firebase_handle': 'veli'},
        namaz: FakeNamazServisi(_gecmisVakitler),
        firebase: fb,
      );
      expect(p.toplamXp, 50);
      expect(fb.gonderilenXp, isNot(contains(300)));
      p.dispose();
    });

    test('Bu cihazda bozulan seri buluttaki eski değerle geri gelmez', () async {
      final fb = FakeFirebaseService()
        ..kullanici = FakeUser('u1', 'Ali')
        ..profilVar = true
        ..buluttakiXp = 999
        ..buluttakiSeri = 40;
      final p = await _baslat(
        prefs: {'toplam_xp': 100, 'streakCount': 0, 'xp_sahibi_uid': 'u1', 'firebase_handle': 'ali'},
        namaz: FakeNamazServisi(_gecmisVakitler),
        firebase: fb,
      );
      expect(p.streakCount, 0);
      expect(p.toplamXp, 100);
      expect(fb.gonderilenSeri.last, 0);
      p.dispose();
    });

    test('Çevrimdışı açılışta giriş yapmış kullanıcı giriş ekranına atılmaz', () async {
      final fb = FakeFirebaseService()
        ..kullanici = FakeUser('u1', 'Ali')
        ..profilVar = null; // Firestore'a ulaşılamıyor
      final p = await _baslat(prefs: {'firebase_handle': 'ali'}, namaz: FakeNamazServisi(_gecmisVakitler), firebase: fb);
      expect(p.needsProfile, isFalse);
      expect(fb.gonderilenXp, isEmpty, reason: 'Bulut okunamadan buluta yazılmamalı');
      p.dispose();
    });

    test('Girişte profil durumu öğrenilemezse yeni profil oluşturulmaz (üzerine yazma yok)', () async {
      final fb = FakeFirebaseService()
        ..kullanici = FakeUser('u1', 'Ali')
        ..profilVar = null;
      final p = await _baslat(prefs: {}, namaz: FakeNamazServisi(_gecmisVakitler), firebase: fb);
      final hata = await p.emailIleGirisYap(email: 'ali@x.com', password: '123456');
      expect(hata, isNotNull);
      expect(fb.olusturulanProfil, 0);
      p.dispose();
    });

    test('Google kaydı (kullanıcı adı alınmışsa) → seçilen handle ve Google adı kaydedilir', () async {
      final fb = FakeFirebaseService()
        ..kullanici = FakeUser('u2', 'ali')
        ..alinmisKullaniciAdlari.add('ali');
      final p = await _baslat(prefs: {}, namaz: FakeNamazServisi(_gecmisVakitler), firebase: fb);
      expect(await p.googleIleGirisYap(), 'google_username_taken');
      expect(await p.completeGoogleRegistration(username: 'ali_k'), isNull);
      expect(p.currentHandle, 'ali_k');
      expect(p.currentUsername, 'ali');
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('firebase_handle'), 'ali_k');
      p.dispose();
    });
  });

  group('Veri sıfırlama', () {
    test('verileriSifirla: eski detaylar bellekte kalmaz, oturum korunur, bulut sıfırlanır', () async {
      final fb = FakeFirebaseService()
        ..kullanici = FakeUser('u1', 'Ali')
        ..profilVar = true;
      final p = await _baslat(
        prefs: {
          'cached_vakitler': json.encode(_gecmisVakitler),
          'lastResetDate': _gun(DateTime.now()),
          'history_details': json.encode({'2026-01-01': {'Sabah': true}}),
          'onboarding_completed': true,
          'firebase_handle': 'ali',
          'toplam_xp': 700,
          'xp_sahibi_uid': 'u1',
        },
        namaz: FakeNamazServisi(_gecmisVakitler),
        firebase: fb,
      );
      expect(p.gunlukDetaylar, isNotEmpty);
      fb.gonderilenXp.clear();
      await p.verileriSifirla();
      await _bekle();
      expect(p.gunlukDetaylar, isEmpty);
      expect(p.toplamXp, 0);
      expect(fb.gonderilenXp.first, 0);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('onboarding_completed'), isTrue);
      expect(prefs.getString('firebase_handle'), 'ali');
      p.dispose();
    });
  });

  group('XP / kaza / zikir', () {
    test('5. vakitte tam gün bonusu, geri alma simetrik', () async {
      // Diğer 4 vakit vaktinde kılınmış; şu an Yatsı vakti
      final p = await _baslat(
        prefs: {
          'cached_vakitler': json.encode(_gecmisVakitler),
          'lastResetDate': _gun(DateTime.now()),
          for (final v in _vakitler.take(4)) 'kildi_$v': true,
        },
        namaz: FakeNamazServisi(_gecmisVakitler),
      );
      await p.vaktiKildimIsaretle('Yatsı', true);
      expect(p.toplamXp, 20 + 25);
      expect(p.streakCount, 1, reason: 'Seri, 5 vakti tamamlanan gün sayısıdır');
      await p.vaktiKildimIsaretle('Yatsı', false);
      expect(p.toplamXp, 0);
      expect(p.streakCount, 0);
      await p.vaktiKildimIsaretle('Yatsı', true);
      expect(p.toplamXp, 45);
      p.dispose();
    });

    test('Borçtan fazla kaza kılınamaz, XP kılınan kadar verilir', () async {
      final p = await _baslat(
        prefs: {'cached_vakitler': json.encode(_gecmisVakitler), 'lastResetDate': _gun(DateTime.now())},
        namaz: FakeNamazServisi(_gecmisVakitler),
      );
      await p.kazaBorcunuAyarla({'Sabah': 3});
      expect(await p.kazaKil('Sabah', adet: 5), 3);
      expect(p.toplamXp, 3 * 10);
      expect(await p.kazaKilGunlukPaket(), 0, reason: 'Borç kalmadı');
      p.dispose();
    });

    test('Zikir sayacı hızlı ardışık dokunuşlarda anında artar', () async {
      final p = await _baslat(prefs: {}, namaz: FakeNamazServisi(_gecmisVakitler));
      p.zikirArtir();
      p.zikirArtir();
      p.zikirArtir();
      expect(p.zikirSayaci, 3, reason: 'await beklenmeden artmalı');
      await _bekle();
      p.dispose();
    });
  });
}
