import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/prayer_post.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Sosyal akış verilerini (dualar) yerel cihazda saklayan servis.
/// Uygulama çevrimdışıyken veya açılışta hızlı yükleme için kullanılır.
class LocalDbService {
  static final LocalDbService _instance = LocalDbService._internal();
  factory LocalDbService() => _instance;
  LocalDbService._internal();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    String path = join(await getDatabasesPath(), 'takva_yolu_cache.db');
    return await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cached_prayers(
            id TEXT PRIMARY KEY,
            text TEXT,
            senderUid TEXT,
            senderName TEXT,
            senderUsername TEXT,
            aminCount INTEGER,
            aminBy TEXT,
            timestamp TEXT,
            isApproved INTEGER
          )
        ''');
      },
    );
  }

  /// Son 20 duayı veritabanına kaydeder
  Future<void> cachePrayers(List<PrayerPost> prayers) async {
    try {
      final db = await database;
      final batch = db.batch();
      
      // Eski önbelleği temizle (basitlik için toplu güncelleme yapıyoruz)
      batch.delete('cached_prayers');
      
      for (var prayer in prayers.take(20)) {
        batch.insert('cached_prayers', {
          'id': prayer.id,
          'text': prayer.text,
          'senderUid': prayer.senderUid,
          'senderName': prayer.senderName,
          'senderUsername': prayer.senderUsername,
          'aminCount': prayer.aminCount,
          'aminBy': jsonEncode(prayer.aminBy),
          'timestamp': prayer.timestamp.toIso8601String(),
          'isApproved': prayer.isApproved ? 1 : 0,
        });
      }
      
      await batch.commit(noResult: true);
      debugPrint('💾 Dualar yerel veritabanına önbelleklendi (Adet: ${prayers.length.clamp(0, 20)})');
    } catch (e) {
      debugPrint('💾 Önbelleğe alma hatası: $e');
    }
  }

  /// Kayıtlı duaları getirir
  Future<List<PrayerPost>> getCachedPrayers() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query('cached_prayers', orderBy: 'timestamp DESC');
      
      return List.generate(maps.length, (i) {
        return PrayerPost(
          id: maps[i]['id'],
          text: maps[i]['text'],
          senderUid: maps[i]['senderUid'],
          senderName: maps[i]['senderName'],
          senderUsername: maps[i]['senderUsername'],
          aminCount: maps[i]['aminCount'],
          aminBy: List<String>.from(jsonDecode(maps[i]['aminBy'])),
          timestamp: DateTime.parse(maps[i]['timestamp']),
          isApproved: maps[i]['isApproved'] == 1,
        );
      });
    } catch (e) {
      debugPrint('💾 Önbellekten getirme hatası: $e');
      return [];
    }
  }
}
