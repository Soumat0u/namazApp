import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/prayer_post.dart';
import 'dart:convert';
import 'package:flutter/foundation.dart';

/// Sosyal akış ve kaza borçlarını yerel cihazda saklayan SQLite servisi.
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
      version: 2,
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
        await _createKazaTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await _createKazaTable(db);
        }
      },
    );
  }

  Future<void> _createKazaTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kaza_borclari(
        vakit TEXT PRIMARY KEY,
        toplamBorc INTEGER DEFAULT 0,
        kilinmis INTEGER DEFAULT 0
      )
    ''');
    for (final vakit in ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı']) {
      await db.insert(
        'kaza_borclari',
        {'vakit': vakit, 'toplamBorc': 0, 'kilinmis': 0},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  // ══════════════════════════════════════════
  // 📿 KAZA BORÇLARI
  // ══════════════════════════════════════════

  Future<Map<String, Map<String, int>>> getKazaBorclari() async {
    try {
      final db = await database;
      final rows = await db.query('kaza_borclari');
      final Map<String, Map<String, int>> result = {};
      for (final row in rows) {
        result[row['vakit'] as String] = {
          'toplamBorc': (row['toplamBorc'] as int?) ?? 0,
          'kilinmis': (row['kilinmis'] as int?) ?? 0,
        };
      }
      return result;
    } catch (e) {
      debugPrint('💾 Kaza borçları getirme hatası: $e');
      return {};
    }
  }

  Future<void> updateKazaBorc(String vakit, {int? toplamBorc, int? kilinmis}) async {
    try {
      final db = await database;
      final Map<String, Object?> values = {};
      if (toplamBorc != null) values['toplamBorc'] = toplamBorc;
      if (kilinmis != null) values['kilinmis'] = kilinmis;
      if (values.isEmpty) return;
      await db.update('kaza_borclari', values, where: 'vakit = ?', whereArgs: [vakit]);
    } catch (e) {
      debugPrint('💾 Kaza borcu güncelleme hatası: $e');
    }
  }

  Future<void> setKazaBorclari(Map<String, int> borclar) async {
    try {
      final db = await database;
      final batch = db.batch();
      for (final entry in borclar.entries) {
        batch.update('kaza_borclari', {'toplamBorc': entry.value},
            where: 'vakit = ?', whereArgs: [entry.key]);
      }
      await batch.commit(noResult: true);
    } catch (e) {
      debugPrint('💾 Kaza borçları ayarlama hatası: $e');
    }
  }

  Future<void> sifirlaKazaBorclari() async {
    try {
      final db = await database;
      await db.update('kaza_borclari', {'toplamBorc': 0, 'kilinmis': 0});
    } catch (e) {
      debugPrint('💾 Kaza sıfırlama hatası: $e');
    }
  }

  // ══════════════════════════════════════════
  // 🤲 DUA ÖNBELLEĞİ
  // ══════════════════════════════════════════

  Future<void> cachePrayers(List<PrayerPost> prayers) async {
    try {
      final db = await database;
      final batch = db.batch();
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
      debugPrint('💾 Dualar önbelleklendi (${prayers.length.clamp(0, 20)})');
    } catch (e) {
      debugPrint('💾 Önbelleğe alma hatası: $e');
    }
  }

  Future<List<PrayerPost>> getCachedPrayers() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps =
          await db.query('cached_prayers', orderBy: 'timestamp DESC');
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
