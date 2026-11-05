import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/bildirim.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import 'widgets/bolum_paneli.dart';

/// Kaza: kaza namazları ve kaza orucu tek sayfada.
/// Borç bir kez belirlenir; sonra kılındıkça/tutuldukça tek dokunuşla işaretlenir.
class KazaScreen extends StatelessWidget {
  const KazaScreen({super.key});

  static const _vakitler = ['Sabah', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    final p = context.watch<NamazProvider>();

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Kaza", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(Responsive.w(4), 0, Responsive.w(4), Responsive.h(30)),
        children: [
          _namazPaneli(context, r, p),
          _orucPaneli(context, r, p),
        ],
      ),
    );
  }

  // ───────────────────────── Kaza namazı ─────────────────────────

  Widget _namazPaneli(BuildContext context, AppThemeColors r, NamazProvider p) {
    final borclar = p.kazaBorclariMap;
    int kalan(String v) => ((borclar[v]?['toplamBorc'] ?? 0) - (borclar[v]?['kilinmis'] ?? 0)).clamp(0, 1 << 30);
    final toplamKalan = _vakitler.fold<int>(0, (t, v) => t + kalan(v));
    final toplam = p.toplamKazaBorcu;
    final kilinan = p.toplamKilinanKaza;
    // Her gün 1 günlük paket kılınırsa: en çok borcu olan vakit kadar gün
    final gunSayisi = _vakitler.map(kalan).fold<int>(0, (a, b) => a > b ? a : b);

    return BolumPaneli(
      padding: EdgeInsets.all(Responsive.w(16)),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _baslik(r, Icons.mosque_rounded, "Kaza Namazı",
            sag: TextButton.icon(
              onPressed: () => _borcBelirle(context, p),
              icon: Icon(Icons.edit_rounded, size: 16, color: r.anaRenk),
              label: Text(toplam == 0 ? "Borcu belirle" : "Düzenle",
                  style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
            )),
        SizedBox(height: Responsive.h(12)),
        if (toplamKalan == 0)
          _bosDurum(
            r,
            toplam == 0
                ? "Kaza namazı borcun kayıtlı değil. Kılamadığın namazlar varsa \"Borcu belirle\" ile ekle."
                : "Elhamdülillah, bütün kaza namazlarını tamamladın!",
            tamam: toplam > 0,
          )
        else ...[
          // Özet
          Row(
            children: [
              SizedBox(
                width: Responsive.w(74),
                height: Responsive.w(74),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: toplam == 0 ? 0 : kilinan / toplam,
                        strokeWidth: 7,
                        color: r.anaRenk,
                        backgroundColor: r.anaRenk.withOpacity(0.15),
                      ),
                    ),
                    Text("%${toplam == 0 ? 0 : (kilinan * 100 / toplam).floor()}",
                        style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(15))),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$toplamKalan vakit kaldı",
                        style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(18))),
                    Text("$kilinan / $toplam kılındı", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
                    SizedBox(height: Responsive.h(4)),
                    Text("Her gün 1 günlük kaza kılarsan ${_sureMetni(gunSayisi)} biter.",
                        style: TextStyle(color: r.anaRenk, fontSize: Responsive.sp(12), fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(14)),
          // Günlük paket
          SizedBox(
            height: Responsive.h(50),
            child: ElevatedButton.icon(
              onPressed: () async {
                final n = await p.kazaKilGunlukPaket();
                if (n == 0) return;
                Bildirim.snackBar(SnackBar(
                  content: Text("$n vakit kaza namazı işaretlendi. Allah kabul etsin!"),
                  backgroundColor: Colors.green,
                  action: SnackBarAction(
                    label: "Geri al",
                    onPressed: () async {
                      for (final v in _vakitler) {
                        await p.kazaGeriAl(v);
                      }
                    },
                  ),
                ));
              },
              icon: const Icon(Icons.done_all_rounded, color: Colors.white),
              label: const Text("1 günlük kaza kıldım (5 vakit)",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: r.anaRenk,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          SizedBox(height: Responsive.h(12)),
          // Vakit vakit
          for (final v in _vakitler)
            Container(
              margin: EdgeInsets.only(bottom: Responsive.h(6)),
              padding: EdgeInsets.fromLTRB(Responsive.w(14), Responsive.h(4), Responsive.w(6), Responsive.h(4)),
              decoration: BoxDecoration(color: r.icYuzey, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  SizedBox(
                    width: Responsive.w(64),
                    child: Text(v, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(14))),
                  ),
                  Expanded(
                    child: Text(kalan(v) == 0 ? "Tamamlandı" : "${kalan(v)} kaldı",
                        style: TextStyle(
                            color: kalan(v) == 0 ? const Color(0xFF2E9D57) : r.pasifRenk,
                            fontWeight: FontWeight.w600,
                            fontSize: Responsive.sp(13))),
                  ),
                  TextButton.icon(
                    onPressed: kalan(v) == 0
                        ? null
                        : () async {
                            await p.kazaKil(v);
                            Bildirim.snackBar(SnackBar(
                              content: Text("$v kazası işaretlendi."),
                              backgroundColor: Colors.green,
                              action: SnackBarAction(label: "Geri al", onPressed: () => p.kazaGeriAl(v)),
                            ));
                          },
                    icon: Icon(Icons.add_task_rounded, size: 18, color: kalan(v) == 0 ? r.pasifRenk : r.anaRenk),
                    label: Text("Kıldım",
                        style: TextStyle(color: kalan(v) == 0 ? r.pasifRenk : r.anaRenk, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
            ),
          SizedBox(height: Responsive.h(6)),
          _hatirlatma(context, r, p),
        ],
        SizedBox(height: Responsive.h(8)),
        Text("Vaktinde işaretlenmeyen namazlar ertesi gün kendiliğinden kaza borcuna eklenir.",
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
      ],
    );
  }

  String _sureMetni(int gun) {
    if (gun <= 1) return "bugün";
    if (gun < 45) return "yaklaşık $gun günde";
    if (gun < 730) return "yaklaşık ${(gun / 30).round()} ayda";
    return "yaklaşık ${(gun / 365).toStringAsFixed(1).replaceAll('.', ',')} yılda";
  }

  Widget _hatirlatma(BuildContext context, AppThemeColors r, NamazProvider p) {
    final saat = TimeOfDay(hour: p.kazaHatirlatmaSaat, minute: p.kazaHatirlatmaDakika);
    return Container(
      padding: EdgeInsets.fromLTRB(Responsive.w(14), Responsive.h(2), Responsive.w(6), Responsive.h(2)),
      decoration: BoxDecoration(color: r.icYuzey, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Icon(Icons.alarm_rounded, size: 20, color: r.anaRenk),
          SizedBox(width: Responsive.w(10)),
          Expanded(
            child: Text("Her gün hatırlat", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w700)),
          ),
          TextButton(
            onPressed: () async {
              final yeni = await showTimePicker(context: context, initialTime: saat);
              if (yeni != null) await p.kazaHatirlatmaAyarla(saat: yeni.hour, dakika: yeni.minute);
            },
            child: Text(saat.format(context), style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w800)),
          ),
          Switch(
            value: p.kazaHatirlatmaAcik,
            activeThumbColor: r.anaRenk,
            onChanged: (a) => p.kazaHatirlatmaAyarla(saat: saat.hour, dakika: saat.minute, acik: a),
          ),
        ],
      ),
    );
  }

  /// Borcu belirleme: kaç yıl/ay/gün namaz kılınmadı; istenirse vakit vakit
  Future<void> _borcBelirle(BuildContext context, NamazProvider p) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BorcPenceresi(provider: p),
    );
  }

  // ───────────────────────── Kaza orucu ─────────────────────────

  Widget _orucPaneli(BuildContext context, AppThemeColors r, NamazProvider p) {
    final borc = p.kazaOrucBorcu;
    final kilinan = p.kilinanKazaOrucu;
    final toplam = borc + kilinan;
    return BolumPaneli(
      padding: EdgeInsets.all(Responsive.w(16)),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _baslik(r, Icons.nightlight_round, "Kaza Orucu",
            sag: TextButton.icon(
              onPressed: () => _orucBorcuGir(context, p),
              icon: Icon(Icons.edit_rounded, size: 16, color: r.anaRenk),
              label: Text(toplam == 0 ? "Borcu belirle" : "Düzenle",
                  style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold)),
            )),
        SizedBox(height: Responsive.h(12)),
        if (borc == 0)
          _bosDurum(
            r,
            toplam == 0
                ? "Kaza orucu borcun kayıtlı değil. Tutamadığın oruçlar varsa \"Borcu belirle\" ile ekle."
                : "Elhamdülillah, bütün kaza oruçlarını tamamladın!",
            tamam: toplam > 0,
          )
        else ...[
          Row(
            children: [
              SizedBox(
                width: Responsive.w(74),
                height: Responsive.w(74),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: kilinan / toplam,
                        strokeWidth: 7,
                        color: r.anaRenk,
                        backgroundColor: r.anaRenk.withOpacity(0.15),
                      ),
                    ),
                    Text("%${(kilinan * 100 / toplam).floor()}",
                        style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(15))),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(14)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("$borc gün kaldı",
                        style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(18))),
                    Text("$kilinan / $toplam gün kaza edildi",
                        style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: Responsive.h(14)),
          SizedBox(
            height: Responsive.h(50),
            child: ElevatedButton.icon(
              onPressed: p.bugunOrucTutuldu
                  ? null
                  : () async {
                      await p.kazaOrucuTuttum();
                      Bildirim.snackBar(const SnackBar(
                        content: Text("Kaza orucun işaretlendi. Allah kabul etsin!"),
                        backgroundColor: Colors.green,
                      ));
                    },
              icon: Icon(Icons.check_rounded, color: p.bugunOrucTutuldu ? r.pasifRenk : Colors.white),
              label: Text(p.bugunOrucTutuldu ? "Bugünün orucu zaten işaretli" : "Bugün kaza orucu tuttum",
                  style: TextStyle(color: p.bugunOrucTutuldu ? r.pasifRenk : Colors.white, fontWeight: FontWeight.w800)),
              style: ElevatedButton.styleFrom(
                backgroundColor: r.anaRenk,
                disabledBackgroundColor: r.icYuzey,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
        SizedBox(height: Responsive.h(10)),
        Text("Mazeretle tutulamayan Ramazan oruçları, bayram günleri dışında herhangi bir günde kaza edilir (Bakara 2/184).",
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11), height: 1.4)),
      ],
    );
  }

  Future<void> _orucBorcuGir(BuildContext context, NamazProvider p) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _OrucBorcPenceresi(provider: p),
    );
  }

  // ───────────────────────── Ortak ─────────────────────────

  Widget _baslik(AppThemeColors r, IconData ikon, String ad, {Widget? sag}) => Row(
        children: [
          Container(
            padding: EdgeInsets.all(Responsive.w(6)),
            decoration: BoxDecoration(color: r.anaRenk.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(ikon, color: r.anaRenk, size: Responsive.w(18)),
          ),
          SizedBox(width: Responsive.w(10)),
          Expanded(
            child: Text(ad, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(17))),
          ),
          ?sag,
        ],
      );

  Widget _bosDurum(AppThemeColors r, String yazi, {required bool tamam}) => Container(
        padding: EdgeInsets.all(Responsive.w(14)),
        decoration: BoxDecoration(color: r.icYuzey, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(tamam ? Icons.verified_rounded : Icons.info_outline_rounded,
                color: tamam ? const Color(0xFF2E9D57) : r.anaRenk),
            SizedBox(width: Responsive.w(10)),
            Expanded(child: Text(yazi, style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(13), height: 1.4))),
          ],
        ),
      );
}

