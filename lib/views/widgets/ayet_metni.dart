import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;

import '../../services/kuran_okuyucu.dart';

const Color _isik = Color(0xFFFFC107);

/// Kelime dizisini RTL çizer. Okunan kelimenin üzerinden sağdan sola kayan bir ışık geçer:
/// [ilerleme] 0 iken kelimenin sağ ucunda (ilk harf), 1 iken sol ucundadır (son harf). Böylece
/// "الٓمٓ" okunurken önce elif, sonra lâm, sonra mîm aydınlanır. Kelime tek parça çizildiği için
/// harflerin birbirine bağlanması bozulmaz. Okunmuş kelimeler hafif soluklaşır.
class IsikliKelimeler extends StatelessWidget {
  final List<String> kelimeler;
  final int? aktif; // 0'dan
  final double ilerleme;
  final TextStyle stil;
  final String sonEk;
  final TextAlign hiza;

  const IsikliKelimeler({
    super.key,
    required this.kelimeler,
    required this.aktif,
    this.ilerleme = 0.5,
    required this.stil,
    this.sonEk = '',
    this.hiza = TextAlign.right,
  });

  Color get _normal => stil.color ?? Colors.black;
  Color get _soluk => _normal.withOpacity(_normal.opacity * 0.55);

  /// [aktifGizli]: okunan kelime alt katmanda görünmez, üst katmanda ışıkla çizilir
  TextSpan _spanlar({bool aktifGizli = false}) {
    final soluk = stil.copyWith(color: _soluk);
    final gizli = stil.copyWith(color: Colors.transparent);
    return TextSpan(children: [
      for (int i = 0; i < kelimeler.length; i++) ...[
        TextSpan(
          text: kelimeler[i],
          style: (aktif != null && i < aktif!)
              ? soluk
              : (aktifGizli && i == aktif)
                  ? gizli
                  : stil,
        ),
        if (i < kelimeler.length - 1) TextSpan(text: ' ', style: stil),
      ],
      if (sonEk.isNotEmpty) TextSpan(text: sonEk, style: stil),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (aktif == null) {
      return Text.rich(_spanlar(), textAlign: hiza, textDirection: TextDirection.rtl);
    }
    final olcek = MediaQuery.textScalerOf(context);
    return LayoutBuilder(builder: (context, kisit) {
      // Okunan kelimenin ekrandaki yerini bul (ışığın gezeceği alan)
      var bas = 0;
      for (int i = 0; i < aktif!; i++) {
        bas += kelimeler[i].length + 1;
      }
      final son = bas + kelimeler[aktif!].length;
      final olcu = TextPainter(
        text: _spanlar(),
        textAlign: hiza,
        textDirection: TextDirection.rtl,
        textScaler: olcek,
      // minWidth da verilmeli: yoksa genişlik metne küçülür, sağa yaslama hesaba katılmaz ve ışık boşluğa düşer
      )..layout(minWidth: kisit.maxWidth, maxWidth: kisit.maxWidth);
      final kutular = olcu.getBoxesForSelection(TextSelection(baseOffset: bas, extentOffset: son));
      olcu.dispose();
      if (kutular.isEmpty) return Text.rich(_spanlar(), textAlign: hiza, textDirection: TextDirection.rtl);
      final alan = kutular.first.toRect();

      // Sağdan sola kayan ışık bandı. Yazıya doğrudan gradyan boyamak Impeller'da görünmüyor;
      // bu yüzden metnin üstüne yalnızca okunan kelimeden oluşan bir katman konur ve o katman
      // kayan altın bir maskeyle boyanır (harf bağlantıları bozulmaz).
      final c = ilerleme.clamp(0.0, 1.0);
      const yari = 0.3; // Bandın yarı genişliği (kelimeye oranla)
      // Işığın gerisi (okunmuş harfler) soluk, altı altın, önü (okunacak harfler) normal
      final bant = LinearGradient(
        begin: Alignment.centerRight, // 0 = kelimenin sağ ucu (ilk harf)
        end: Alignment.centerLeft,
        colors: [_soluk, _soluk, _isik, _isik, _normal, _normal],
        stops: [
          0,
          (c - yari).clamp(0.0, 1.0),
          (c - yari / 3).clamp(0.0, 1.0),
          (c + yari / 3).clamp(0.0, 1.0),
          (c + yari).clamp(0.0, 1.0),
          1,
        ],
      );

      return Stack(
        children: [
          // Tam genişlik: kısa ayetler kendi boyuna küçülüp sola kaymasın (ölçümle aynı düzen)
          SizedBox(
            width: kisit.maxWidth,
            child: Text.rich(_spanlar(aktifGizli: true),
                textAlign: hiza, textDirection: TextDirection.rtl, textScaler: olcek),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (_) => bant.createShader(alan),
                child: Text.rich(_maske(), textAlign: hiza, textDirection: TextDirection.rtl, textScaler: olcek),
              ),
            ),
          ),
        ],
      );
    });
  }

