import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// İçeriği gözden geçirip onaylayan hesaplar: taslakları da görürler
/// (firestore.rules içindeki editor() listesiyle aynı olmalı)
const editorler = {'TjjDhAT8r9dpDQaJRb53HOz2eEy2'};

class Kategori {
  final String id;
  final String ad;
  final String aciklama;
  final IconData ikon;
  final Color renk;
  const Kategori(this.id, this.ad, this.aciklama, this.ikon, this.renk);
}

const kategoriler = [
  Kategori('temel', 'Temel Bilgiler', 'İmanın ve İslam\'ın şartları', Icons.verified_rounded, Color(0xFF2E7D32)),
  Kategori('ibadetler', 'İbadetler', 'Namaz, oruç, zekât, hac ve kurban', Icons.mosque_rounded, Color(0xFF1565C0)),
  Kategori('peygamberimiz', 'Peygamberimiz', 'Hayatı, ahlakı ve ailesi', Icons.brightness_7_rounded, Color(0xFFEF6C00)),
  Kategori('peygamberler', 'Peygamberler', 'Kur\'an\'da adı geçen peygamberler', Icons.auto_stories_rounded, Color(0xFF6D4C41)),
  Kategori('melekler', 'Melekler', 'Meleklere iman ve görevleri', Icons.flare_rounded, Color(0xFF0288D1)),
  Kategori('halifeler', 'Dört Halife', 'Hulefâ-yi Râşidîn', Icons.account_balance_rounded, Color(0xFF5E35B1)),
  Kategori('sahabe', 'Sahabe', 'Peygamberimizin dostları', Icons.groups_rounded, Color(0xFF00897B)),
  Kategori('alimler', 'Âlimler', 'Mezhep imamları, muhaddisler ve kelamcılar', Icons.menu_book_rounded, Color(0xFF455A64)),
  Kategori('kavramlar', 'Kavramlar', 'Temel dinî kavramlar', Icons.lightbulb_rounded, Color(0xFFF9A825)),
  Kategori('tarih', 'İslam Tarihi', 'Dönemler ve önemli olaylar', Icons.history_edu_rounded, Color(0xFFAD1457)),
];

Kategori kategoriBul(String id) => kategoriler.firstWhere((k) => k.id == id, orElse: () => kategoriler.first);

class Madde {
  final String id;
  final String kategori;
  final String baslik;
  final String ozet;
  final int sira;
  final List<(String, String)> kunye;
  final List<String> baglantilar;
  final List<String> ozelGun; // hicrî "ay-gün"
  final String kaynak;
  final String govde;
  final bool yayinda;

  const Madde({
    required this.id,
    required this.kategori,
    required this.baslik,
    required this.ozet,
    required this.sira,
    required this.kunye,
    required this.baglantilar,
    required this.ozelGun,
    required this.kaynak,
    required this.govde,
    required this.yayinda,
  });

  factory Madde.json(Map<String, dynamic> j) => Madde(
        id: j['id'] as String,
        kategori: j['kategori'] as String? ?? 'temel',
        baslik: j['baslik'] as String? ?? '',
        ozet: j['ozet'] as String? ?? '',
        sira: (j['sira'] as num?)?.toInt() ?? 99,
        kunye: [
          for (final k in (j['kunye'] as List? ?? []))
            if (k is List && k.length == 2) (k[0].toString(), k[1].toString())
            else if (k is Map) (k['ad'].toString(), k['deger'].toString()),
        ],
        baglantilar: [for (final b in (j['baglantilar'] as List? ?? [])) b.toString()],
        ozelGun: [for (final g in (j['ozelGun'] as List? ?? [])) g.toString()],
        kaynak: j['kaynak'] as String? ?? '',
        govde: j['govde'] as String? ?? '',
        yayinda: j['yayinda'] as bool? ?? true,
      );

  Map<String, dynamic> json() => {
        'id': id,
        'kategori': kategori,
        'baslik': baslik,
        'ozet': ozet,
        'sira': sira,
        'kunye': [for (final (a, d) in kunye) [a, d]],
        'baglantilar': baglantilar,
        'ozelGun': ozelGun,
        'kaynak': kaynak,
        'govde': govde,
        'yayinda': yayinda,
      };
}

/// İslam Ansiklopedisi içeriği: Firestore'dan gelir, telefonda saklanır
/// (internetsiz de okunur). İlk açılışta uygulamaya gömülü onaylı paket kullanılır.
class AnsiklopediServisi extends ChangeNotifier {
  AnsiklopediServisi._();
  static final AnsiklopediServisi ornek = AnsiklopediServisi._();

  static const _guncellemeAraligi = Duration(hours: 6);

  List<Madde> maddeler = [];
  Set<String> okunanlar = {};
  static const okunmaTarihiAnahtari = 'ansiklopedi_okunma_tarihi';
  bool yukleniyor = false;
  String? hata;
  bool _yuklendi = false;
  Future<void>? _yukleme;

  bool get editorMu => editorler.contains(FirebaseAuth.instance.currentUser?.uid);

  Madde? bul(String id) => maddeler.where((m) => m.id == id).firstOrNull;

  List<Madde> kategoridekiler(String kategori) =>
      maddeler.where((m) => m.kategori == kategori).toList()..sort((a, b) => a.sira.compareTo(b.sira));

  Future<File> get _onbellek async => File('${(await getApplicationDocumentsDirectory()).path}/ansiklopedi.json');

