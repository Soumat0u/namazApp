import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Ortak hatimde bir cüzün durumu
class CuzDurumu {
  final String? uid;
  final String ad;
  final bool bitti;
  const CuzDurumu({this.uid, this.ad = '', this.bitti = false});

  bool get bos => uid == null;

  factory CuzDurumu.fromMap(Map<String, dynamic>? m) =>
      m == null ? const CuzDurumu() : CuzDurumu(uid: m['uid'], ad: m['ad'] ?? '', bitti: m['bitti'] ?? false);
}

class OrtakHatim {
  final String id;
  final String ad;
  final String olusturan;
  final List<String> uyeler;
  final Map<int, CuzDurumu> cuzler; // 1..30

  OrtakHatim({required this.id, required this.ad, required this.olusturan, required this.uyeler, required this.cuzler});

  int get bitenCuz => cuzler.values.where((c) => c.bitti).length;
  int get alinanCuz => cuzler.values.where((c) => !c.bos).length;
  bool get tamamlandi => bitenCuz == 30;

  factory OrtakHatim.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final ham = Map<String, dynamic>.from(data['cuzler'] ?? {});
    return OrtakHatim(
      id: doc.id,
      ad: data['ad'] ?? 'Hatim',
      olusturan: data['olusturan'] ?? '',
      uyeler: List<String>.from(data['uyeler'] ?? []),
      cuzler: {for (int i = 1; i <= 30; i++) i: CuzDurumu.fromMap(ham['$i'] as Map<String, dynamic>?)},
    );
  }
}

/// Kardeşlerle ortak hatim: her üye boş bir cüzü üstlenir ve okuyunca işaretler
class HatimServisi {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<OrtakHatim>> hatimlerim(String uid) => _db
      .collection('hatimler')
      .where('uyeler', arrayContains: uid)
      .snapshots()
      .map((s) => s.docs.map(OrtakHatim.fromFirestore).toList());

  Future<String?> olustur({required String uid, required String ad, required List<String> davetliler}) async {
    try {
      await _db.collection('hatimler').add({
        'ad': ad,
        'olusturan': uid,
        'uyeler': {uid, ...davetliler}.toList(),
        'cuzler': <String, dynamic>{},
        'olusturulma': FieldValue.serverTimestamp(),
      });
      return null;
    } catch (e) {
      debugPrint('📖 Hatim oluşturma hatası: $e');
      return 'Hatim oluşturulamadı. İnternet bağlantınızı kontrol edin.';
    }
  }

  /// Boş cüzü üstlenir. Aynı anda başkası aldıysa hata mesajı döner.
  Future<String?> cuzAl(String hatimId, int cuz, String uid, String ad) async {
    final ref = _db.collection('hatimler').doc(hatimId);
    try {
      return await _db.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final mevcut = (snap.data()?['cuzler'] as Map<String, dynamic>?)?['$cuz'];
        if (mevcut != null) return 'Bu cüzü az önce başka bir kardeşin aldı.';
        tx.update(ref, {'cuzler.$cuz': {'uid': uid, 'ad': ad, 'bitti': false}});
        return null;
      });
    } catch (e) {
      debugPrint('📖 Cüz alma hatası: $e');
      return 'Cüz alınamadı.';
    }
  }

  Future<void> cuzBitir(String hatimId, int cuz, bool bitti) =>
      _db.collection('hatimler').doc(hatimId).update({'cuzler.$cuz.bitti': bitti});

  Future<void> cuzBirak(String hatimId, int cuz) =>
      _db.collection('hatimler').doc(hatimId).update({'cuzler.$cuz': FieldValue.delete()});

  Future<void> sil(String hatimId) => _db.collection('hatimler').doc(hatimId).delete();
}
