import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/bildirim.dart';
import '../../core/utils/responsive.dart';
import '../../providers/namaz_provider.dart';
import '../../services/kuran_hedefi.dart';
import '../kuran_screen.dart';
import 'bolum_paneli.dart';

/// Ramazan'da ana sayfanın üstünde: günü, iftar/sahur geri sayımı ve günün
/// ne kadarının geçtiği; bugünün orucu, teravihi ve Kur'an'ı; Ramazan boyunca
/// tutulan oruçlar.
class RamazanKarti extends StatefulWidget {
  /// Önizleme/test için "şu an" (verilmezse gerçek saat)
  final DateTime Function()? saat;
  const RamazanKarti({super.key, this.saat});

  @override
  State<RamazanKarti> createState() => _RamazanKartiState();
}

enum _Evre { sahur, oruc, iftar }

class _RamazanKartiState extends State<RamazanKarti> {
  late final Timer _saniye;
  DateTime get _simdi => widget.saat?.call() ?? DateTime.now();
  /// Kart açık mı (kapalıyken ince bir şerit; saat kartı ve vakitler yukarıda kalsın diye)
  bool _acik = false;
  bool _degistirildi = false; // kayıtlı tercih geç okunursa kullanıcının dokunuşunu ezmesin

  @override
  void initState() {
    super.initState();
    KuranHedefi.ornek.yukle();
    SharedPreferences.getInstance().then((p) {
      if (mounted && !_degistirildi) setState(() => _acik = p.getBool('ramazan_karti_acik') ?? false);
    });
    _saniye = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _saniye.cancel();
    super.dispose();
  }

  String _sure(Duration d) {
    if (d.isNegative) d = Duration.zero;
    return "${d.inHours.toString().padLeft(2, '0')}:${(d.inMinutes % 60).toString().padLeft(2, '0')}:${(d.inSeconds % 60).toString().padLeft(2, '0')}";
  }

  DateTime? _vakit(NamazProvider p, String ad) {
    final s = p.vakitler?[ad];
    if (s == null) return null;
    final parca = s.split(':');
    final n = _simdi;
    return DateTime(n.year, n.month, n.day, int.tryParse(parca[0]) ?? 0, int.tryParse(parca.length > 1 ? parca[1] : '0') ?? 0);
  }

  void _acKapat() {
    _degistirildi = true;
    setState(() => _acik = !_acik);
    SharedPreferences.getInstance().then((p) => p.setBool('ramazan_karti_acik', _acik));
  }

  Future<void> _orucDegistir(NamazProvider p) async {
    final yeni = !p.bugunOrucTutuldu;
    await p.bugunOrucDegistir(yeni);
    Bildirim.snackBar(SnackBar(
      content: Text(yeni ? "Orucun işaretlendi. Allah kabul etsin!" : "Oruç işareti kaldırıldı."),
      backgroundColor: yeni ? Colors.green : null,
      action: SnackBarAction(label: "Geri al", onPressed: () => p.bugunOrucDegistir(!yeni)),
    ));
  }

  Future<void> _gunDegistir(NamazProvider p, String gun, int no) async {
    final yeni = !p.orucGunleri.contains(gun);
    await p.orucGunuDegistir(gun, yeni);
    Bildirim.snackBar(SnackBar(
      content: Text(yeni ? "Ramazan'ın $no. günü: oruç tutuldu olarak işaretlendi." : "Ramazan'ın $no. günü: oruç işareti kaldırıldı."),
      backgroundColor: yeni ? Colors.green : null,
      action: SnackBarAction(label: "Geri al", onPressed: () => p.orucGunuDegistir(gun, !yeni)),
    ));
  }

