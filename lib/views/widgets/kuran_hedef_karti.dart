import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../services/kuran_hedefi.dart';

/// Kur'an ekranının üstündeki günlük okuma hedefi kartı
class KuranHedefKarti extends StatefulWidget {
  const KuranHedefKarti({super.key});

  @override
  State<KuranHedefKarti> createState() => _KuranHedefKartiState();
}

class _KuranHedefKartiState extends State<KuranHedefKarti> {
  final h = KuranHedefi.ornek;

  @override
  void initState() {
    super.initState();
    h.yukle();
  }

  Future<void> _hedefSec(AppThemeColors r) async {
    final secilen = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: r.arkaPlanRengi,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (c) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Günlük okuma hedefi",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w900, fontSize: 17)),
              const SizedBox(height: 4),
              Text("Günde 20 sayfa okuyan, Kur'an'ı bir ayda hatmeder.",
                  textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk, fontSize: 12)),
              const SizedBox(height: 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final s in KuranHedefi.secenekler)
                    ChoiceChip(
                      label: Text(s == 20 ? "20 sayfa (1 cüz)" : "$s sayfa"),
                      selected: h.hedef == s,
                      showCheckmark: false,
                      selectedColor: r.anaRenk.withOpacity(0.18),
                      labelStyle: TextStyle(
                          color: h.hedef == s ? r.anaRenk : r.yaziRengi, fontWeight: FontWeight.bold),
                      onSelected: (_) => Navigator.pop(c, s),
                    ),
                ],
              ),
              if (h.hedef > 0)
                TextButton(
                  onPressed: () => Navigator.pop(c, 0),
                  child: Text("Hedefi kaldır", style: TextStyle(color: r.pasifRenk)),
                ),
            ],
          ),
        ),
      ),
    );
    if (secilen != null) await h.hedefAyarla(secilen);
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ListenableBuilder(
      listenable: h,
      builder: (context, _) {
        if (h.hedef == 0) {
          return Material(
            color: r.kartRengi,
            borderRadius: BorderRadius.circular(16),
            child: ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Icon(Icons.flag_rounded, color: r.anaRenk),
              title: Text("Günlük okuma hedefi koy", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
              subtitle: Text("Her gün birkaç sayfa; okudukların kendiliğinden sayılır",
                  style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
              trailing: Icon(Icons.chevron_right_rounded, color: r.pasifRenk),
              onTap: () => _hedefSec(r),
            ),
          );
        }
        final renk = h.tamamlandi ? const Color(0xFF2E9D57) : r.anaRenk;
        return Container(
          padding: EdgeInsets.all(Responsive.w(14)),
          decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              SizedBox(
                width: Responsive.w(52),
                height: Responsive.w(52),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: CircularProgressIndicator(
                        value: h.oran,
                        strokeWidth: 5,
                        color: renk,
                        backgroundColor: renk.withOpacity(0.15),
                      ),
                    ),
                    h.tamamlandi
                        ? Icon(Icons.check_rounded, color: renk)
                        : Text("${h.bugunOkunan}",
                            style: TextStyle(color: renk, fontWeight: FontWeight.w900, fontSize: Responsive.sp(16))),
                  ],
                ),
              ),
              SizedBox(width: Responsive.w(12)),
              Expanded(
                child: GestureDetector(
                  onTap: () => _hedefSec(r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h.tamamlandi ? "Bugünkü hedef tamam, maşallah!" : "Bugün ${h.bugunOkunan} / ${h.hedef} sayfa",
                          style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(14))),
                      Text("Hedef: günde ${h.hedef} sayfa • değiştir",
                          style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(11))),
                    ],
                  ),
                ),
              ),
              // Mushaftan okunanlar
              Tooltip(
                message: "Mushaftan okuduğum sayfayı ekle",
                child: OutlinedButton(
                  onPressed: () => h.elleEkle(1),
                  onLongPress: h.bugunOkunan > 0 ? () => h.elleEkle(-1) : null,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: r.anaRenk,
                    side: BorderSide(color: r.anaRenk.withOpacity(0.4)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  child: const Text("+1 sayfa", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