/// Kaza namazı borcunu belirleme penceresi
class _BorcPenceresi extends StatefulWidget {
  final NamazProvider provider;
  const _BorcPenceresi({required this.provider});

  @override
  State<_BorcPenceresi> createState() => _BorcPenceresiState();
}

class _BorcPenceresiState extends State<_BorcPenceresi> {
  int _yil = 0, _ay = 0, _gun = 0;
  bool _ozelHal = true; // kadınlarda her ay ortalama 7 gün düşülür
  bool _elle = false;
  late final Map<String, int> _vakitBorc = {
    for (final v in KazaScreen._vakitler) v: widget.provider.kazaBorclariMap[v]?['toplamBorc'] ?? 0,
  };

  int get _toplamGun {
    var g = _yil * 365 + _ay * 30 + _gun;
    if (widget.provider.kadinMi && _ozelHal) g -= (g / 30 * 7).floor();
    return g < 0 ? 0 : g;
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final p = widget.provider;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.paddingOf(context).bottom + 16),
      decoration: BoxDecoration(color: r.arkaPlanRengi, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: r.pasifRenk.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 14),
            Text("Kaza borcunu belirle",
                textAlign: TextAlign.center,
                style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              _elle ? "Her vakit için toplam borcu gir." : "Ergenlik çağından sonra namaz kılmadığın süreyi yaklaşık olarak gir.",
              textAlign: TextAlign.center,
              style: TextStyle(color: r.pasifRenk, fontSize: 12),
            ),
            if (p.toplamKazaBorcu > 0) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: r.anaRenk.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  _vakitBorc.values.toSet().length == 1
                      ? "Şu anki borcun: her vakit için ${_vakitBorc.values.first} gün. Kaydedersen yenisiyle değişir."
                      : "Şu anki borcun vakitlere göre farklı. Görmek için \"Vakit vakit elle gir\". Kaydedersen yenisiyle değişir.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: r.yaziRengi, fontSize: 12, height: 1.35),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (!_elle) ...[
              _sayac(r, "Yıl", _yil, (v) => setState(() => _yil = v)),
              _sayac(r, "Ay", _ay, (v) => setState(() => _ay = v)),
              _sayac(r, "Gün", _gun, (v) => setState(() => _gun = v)),
              if (p.kadinMi)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _ozelHal,
                  activeThumbColor: r.anaRenk,
                  onChanged: (v) => setState(() => _ozelHal = v),
                  title: Text("Özel hâl günlerini düş", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w700)),
                  subtitle: Text("Her ay için ortalama 7 gün", style: TextStyle(color: r.pasifRenk, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              Text("Her vakit için $_toplamGun gün kaza borcu",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900, fontSize: 15)),
            ] else
              for (final v in KazaScreen._vakitler)
                _sayac(r, v, _vakitBorc[v]!, (x) => setState(() => _vakitBorc[v] = x), adim: 10),
            TextButton(
              onPressed: () => setState(() => _elle = !_elle),
              child: Text(_elle ? "Süreyle hesapla" : "Vakit vakit elle gir", style: TextStyle(color: r.anaRenk)),
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  final borclar = _elle
                      ? Map<String, int>.from(_vakitBorc)
                      : {for (final v in KazaScreen._vakitler) v: _toplamGun};
                  await p.kazaBorcunuAyarla(borclar);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  Bildirim.snackBar(const SnackBar(content: Text("Kaza borcun kaydedildi."), backgroundColor: Colors.green));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: r.anaRenk,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
              ),
            ),
            if (p.toplamKazaBorcu > 0)
              TextButton(
                onPressed: () async {
                  final evet = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      backgroundColor: r.kartRengi,
                      title: Text("Kayıtlar sıfırlansın mı?", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900)),
                      content: Text("Bütün kaza namazı borcun ve kıldığın kazaların sayısı silinir. Bu geri alınamaz.",
                          style: TextStyle(color: r.yaziRengi.withOpacity(0.8))),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(d, false), child: Text("Vazgeç", style: TextStyle(color: r.pasifRenk))),
                        TextButton(onPressed: () => Navigator.pop(d, true), child: Text("Sıfırla", style: TextStyle(color: r.kirmizi, fontWeight: FontWeight.w800))),
                      ],
                    ),
                  );
                  if (evet != true) return;
                  await p.sifirlaKaza();
                  if (context.mounted) Navigator.pop(context);
                  Bildirim.snackBar(const SnackBar(content: Text("Kaza namazı kayıtları sıfırlandı.")));
                },
                child: Text("Tüm kaza namazı kayıtlarını sıfırla", style: TextStyle(color: r.kirmizi)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sayac(AppThemeColors r, String ad, int deger, ValueChanged<int> degis, {int adim = 1}) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Expanded(child: Text(ad, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w700, fontSize: 15))),
            IconButton.filledTonal(
              onPressed: deger > 0 ? () => degis((deger - adim).clamp(0, 1 << 30)) : null,
              icon: const Icon(Icons.remove_rounded),
            ),
            GestureDetector(
              onTap: () async {
                final c = TextEditingController(text: '$deger');
                final yeni = await showDialog<int>(
                  context: context,
                  builder: (d) => AlertDialog(
                    title: Text(ad),
                    content: TextField(controller: c, keyboardType: TextInputType.number, autofocus: true),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d), child: const Text("Vazgeç")),
                      TextButton(onPressed: () => Navigator.pop(d, int.tryParse(c.text.trim())), child: const Text("Tamam")),
                    ],
                  ),
                );
                if (yeni != null && yeni >= 0) degis(yeni);
              },
              child: SizedBox(
                width: 64,
                child: Text("$deger",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: 20)),
              ),
            ),
            IconButton.filledTonal(onPressed: () => degis(deger + adim), icon: const Icon(Icons.add_rounded)),
          ],
        ),
      );
}

