import 'dart:math';

import 'package:flutter/material.dart';

import '../core/constants/app_colors.dart';
import '../core/constants/dualar.dart';
import '../core/utils/responsive.dart';
import '../services/ezber_servisi.dart';

/// Ezber seviyesi: okunuştaki kelimelerin ne kadarının gizleneceği
enum _Seviye {
  oku('Oku', 0.0, false),
  kolay('Kolay', 0.3, true),
  orta('Orta', 0.6, true),
  zor('Zor', 1.0, false);

  final String ad;
  final double oran;
  /// Gizli kelimenin ilk harfi ipucu olarak görünür mü
  final bool ipucu;
  const _Seviye(this.ad, this.oran, this.ipucu);
}

/// Dua ezberleme: okunuştaki kelimeler kademeli gizlenir, kullanıcı içinden
/// okuyup dokunarak kontrol eder; sonunda "Bildim / Zorlandım" ile aralıklı
/// tekrar takvimine işlenir.
class DuaEzberScreen extends StatefulWidget {
  final Dua dua;
  const DuaEzberScreen({super.key, required this.dua});

  @override
  State<DuaEzberScreen> createState() => _DuaEzberScreenState();
}

class _DuaEzberScreenState extends State<DuaEzberScreen> {
  late final List<List<String>> _cumleler = widget.dua.okunus
      .split(RegExp(r'(?<=[.!?])\s+'))
      .where((c) => c.trim().isNotEmpty)
      .map((c) => c.trim().split(RegExp(r'\s+')))
      .toList();
  late final int _kelimeSayisi = _cumleler.fold(0, (t, c) => t + c.length);

  _Seviye _seviye = _Seviye.kolay;
  int _tohum = 0; // "Karıştır" ile farklı kelimeler gizlenir
  Set<int> _gizli = {};
  final Set<int> _acilan = {};

  @override
  void initState() {
    super.initState();
    EzberServisi.ornek.yukle();
    // Daha önce çalışılmışsa kaldığı seviyeden başlar
    final kutu = EzberServisi.ornek.durum(widget.dua.baslik)?.kutu ?? 0;
    _seviye = kutu >= 3 ? _Seviye.zor : (kutu >= 1 ? _Seviye.orta : _Seviye.kolay);
    _gizle();
  }

  void _gizle() {
    final adet = (_kelimeSayisi * _seviye.oran).round();
    final sira = List.generate(_kelimeSayisi, (i) => i)..shuffle(Random(widget.dua.baslik.hashCode + _tohum));
    _gizli = sira.take(adet).toSet();
    _acilan.clear();
  }

  void _seviyeSec(_Seviye s) => setState(() {
        _seviye = s;
        _gizle();
      });

