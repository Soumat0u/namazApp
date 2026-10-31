import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';

/// Zekât hesabı (Diyanet: nisap 80,18 gram altın, oran %2,5)
class ZekatHesabi {
  static const double nisapGram = 80.18;
  static const double oran = 0.025;

  final double altinGram, altinFiyati, nakit, doviz, ticariMal, alacak, borc;

  const ZekatHesabi({
    this.altinGram = 0,
    this.altinFiyati = 0,
    this.nakit = 0,
    this.doviz = 0,
    this.ticariMal = 0,
    this.alacak = 0,
    this.borc = 0,
  });

  double get netVarlik => altinGram * altinFiyati + nakit + doviz + ticariMal + alacak - borc;
  double get nisapTutari => nisapGram * altinFiyati;
  bool get zekatGerekli => altinFiyati > 0 && netVarlik >= nisapTutari;
  double get zekat => zekatGerekli ? netVarlik * oran : 0;
}

class ZekatScreen extends StatefulWidget {
  const ZekatScreen({super.key});

  @override
  State<ZekatScreen> createState() => _ZekatScreenState();
}

class _ZekatScreenState extends State<ZekatScreen> {
  final _alanlar = {
    'altinFiyati': TextEditingController(),
    'altinGram': TextEditingController(),
    'nakit': TextEditingController(),
    'doviz': TextEditingController(),
    'ticariMal': TextEditingController(),
    'alacak': TextEditingController(),
    'borc': TextEditingController(),
  };
  final _tl = NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2);

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      final fiyat = p.getDouble('gram_altin_fiyati');
      if (fiyat != null && mounted) setState(() => _alanlar['altinFiyati']!.text = fiyat.toStringAsFixed(0));
    });
  }

  @override
  void dispose() {
    for (final c in _alanlar.values) {
      c.dispose();
    }
    super.dispose();
  }

  double _deger(String alan) => double.tryParse(_alanlar[alan]!.text.replaceAll('.', '').replaceAll(',', '.')) ?? 0;

  ZekatHesabi get _hesap => ZekatHesabi(
        altinFiyati: _deger('altinFiyati'),
        altinGram: _deger('altinGram'),
        nakit: _deger('nakit'),
        doviz: _deger('doviz'),
        ticariMal: _deger('ticariMal'),
        alacak: _deger('alacak'),
        borc: _deger('borc'),
      );

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    final h = _hesap;

    Widget alan(String anahtar, String etiket, {String sonek = '₺'}) => Padding(
          padding: EdgeInsets.only(bottom: Responsive.h(10)),
          child: TextField(
            controller: _alanlar[anahtar],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
            onChanged: (_) {
              setState(() {});
              if (anahtar == 'altinFiyati') {
                SharedPreferences.getInstance().then((p) => p.setDouble('gram_altin_fiyati', _deger('altinFiyati')));
              }
            },
            style: TextStyle(color: r.yaziRengi),
            decoration: InputDecoration(
              labelText: etiket,
              suffixText: sonek,
              filled: true,
              fillColor: r.kartRengi,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            ),
          ),
        );

    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Zekât Hesaplayıcı", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: EdgeInsets.all(Responsive.w(16)),
        children: [
          alan('altinFiyati', 'Güncel gram altın fiyatı'),
          Divider(color: r.pasifRenk.withOpacity(0.2)),
          alan('altinGram', 'Altın / takı', sonek: 'gram'),
          alan('nakit', 'Nakit ve banka hesapları'),
          alan('doviz', 'Döviz (TL karşılığı)'),
          alan('ticariMal', 'Ticari mallar'),
          alan('alacak', 'Tahsili umulan alacaklar'),
          alan('borc', 'Borçlar (düşülür)'),
          SizedBox(height: Responsive.h(6)),
          Container(
            padding: EdgeInsets.all(Responsive.w(16)),
            decoration: BoxDecoration(
              color: h.zekatGerekli ? r.anaRenk.withOpacity(0.12) : r.kartRengi,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: r.anaRenk.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _satir(r, "Net varlık", _tl.format(h.netVarlik)),
                _satir(r, "Nisap (80,18 gr altın)", h.altinFiyati > 0 ? _tl.format(h.nisapTutari) : "Altın fiyatını girin"),
                Divider(color: r.pasifRenk.withOpacity(0.2)),
                Text(
                  h.altinFiyati <= 0
                      ? "Hesap için gram altın fiyatını girin."
                      : h.zekatGerekli
                          ? "Vermen gereken zekât: ${_tl.format(h.zekat)}"
                          : "Varlığın nisap miktarının altında; zekât gerekmiyor.",
                  style: TextStyle(fontWeight: FontWeight.w900, color: r.yaziRengi, fontSize: Responsive.sp(16)),
                ),
              ],
            ),
          ),
          SizedBox(height: Responsive.h(12)),
          Text(
            "Zekât; temel ihtiyaçlar ve borçlar dışında, nisap miktarı mala sahip olup üzerinden bir kameri yıl geçen "
            "kişiye farzdır. Oran %2,5'tir. Bu hesap bilgi amaçlıdır; özel durumlar için bir din görevlisine danışın.",
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11), height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _satir(AppThemeColors r, String ad, String deger) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(ad, style: TextStyle(color: r.pasifRenk))),
            Text(deger, style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
          ],
        ),
      );
}