/// Kaza orucu borcunu belirleme: doğrudan yazılabilen büyük sayı, − / + ve hızlı ekleme
class _OrucBorcPenceresi extends StatefulWidget {
  final NamazProvider provider;
  const _OrucBorcPenceresi({required this.provider});

  @override
  State<_OrucBorcPenceresi> createState() => _OrucBorcPenceresiState();
}

class _OrucBorcPenceresiState extends State<_OrucBorcPenceresi> {
  late final TextEditingController _c =
      TextEditingController(text: widget.provider.kazaOrucBorcu == 0 ? '' : '${widget.provider.kazaOrucBorcu}');

  int get _deger => int.tryParse(_c.text.trim()) ?? 0;

  void _ayarla(int v) {
    final yeni = v < 0 ? 0 : v;
    setState(() {
      _c.text = yeni == 0 ? '' : '$yeni';
      _c.selection = TextSelection.collapsed(offset: _c.text.length);
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final p = widget.provider;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).viewInsets.bottom + MediaQuery.paddingOf(context).bottom + 16),
      decoration: BoxDecoration(color: r.arkaPlanRengi, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: r.pasifRenk.withOpacity(0.35), borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          Text("Kaza orucu borcu",
              textAlign: TextAlign.center, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: 18)),
          const SizedBox(height: 4),
          Text("Henüz kaza etmediğin oruç sayısını yaz ya da düğmelerle ayarla.",
              textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk, fontSize: 12)),
          const SizedBox(height: 18),
          Row(
            children: [
              IconButton.filledTonal(
                iconSize: 28,
                onPressed: _deger > 0 ? () => _ayarla(_deger - 1) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _c,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  onChanged: (_) => setState(() {}),
                  style: TextStyle(color: r.yaziRengi, fontSize: 36, fontWeight: FontWeight.w900),
                  decoration: InputDecoration(
                    hintText: "0",
                    filled: true,
                    fillColor: r.kartRengi,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: r.anaRenk, width: 2)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton.filledTonal(iconSize: 28, onPressed: () => _ayarla(_deger + 1), icon: const Icon(Icons.add_rounded)),
            ],
          ),
          const SizedBox(height: 6),
          Text("gün", textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final n in const [5, 10, 30])
                ActionChip(
                  label: Text("+$n gün"),
                  labelStyle: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold),
                  backgroundColor: r.anaRenk.withOpacity(0.1),
                  side: BorderSide.none,
                  onPressed: () => _ayarla(_deger + n),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: () async {
                await p.kazaOrucBorcuAyarla(_deger);
                if (!context.mounted) return;
                Navigator.pop(context);
                Bildirim.snackBar(SnackBar(
                  content: Text(_deger == 0 ? "Kaza orucu borcu kaldırıldı." : "Kaza orucu borcun $_deger gün olarak kaydedildi."),
                  backgroundColor: Colors.green,
                ));
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: r.anaRenk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