  Future<void> _teravihDegistir(NamazProvider p) async {
    final yeni = !p.buGeceTeravihKilindi;
    await p.teravihDegistir(yeni);
    if (yeni) {
      Bildirim.snackBar(SnackBar(
        content: const Text("Teravih işaretlendi. Allah kabul etsin!"),
        backgroundColor: Colors.green,
        action: SnackBarAction(label: "Geri al", onPressed: () => p.teravihDegistir(false)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final p = context.watch<NamazProvider>();
    final gun = p.ramazanGunu;
    if (gun == null) return const SizedBox.shrink();

    final simdi = _simdi;
    final bugun = p.orucVakitleri(simdi);
    // Yarının vakti takvimde henüz yoksa bugünkü imsak saatiyle tahmin edilir (bir iki dakika fark eder)
    final yarin = p.orucVakitleri(DateTime(simdi.year, simdi.month, simdi.day + 1)) ??
        (bugun == null ? null : (imsak: bugun.imsak.add(const Duration(days: 1)), iftar: bugun.iftar.add(const Duration(days: 1))));
    final _Evre evre = bugun == null || simdi.isBefore(bugun.imsak)
        ? _Evre.sahur
        : simdi.isBefore(bugun.iftar)
            ? _Evre.oruc
            : _Evre.iftar;
    final (String etiket, DateTime? hedef) = switch (evre) {
      _Evre.sahur => ("SAHURUN BİTMESİNE", bugun?.imsak),
      _Evre.oruc => ("İFTARA KALAN", bugun?.iftar),
      _Evre.iftar => ("YARIN SAHURUN BİTMESİNE", yarin?.imsak),
    };
    final yatsi = _vakit(p, 'Yatsı');
    final teravihVakti = yatsi != null && !simdi.isBefore(yatsi);

    final koyu = Color.alphaBlend(Colors.black.withOpacity(0.38), r.anaRenk);
    return Container(
      margin: EdgeInsets.fromLTRB(Responsive.w(16), 0, Responsive.w(16), Responsive.h(14)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(_acik ? 26 : 22),
        boxShadow: [BoxShadow(color: r.anaRenk.withOpacity(0.18), blurRadius: 22, offset: const Offset(0, 8))],
      ),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: _acik
            ? _tamKart(r, p, gun, koyu, etiket, hedef, bugun, evre, simdi, teravihVakti)
            : _serit(r, p, gun, koyu, evre, hedef, simdi),
      ),
    );
  }

  /// Kapalı hâl: gün, geri sayım ve tek dokunuşla oruç
  Widget _serit(AppThemeColors r, NamazProvider p, int gun, Color koyu, _Evre evre, DateTime? hedef, DateTime simdi) {
    final kisa = switch (evre) {
      _Evre.sahur => "Sahurun bitmesine",
      _Evre.oruc => "İftara",
      _Evre.iftar => "Yarın sahura",
    };
    final tuttu = p.bugunOrucTutuldu;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _acKapat,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [koyu, r.anaRenk], begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          padding: EdgeInsets.fromLTRB(Responsive.w(12), Responsive.h(10), Responsive.w(4), Responsive.h(10)),
          child: Row(
            children: [
              Transform.scale(scale: 0.85, child: _gunHalkasi(gun)),
              SizedBox(width: Responsive.w(8)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Ramazan • $kisa",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontWeight: FontWeight.w700, fontSize: Responsive.sp(11))),
                    Text(
                      hedef == null ? "--:--:--" : _sure(hedef.difference(simdi)),
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: Responsive.sp(22),
                        height: 1.15,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              // Oruç: tek dokunuşla işaretle
              Material(
                color: tuttu ? Colors.white : Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(20),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _orucDegistir(p),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(8)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(tuttu ? Icons.check_circle_rounded : Icons.nightlight_round,
                            size: 18, color: tuttu ? const Color(0xFF2E9D57) : Colors.white),
                        const SizedBox(width: 6),
                        Text(tuttu ? "Oruç tutuldu" : (evre == _Evre.iftar ? "Orucumu tuttum" : "Oruçluyum"),
                            style: TextStyle(
                                color: tuttu ? const Color(0xFF2E9D57) : Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: Responsive.sp(12))),
                      ],
                    ),
                  ),
                ),
              ),
              Icon(Icons.expand_more_rounded, color: Colors.white.withOpacity(0.9)),
              SizedBox(width: Responsive.w(4)),
            ],
          ),
        ),
      ),
    );
  }

  /// Açık hâl: bütün ayrıntılar
  Widget _tamKart(AppThemeColors r, NamazProvider p, int gun, Color koyu, String etiket, DateTime? hedef,
      ({DateTime imsak, DateTime iftar})? bugun, _Evre evre, DateTime simdi, bool teravihVakti) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ust(r, p, gun, koyu, etiket, hedef, bugun, evre, simdi),
          Padding(
            padding: EdgeInsets.fromLTRB(Responsive.w(14), Responsive.h(14), Responsive.w(14), Responsive.h(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _baslik(r, "BUGÜN"),
                SizedBox(height: Responsive.h(8)),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _Kutu(
                          ikon: Icons.nightlight_round,
                          ad: "Oruç",
                          durum: p.bugunOrucTutuldu ? "Tutuldu" : "Dokun, işaretle",
                          secili: p.bugunOrucTutuldu,
                          onTap: () => _orucDegistir(p),
                        ),
                      ),
                      SizedBox(width: Responsive.w(8)),
                      Expanded(
                        child: _Kutu(
                          ikon: Icons.mosque_rounded,
                          ad: "Teravih",
                          durum: p.buGeceTeravihKilindi ? "Kılındı" : (teravihVakti ? "Dokun, işaretle" : "Yatsıdan sonra"),
                          secili: p.buGeceTeravihKilindi,
                          pasif: !teravihVakti && !p.buGeceTeravihKilindi,
                          onTap: teravihVakti || p.buGeceTeravihKilindi ? () => _teravihDegistir(p) : null,
                        ),
                      ),
                      SizedBox(width: Responsive.w(8)),
                      Expanded(
                        child: ListenableBuilder(
                          listenable: KuranHedefi.ornek,
                          builder: (context, _) {
                            final h = KuranHedefi.ornek;
                            return _Kutu(
                              ikon: Icons.import_contacts_rounded,
                              ad: "Kur'an",
                              durum: h.hedef == 0 ? "Hedef koy" : "${h.bugunOkunan} / ${h.hedef} sayfa",
                              secili: h.tamamlandi,
                              ilerleme: h.hedef == 0 ? null : h.oran,
                              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KuranScreen())),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: Responsive.h(16)),
                _ramazanIlerlemesi(r, p, simdi),
              ],
            ),
          ),
        ],
    );
  }

  /// Renkli üst bölüm: gün, geri sayım, imsak → iftar çizelgesi
  Widget _ust(AppThemeColors r, NamazProvider p, int gun, Color koyu, String etiket, DateTime? hedef,
      ({DateTime imsak, DateTime iftar})? bugun, _Evre evre, DateTime simdi) {
    final beyaz70 = Colors.white.withOpacity(0.75);
    return Container(
      padding: EdgeInsets.fromLTRB(Responsive.w(18), Responsive.h(14), Responsive.w(12), Responsive.h(16)),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [koyu, r.anaRenk], begin: Alignment.topLeft, end: Alignment.bottomRight),
      ),
      // Kesme yok: gün halkasının çizgisi kenardan taşınca kırpılıyordu (hilal süsü kartın kenarında kesilir)
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: Responsive.w(-18),
            bottom: Responsive.h(-34),
            child: Icon(Icons.nightlight_round, size: Responsive.w(120), color: Colors.white.withOpacity(0.07)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _gunHalkasi(gun),
                  SizedBox(width: Responsive.w(10)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Ramazan-ı Şerif",
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: Responsive.sp(16))),
                        Text(p.ramazanOnizleme ? "$gun. gün • önizleme" : "$gun. gün • Hayırlı Ramazanlar",
                            style: TextStyle(color: beyaz70, fontSize: Responsive.sp(12), fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  if (p.bildirimlerAcik)
                    IconButton(
                      tooltip: p.orucModu ? "Sahur ve iftar bildirimleri açık" : "Sahur ve iftar bildirimlerini aç",
                      onPressed: () async {
                        final acik = !p.orucModu;
                        await p.orucModuDegistir(acik);
                        Bildirim.snackBar(SnackBar(
                          content: Text(acik
                              ? "Sahur (imsaktan 45 dk önce) ve iftar bildirimleri açıldı."
                              : "Sahur ve iftar bildirimleri kapatıldı."),
                        ));
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withOpacity(p.orucModu ? 0.22 : 0.10),
                      ),
                      icon: Icon(p.orucModu ? Icons.notifications_active_rounded : Icons.notifications_off_outlined,
                          color: Colors.white, size: 20),
                    ),
                  IconButton(
                    tooltip: "Küçült",
                    onPressed: _acKapat,
                    icon: const Icon(Icons.expand_less_rounded, color: Colors.white),
                  ),
                ],
              ),
              SizedBox(height: Responsive.h(14)),
              Text(etiket,
                  style: TextStyle(color: beyaz70, fontWeight: FontWeight.w800, letterSpacing: 1.4, fontSize: Responsive.sp(11))),
              Text(
                hedef == null ? "--:--:--" : _sure(hedef.difference(simdi)),
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: Responsive.sp(40),
                  height: 1.1,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (evre == _Evre.iftar)
                Text("Hayırlı iftarlar! Allah orucunuzu kabul etsin.",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: Responsive.sp(12))),
              if (bugun != null) ...[
                SizedBox(height: Responsive.h(12)),
                _cizelge(bugun, simdi, evre),
              ],
            ],
          ),
        ],
      ),
    );
  }

  /// Ramazan'ın kaçıncı günü: 30 üzerinden halka
  Widget _gunHalkasi(int gun) => SizedBox(
        width: Responsive.w(44),
        height: Responsive.w(44),
        child: Stack(
          alignment: Alignment.center,
          children: [
            SizedBox.expand(
              child: CircularProgressIndicator(
                value: gun / 30,
                strokeWidth: 4,
                color: Colors.white,
                backgroundColor: Colors.white.withOpacity(0.2),
              ),
            ),
            Text("$gun", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: Responsive.sp(16))),
          ],
        ),
      );

  /// İmsak → iftar çubuğu; güneş günün geçen kısmına göre ilerler
  Widget _cizelge(({DateTime imsak, DateTime iftar}) v, DateTime simdi, _Evre evre) {
    final toplam = v.iftar.difference(v.imsak).inSeconds;
    final oran = switch (evre) {
      _Evre.sahur => 0.0,
      _Evre.iftar => 1.0,
      _Evre.oruc => (simdi.difference(v.imsak).inSeconds / toplam).clamp(0.0, 1.0),
    };
    final saat = DateFormat('HH:mm');
    final yazi = TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: Responsive.sp(12));
    return Column(
      children: [
        LayoutBuilder(builder: (_, c) {
          final ikon = Responsive.w(22);
          final x = (c.maxWidth - ikon) * oran;
          return SizedBox(
            height: ikon,
            child: Stack(
              alignment: Alignment.centerLeft,
              children: [
                Container(
                  height: 6,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.22), borderRadius: BorderRadius.circular(3)),
                ),
                Container(
                  width: x + ikon / 2,
                  height: 6,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.85), borderRadius: BorderRadius.circular(3)),
                ),
                Positioned(
                  left: x,
                  child: Container(
                    width: ikon,
                    height: ikon,
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: Icon(
                      evre == _Evre.oruc ? Icons.wb_sunny_rounded : Icons.nightlight_round,
                      size: ikon * 0.68,
                      color: const Color(0xFFF2A33A),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        SizedBox(height: Responsive.h(6)),
        Row(
          children: [
            Text("İmsak ${saat.format(v.imsak)}", style: yazi),
            const Spacer(),
            Text("İftar ${saat.format(v.iftar)}", style: yazi),
          ],
        ),
      ],
    );
  }

  Widget _baslik(AppThemeColors r, String s) => Text(s,
      style: TextStyle(color: r.pasifRenk, fontWeight: FontWeight.w900, letterSpacing: 1.4, fontSize: Responsive.sp(11)));

  /// Bu Ramazan: tutulan oruçlar ve kılınan teravihler, 30 parçalı çubuk
  Widget _ramazanIlerlemesi(AppThemeColors r, NamazProvider p, DateTime simdi) {
    final gunler = p.buRamazaninGunleri;
    final bugun = DateFormat('yyyy-MM-dd').format(simdi);
    final gecen = gunler.where((g) => g.compareTo(bugun) <= 0).length;
    final tutulan = gunler.where(p.orucGunleri.contains).length;
    final teravih = gunler.where(p.teravihGunleri.contains).length;
    final kacan = gunler.where((g) => g.compareTo(bugun) < 0 && !p.orucGunleri.contains(g)).length;
    final kacanRenk = r.kartUstunde(r.kirmizi, 0.35);
    final gelecek = r.kartUstunde(r.pasifRenk, 0.28);

    Widget nokta(Color c, String s) => Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 4),
          Text(s, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(10), fontWeight: FontWeight.w600)),
        ]);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _baslik(r, "BU RAMAZAN"),
            const Spacer(),
            Text.rich(
              TextSpan(children: [
                TextSpan(text: "$tutulan", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900)),
                TextSpan(text: "/$gecen gün oruç  •  "),
                TextSpan(text: "$teravih", style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.w900)),
                const TextSpan(text: " teravih"),
              ]),
              style: TextStyle(color: r.yaziRengi, fontSize: Responsive.sp(12), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        SizedBox(height: Responsive.h(2)),
        Row(
          children: [
            for (int i = 0; i < gunler.length; i++) ...[
              if (i > 0) const SizedBox(width: 2),
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Bugün ve geçmiş günler sonradan işaretlenebilir (unutulan günler için)
                  onTap: gunler[i].compareTo(bugun) <= 0 ? () => _gunDegistir(p, gunler[i], i + 1) : null,
                  child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Container(
                  height: gunler[i] == bugun ? 14 : 10,
                  decoration: BoxDecoration(
                    color: p.orucGunleri.contains(gunler[i])
                        ? r.anaRenk
                        : gunler[i].compareTo(bugun) < 0
                            ? kacanRenk
                            : gelecek,
                    borderRadius: BorderRadius.circular(3),
                    border: gunler[i] == bugun ? Border.all(color: r.anaRenk, width: 1.5) : null,
                  ),
                ),
                ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: Responsive.h(2)),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            nokta(r.anaRenk, "Tutuldu"),
            if (kacan > 0) nokta(kacanRenk, "Tutulmadı ($kacan)"),
            nokta(gelecek, "Kalan günler"),
          ],
        ),
        SizedBox(height: Responsive.h(4)),
        Text("Unuttuğun bir günü işaretlemek için çubukta o güne dokun.",
            style: TextStyle(color: r.pasifRenk.withOpacity(0.8), fontSize: Responsive.sp(10))),
      ],
    );
  }
}