  /// Maske katmanı: aynı düzen, ama yalnızca okunan kelime görünür (hafif ışıltılı)
  TextSpan _maske() {
    final gizli = stil.copyWith(color: Colors.transparent, shadows: const []);
    final gorunur = stil.copyWith(color: Colors.white, shadows: const []);
    return TextSpan(children: [
      for (int i = 0; i < kelimeler.length; i++) ...[
        TextSpan(text: kelimeler[i], style: i == aktif ? gorunur : gizli),
        if (i < kelimeler.length - 1) TextSpan(text: ' ', style: gizli),
      ],
      if (sonEk.isNotEmpty) TextSpan(text: sonEk, style: gizli),
    ]);
  }
}

/// Ayetin Arapça metni; tilavette okunan harfin üzerinden ışık geçer.
/// Yalnızca kendi ayeti okunurken yeniden çizilir. Kelime verisi yoksa metin düz gösterilir.
class AyetMetni extends StatefulWidget {
  final KuranOkuyucu okuyucu;
  final int sure;
  final int ayet;
  final TextStyle stil;
  final TextAlign hiza;

  const AyetMetni({
    super.key,
    required this.okuyucu,
    required this.sure,
    required this.ayet,
    required this.stil,
    this.hiza = TextAlign.right,
  });

  @override
  State<AyetMetni> createState() => _AyetMetniState();
}

class _AyetMetniState extends State<AyetMetni> {
  bool _okunuyordu = false;

  bool get _okunuyor {
    final k = widget.okuyucu.konum.value;
    if (k == null) return false;
    final a = widget.okuyucu.ayetler[k.index];
    return a.sure == widget.sure && a.ayet == widget.ayet;
  }

  void _degisti() {
    final simdi = _okunuyor;
    // Sadece bu ayet okunuyorsa veya az önce okunuyorduysa (ışığı kaldırmak için) çiz
    if (simdi || _okunuyordu) setState(() {});
    _okunuyordu = simdi;
  }

  @override
  void initState() {
    super.initState();
    widget.okuyucu.konum.addListener(_degisti);
  }

  @override
  void didUpdateWidget(AyetMetni eski) {
    super.didUpdateWidget(eski);
    if (eski.okuyucu != widget.okuyucu) {
      eski.okuyucu.konum.removeListener(_degisti);
      widget.okuyucu.konum.addListener(_degisti);
    }
  }

  @override
  void dispose() {
    widget.okuyucu.konum.removeListener(_degisti);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final veri = widget.okuyucu.kelimeler(widget.sure, widget.ayet);
    final bitis = ' ${quran.getVerseEndSymbol(widget.ayet)}';
    if (veri == null || veri.kelimeler.isEmpty) {
      return Text(quran.getVerse(widget.sure, widget.ayet) + bitis,
          textAlign: widget.hiza, textDirection: TextDirection.rtl, style: widget.stil);
    }
    final k = _okunuyor ? widget.okuyucu.konum.value : null;
    return IsikliKelimeler(
      kelimeler: veri.kelimeler,
      aktif: k == null ? null : k.kelime - 1,
      ilerleme: k?.ilerleme ?? 0,
      stil: widget.stil,
      sonEk: bitis,
      hiza: widget.hiza,
    );
  }
}