  /// Önbelleği (yoksa gömülü paketi) okur; ardından gerekirse Firestore'dan günceller
  Future<void> yukle({bool zorla = false}) => _yukleme ??= _yukle(zorla).whenComplete(() => _yukleme = null);

  Future<void> _yukle(bool zorla) async {
    final prefs = await SharedPreferences.getInstance();
    if (!_yuklendi) {
      okunanlar = (prefs.getStringList('ansiklopedi_okunan') ?? []).toSet();
      final g = prefs.getString('ansiklopedi_gunun')?.split('|');
      if (g != null && g.length == 2) _gununSecimi = (g[0], g[1]);
      try {
        final f = await _onbellek;
        final ham = await f.exists() ? await f.readAsString() : await rootBundle.loadString('assets/ansiklopedi.json');
        maddeler = [for (final j in json.decode(ham) as List) Madde.json(Map<String, dynamic>.from(j))];
      } catch (e) {
        debugPrint('ansiklopedi önbelleği okunamadı: $e');
      }
      _yuklendi = true;
      notifyListeners();
    }

    final son = DateTime.fromMillisecondsSinceEpoch(prefs.getInt('ansiklopedi_son_guncelleme') ?? 0);
    final editor = editorMu;
    // Editör olarak giriş/çıkış yapıldıysa taslaklar eklenip çıkarılmalı
    final kimDegisti = prefs.getBool('ansiklopedi_editor') != editor;
    if (!zorla && !kimDegisti && DateTime.now().difference(son) < _guncellemeAraligi && maddeler.isNotEmpty) return;

    yukleniyor = true;
    hata = null;
    notifyListeners();
    try {
      Query<Map<String, dynamic>> q = FirebaseFirestore.instance.collection('ansiklopedi');
      if (!editor) q = q.where('yayinda', isEqualTo: true);
      final snap = await q.get().timeout(const Duration(seconds: 20));
      maddeler = [for (final d in snap.docs) Madde.json({...d.data(), 'id': d.id})];
      await (await _onbellek).writeAsString(json.encode([for (final m in maddeler) m.json()]));
      await prefs.setInt('ansiklopedi_son_guncelleme', DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool('ansiklopedi_editor', editor);
    } on FirebaseException catch (e) {
      // İzin hatası: içerik henüz yayına alınmamış (kural/içerik yüklenmemiş)
      hata = maddeler.isEmpty
          ? (e.code == 'permission-denied'
              ? 'Ansiklopedi içeriği henüz hazırlanıyor. Yakında burada olacak.'
              : 'İçerik indirilemedi. İnternet bağlantını kontrol et.')
          : null;
      debugPrint('ansiklopedi güncellenemedi: ${e.code} ${e.message}');
    } catch (e) {
      hata = maddeler.isEmpty ? 'İçerik indirilemedi. İnternet bağlantını kontrol et.' : null;
      debugPrint('ansiklopedi güncellenemedi: $e');
    }
    yukleniyor = false;
    notifyListeners();
  }

  Future<void> okundu(String id) async {
    if (!okunanlar.add(id)) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ansiklopedi_okunan', okunanlar.toList());
    // Hangi gün okunduğu: haftalık paylaşımda "bu hafta okunan makale" için
    final tarihler = Map<String, String>.from(
        json.decode(prefs.getString(okunmaTarihiAnahtari) ?? '{}') as Map);
    final t = DateTime.now();
    tarihler[id] = '${t.year}-${t.month.toString().padLeft(2, '0')}-${t.day.toString().padLeft(2, '0')}';
    await prefs.setString(okunmaTarihiAnahtari, json.encode(tarihler));
    notifyListeners();
  }

  /// Günün bilgisi: bugünün hicrî tarihine ayrılmış bir madde varsa o (ör. 17
  /// Ramazan'da Bedir); yoksa henüz okunmamışlardan, her gün başka biri.
  Madde? gununMaddesi({({int ay, int gun})? hicri, DateTime? tarih}) {
    final yayinda = maddeler.where((m) => m.yayinda).toList()..sort((a, b) => a.id.compareTo(b.id));
    final havuz = yayinda.isNotEmpty ? yayinda : (editorMu ? (maddeler.toList()..sort((a, b) => a.id.compareTo(b.id))) : <Madde>[]);
    if (havuz.isEmpty) return null;
    if (hicri != null) {
      final anahtar = '${hicri.ay}-${hicri.gun}';
      final ozel = havuz.where((m) => m.ozelGun.contains(anahtar)).toList();
      if (ozel.isNotEmpty) return ozel.first;
    }
    final t = tarih ?? DateTime.now();
    final gun = '${t.year}-${t.month}-${t.day}';
    // Gün içinde sabit kalır (okununca başkasına geçmez); seçim telefonda saklanır
    if (_gununSecimi?.$1 == gun) {
      final m = havuz.where((m) => m.id == _gununSecimi!.$2).firstOrNull;
      if (m != null) return m;
    }
    final gunNo = DateTime(t.year, t.month, t.day).millisecondsSinceEpoch ~/ Duration.millisecondsPerDay;
    final okunmamis = havuz.where((m) => !okunanlar.contains(m.id)).toList();
    final liste = okunmamis.isNotEmpty ? okunmamis : havuz;
    final secim = liste[gunNo % liste.length];
    _gununSecimi = (gun, secim.id);
    SharedPreferences.getInstance().then((p) => p.setString('ansiklopedi_gunun', '$gun|${secim.id}'));
    return secim;
  }

  (String, String)? _gununSecimi; // (gün, madde id)

}