/// "Bugün" kutusu: dokununca işaretlenir/kaldırılır
class _Kutu extends StatelessWidget {
  final IconData ikon;
  final String ad;
  final String durum;
  final bool secili;
  final bool pasif;
  final double? ilerleme;
  final VoidCallback? onTap;
  const _Kutu({
    required this.ikon,
    required this.ad,
    required this.durum,
    required this.secili,
    this.pasif = false,
    this.ilerleme,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final yesil = const Color(0xFF2E9D57);
    final zemin = secili ? yesil : r.icYuzey;
    final yazi = secili ? Colors.white : (pasif ? r.pasifRenk : r.yaziRengi);
    return Material(
      color: zemin,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.fromLTRB(Responsive.w(10), Responsive.h(12), Responsive.w(10), Responsive.h(10)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(ikon, size: Responsive.w(20), color: secili ? Colors.white : (pasif ? r.pasifRenk : r.anaRenk)),
                  const Spacer(),
                  Icon(
                    secili ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    size: Responsive.w(18),
                    color: secili ? Colors.white : r.pasifRenk.withOpacity(pasif ? 0.4 : 0.8),
                  ),
                ],
              ),
              SizedBox(height: Responsive.h(10)),
              Text(ad, style: TextStyle(color: yazi, fontWeight: FontWeight.w900, fontSize: Responsive.sp(14))),
              SizedBox(height: Responsive.h(2)),
              Text(durum,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: secili ? Colors.white.withOpacity(0.9) : r.pasifRenk,
                      fontSize: Responsive.sp(11),
                      fontWeight: FontWeight.w600)),
              if (ilerleme != null && !secili) ...[
                SizedBox(height: Responsive.h(6)),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: ilerleme,
                    minHeight: 4,
                    color: r.anaRenk,
                    backgroundColor: r.anaRenk.withOpacity(0.15),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