  Future<void> _sonuc(bool bildi) async {
    await EzberServisi.ornek.sonuc(widget.dua.baslik, bildi: bildi);
    if (!mounted) return;
    final d = EzberServisi.ornek.durum(widget.dua.baslik)!;
    final gun = DateTime.parse(d.sonraki).difference(DateTime.parse(EzberServisi.bugun())).inDays;
    await showDialog(
      context: context,
      builder: (c) {
        final r = c.renkler;
        return AlertDialog(
          backgroundColor: r.kartRengi,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          icon: Icon(bildi ? Icons.celebration_rounded : Icons.replay_rounded, color: r.anaRenk, size: 40),
          title: Text(
            d.ezberlendi ? "Maşallah, ezberlendi!" : (bildi ? "Güzel gidiyor" : "Tekrar edelim"),
            style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900),
          ),
          content: Text(
            bildi
                ? "Bir sonraki tekrar $gun gün sonra. Aralıklarla tekrar ettikçe kalıcı olur."
                : "Yarın tekrar sorulacak. Birkaç kez daha okuyup dinlemek iyi gelir.",
            textAlign: TextAlign.center,
            style: TextStyle(color: r.yaziRengi.withOpacity(0.8)),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text("Tamam", style: TextStyle(color: r.anaRenk))),
          ],
        );
      },
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    final durum = EzberServisi.ornek.durum(widget.dua.baslik);
    final gizliKalan = _gizli.difference(_acilan).length;
    int sayac = 0;

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Ezber: ${widget.dua.baslik}", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.h(4), Responsive.w(16), Responsive.h(30)),
        children: [
          // İlerleme: 5 kutu
          Row(
            children: [
              for (int i = 0; i < EzberDurumu.enUstKutu; i++)
                Expanded(
                  child: Container(
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i < (durum?.kutu ?? 0) ? r.anaRenk : r.pasifRenk.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: Responsive.h(6)),
          Text(
            durum == null
                ? "İlk kez çalışıyorsun"
                : durum.ezberlendi
                    ? "Ezberlendi • tekrarla pekiştir"
                    : "Ezber ilerlemesi: ${durum.kutu}/${EzberDurumu.enUstKutu}",
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12)),
          ),
          SizedBox(height: Responsive.h(14)),
          // Seviye seçimi
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(color: r.anaRenk.withOpacity(0.08), borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                for (final s in _Seviye.values)
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _seviyeSec(s),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _seviye == s ? r.kartRengi : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(s.ad,
                            style: TextStyle(
                                color: _seviye == s ? r.anaRenk : r.yaziRengi.withOpacity(0.6),
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(14)),
          // Metin
          Container(
            padding: EdgeInsets.all(Responsive.w(18)),
            decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final cumle in _cumleler)
                  Padding(
                    padding: EdgeInsets.only(bottom: Responsive.h(10)),
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 8,
                      children: [
                        for (final k in cumle) _kelime(r, k, sayac++),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(8)),
          Row(
            children: [
              Expanded(
                child: Text(
                  _seviye == _Seviye.oku
                      ? "Önce birkaç kez okuyun, sonra bir seviye seçin."
                      : "İçinizden okuyun; emin olamadığınız kelimeye dokunup bakın. Gizli: $gizliKalan",
                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12)),
                ),
              ),
              if (_seviye != _Seviye.oku && _seviye != _Seviye.zor)
                TextButton.icon(
                  onPressed: () => setState(() {
                    _tohum++;
                    _gizle();
                  }),
                  icon: Icon(Icons.shuffle_rounded, size: 18, color: r.anaRenk),
                  label: Text("Karıştır", style: TextStyle(color: r.anaRenk)),
                ),
            ],
          ),
          if (widget.dua.meal.isNotEmpty) ...[
            SizedBox(height: Responsive.h(8)),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text("Anlamı", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
              children: [
                Text(widget.dua.meal, style: TextStyle(color: r.yaziRengi.withOpacity(0.8), height: 1.45)),
              ],
            ),
          ],
          SizedBox(height: Responsive.h(18)),
          if (_seviye != _Seviye.oku)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sonuc(false),
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text("Zorlandım"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: r.yaziRengi,
                      side: BorderSide(color: r.pasifRenk.withOpacity(0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
                SizedBox(width: Responsive.w(10)),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _sonuc(true),
                    icon: const Icon(Icons.check_rounded, color: Colors.white),
                    label: const Text("Bildim", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: r.anaRenk,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _kelime(AppThemeColors r, String kelime, int i) {
    final stil = TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(17), height: 1.3, fontWeight: FontWeight.w500);
    if (!_gizli.contains(i) || _acilan.contains(i)) {
      return Text(kelime,
          style: _acilan.contains(i) ? stil.copyWith(color: r.anaRenk, fontWeight: FontWeight.w700) : stil);
    }
    // Gizli kelime: yaklaşık genişliğinde bir kutu; dokununca açılır
    final ipucu = _seviye.ipucu ? kelime.characters.first : '';
    return GestureDetector(
      onTap: () => setState(() => _acilan.add(i)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        constraints: BoxConstraints(minWidth: (kelime.length * Responsive.sp(17) * 0.5).clamp(28, 160)),
        decoration: BoxDecoration(
          color: r.anaRenk.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border(bottom: BorderSide(color: r.anaRenk.withOpacity(0.5), width: 2)),
        ),
        child: Text(ipucu, style: stil.copyWith(color: r.anaRenk.withOpacity(0.7))),
      ),
    );
  }
}
