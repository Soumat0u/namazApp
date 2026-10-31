import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../models/user_profile.dart';
import '../providers/namaz_provider.dart';
import '../services/firebase_service.dart';
import '../services/hatim_servisi.dart';

const int _cuzXp = 15;

class HatimScreen extends StatelessWidget {
  const HatimScreen({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: r.arkaPlanRengi,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          centerTitle: true,
          title: Text("Hatim Takibi", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
          bottom: TabBar(
            labelColor: r.anaRenk,
            unselectedLabelColor: r.pasifRenk,
            indicatorColor: r.anaRenk,
            tabs: const [Tab(text: "Kişisel"), Tab(text: "Arkadaşlarla")],
          ),
        ),
        body: const TabBarView(children: [_KisiselHatim(), _OrtakHatimler()]),
      ),
    );
  }
}

/// 30 cüzlük kutucuk ızgarası (kişisel ve ortak hatimde ortak)
Widget _cuzIzgarasi({
  required AppThemeColors r,
  required Color Function(int cuz) renk,
  required Widget Function(int cuz) icerik,
  required void Function(int cuz) onTap,
}) {
  return GridView.builder(
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    itemCount: 30,
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 5,
      mainAxisSpacing: Responsive.w(8),
      crossAxisSpacing: Responsive.w(8),
    ),
    itemBuilder: (_, i) => InkWell(
      onTap: () => onTap(i + 1),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: renk(i + 1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: r.pasifRenk.withOpacity(0.15)),
        ),
        alignment: Alignment.center,
        child: icerik(i + 1),
      ),
    ),
  );
}

// ───────────────────────── Kişisel ─────────────────────────

class _KisiselHatim extends StatefulWidget {
  const _KisiselHatim();
  @override
  State<_KisiselHatim> createState() => _KisiselHatimState();
}

class _KisiselHatimState extends State<_KisiselHatim> {
  Set<int> _okunan = {};
  int _hatimSayisi = 0;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((p) {
      if (!mounted) return;
      setState(() {
        _okunan = (p.getStringList('hatim_cuzler') ?? []).map(int.parse).toSet();
        _hatimSayisi = p.getInt('hatim_sayisi') ?? 0;
      });
    });
  }

  Future<void> _kaydet() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList('hatim_cuzler', _okunan.map((c) => '$c').toList());
    await p.setInt('hatim_sayisi', _hatimSayisi);
  }

  Future<void> _degistir(int cuz) async {
    final provider = context.read<NamazProvider>();
    final okundu = !_okunan.contains(cuz);
    setState(() => okundu ? _okunan.add(cuz) : _okunan.remove(cuz));
    await provider.xpEkle(okundu ? _cuzXp : -_cuzXp);
    if (_okunan.length == 30) {
      setState(() {
        _hatimSayisi++;
        _okunan = {};
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Hatim tamamlandı 🤲"),
            content: Text("Allah kabul etsin. Bu senin $_hatimSayisi. hatmin. Yeni hatme başlayabilirsin."),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Âmin"))],
          ),
        );
      }
    }
    await _kaydet();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return ListView(
      padding: EdgeInsets.all(Responsive.w(16)),
      children: [
        Container(
          padding: EdgeInsets.all(Responsive.w(16)),
          decoration: BoxDecoration(color: r.kartRengi, borderRadius: BorderRadius.circular(16)),
          child: Row(
            children: [
              SizedBox(
                width: Responsive.w(56),
                height: Responsive.w(56),
                child: CircularProgressIndicator(
                  value: _okunan.length / 30,
                  strokeWidth: 6,
                  backgroundColor: r.pasifRenk.withOpacity(0.15),
                  color: r.anaRenk,
                ),
              ),
              SizedBox(width: Responsive.w(16)),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("${_okunan.length} / 30 cüz",
                        style: TextStyle(fontWeight: FontWeight.w900, fontSize: Responsive.sp(18), color: r.yaziRengi)),
                    Text("Tamamlanan hatim: $_hatimSayisi",
                        style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: Responsive.h(16)),
        Text("Okuduğun cüze dokun (her cüz +$_cuzXp XP)",
            style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12))),
        SizedBox(height: Responsive.h(10)),
        _cuzIzgarasi(
          r: r,
          renk: (c) => _okunan.contains(c) ? r.anaRenk : r.kartRengi,
          icerik: (c) => Text("$c",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _okunan.contains(c) ? Colors.white : r.yaziRengi,
              )),
          onTap: _degistir,
        ),
      ],
    );
  }
}

// ───────────────────────── Ortak ─────────────────────────

class _OrtakHatimler extends StatelessWidget {
  const _OrtakHatimler();

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final uid = context.read<NamazProvider>().currentUid;
    if (uid == null) return const Center(child: Text("Ortak hatim için giriş yapmalısın."));

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: r.anaRenk,
        onPressed: () => _hatimOlustur(context, uid),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Yeni Hatim", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: StreamBuilder<List<OrtakHatim>>(
        stream: HatimServisi().hatimlerim(uid),
        builder: (context, snap) {
          if (!snap.hasData) return Center(child: CircularProgressIndicator(color: r.anaRenk));
          final liste = snap.data!;
          if (liste.isEmpty) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(Responsive.w(32)),
                child: Text(
                  "Arkadaşlarınla birlikte hatim başlat. Herkes bir cüz üstlenir, birlikte tamamlarsınız.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: r.pasifRenk),
                ),
              ),
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(Responsive.w(16), Responsive.w(16), Responsive.w(16), 90),
            children: [
              for (final h in liste)
                Card(
                  color: r.kartRengi,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: ListTile(
                    title: Text(h.ad, style: TextStyle(fontWeight: FontWeight.bold, color: r.yaziRengi)),
                    subtitle: Text(
                      h.tamamlandi
                          ? "Tamamlandı 🤲 • ${h.uyeler.length} kişi"
                          : "${h.bitenCuz}/30 okundu • ${30 - h.alinanCuz} cüz boşta • ${h.uyeler.length} kişi",
                      style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12)),
                    ),
                    trailing: Icon(Icons.chevron_right_rounded, color: r.pasifRenk),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => _OrtakHatimDetay(hatimId: h.id)),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _hatimOlustur(BuildContext context, String uid) async {
    final r = context.renklerOku; // Düğme olayında: dinlemeden oku
    final messenger = ScaffoldMessenger.of(context);
    final adController = TextEditingController(text: "Arkadaşlar Hatmi");
    final secili = <String>{};
    final profil = await FirebaseService().getUserProfileFuture(uid);
    final arkadaslar = profil == null || profil.friends.isEmpty
        ? <UserProfile>[]
        : await FirebaseService().getFriendsProfilesStream(profil.friends).first;
    if (!context.mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: r.arkaPlanRengi,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setState) => Padding(
          padding: EdgeInsets.only(
              left: 20, right: 20, top: 20, bottom: MediaQuery.of(sheet).viewInsets.bottom + 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text("Yeni Ortak Hatim",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: r.yaziRengi)),
              const SizedBox(height: 12),
              TextField(
                controller: adController,
                decoration: InputDecoration(
                  labelText: "Hatim adı",
                  filled: true,
                  fillColor: r.kartRengi,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              Text("Davet edilecek arkadaşlar", style: TextStyle(color: r.pasifRenk)),
              if (arkadaslar.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text("Henüz arkadaşın yok. Tek başına da başlayabilirsin.",
                      style: TextStyle(color: r.pasifRenk, fontSize: 12)),
                ),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 260),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final a in arkadaslar)
                      CheckboxListTile(
                        value: secili.contains(a.uid),
                        activeColor: r.anaRenk,
                        title: Text(a.displayName, style: TextStyle(color: r.yaziRengi)),
                        subtitle: Text("@${a.username}", style: TextStyle(color: r.pasifRenk, fontSize: 12)),
                        onChanged: (v) => setState(() => v! ? secili.add(a.uid) : secili.remove(a.uid)),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: r.anaRenk,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () async {
                  final ad = adController.text.trim().isEmpty ? "Arkadaşlar Hatmi" : adController.text.trim();
                  Navigator.pop(sheet);
                  final hata = await HatimServisi().olustur(uid: uid, ad: ad, davetliler: secili.toList());
                  messenger.showSnackBar(SnackBar(content: Text(hata ?? "Hatim başlatıldı. Cüzünü seçmeyi unutma!")));
                },
                child: const Text("Başlat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OrtakHatimDetay extends StatelessWidget {
  final String hatimId;
  const _OrtakHatimDetay({required this.hatimId});

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final provider = context.read<NamazProvider>();
    final uid = provider.currentUid!;
    final servis = HatimServisi();

    return StreamBuilder<List<OrtakHatim>>(
      stream: servis.hatimlerim(uid),
      builder: (context, snap) {
        final hatim = snap.data?.where((h) => h.id == hatimId).firstOrNull;
        return Scaffold(
          backgroundColor: r.arkaPlanRengi,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: Text(hatim?.ad ?? "Hatim", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
            actions: [
              if (hatim != null && hatim.olusturan == uid)
                IconButton(
                  tooltip: "Hatmi sil",
                  icon: Icon(Icons.delete_outline_rounded, color: r.kirmizi),
                  onPressed: () async {
                    Navigator.pop(context);
                    await servis.sil(hatimId);
                  },
                ),
            ],
          ),
          body: hatim == null
              ? Center(child: CircularProgressIndicator(color: r.anaRenk))
              : ListView(
                  padding: EdgeInsets.all(Responsive.w(16)),
                  children: [
                    LinearProgressIndicator(
                      value: hatim.bitenCuz / 30,
                      minHeight: 8,
                      backgroundColor: r.pasifRenk.withOpacity(0.15),
                      color: r.anaRenk,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    SizedBox(height: Responsive.h(8)),
                    Text(
                      hatim.tamamlandi
                          ? "Hatim tamamlandı. Allah kabul etsin 🤲"
                          : "${hatim.bitenCuz}/30 cüz okundu. Boş cüze dokunup üstlenebilirsin.",
                      style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(12)),
                    ),
                    SizedBox(height: Responsive.h(14)),
                    _cuzIzgarasi(
                      r: r,
                      renk: (c) {
                        final d = hatim.cuzler[c]!;
                        if (d.bitti) return r.anaRenk;
                        if (d.uid == uid) return r.anaRenk.withOpacity(0.25);
                        if (!d.bos) return r.pasifRenk.withOpacity(0.2);
                        return r.kartRengi;
                      },
                      icerik: (c) {
                        final d = hatim.cuzler[c]!;
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text("$c",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, color: d.bitti ? Colors.white : r.yaziRengi)),
                            if (!d.bos)
                              Text(
                                d.uid == uid ? "Sen" : d.ad.split(' ').first,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: Responsive.sp(9), color: d.bitti ? Colors.white70 : r.pasifRenk),
                              ),
                          ],
                        );
                      },
                      onTap: (c) => _cuzaDokun(context, hatim, c, uid, provider),
                    ),
                    SizedBox(height: Responsive.h(12)),
                    Row(
                      children: [
                        _lejant(r, r.kartRengi, "Boş"),
                        _lejant(r, r.anaRenk.withOpacity(0.25), "Senin"),
                        _lejant(r, r.pasifRenk.withOpacity(0.2), "Başkasının"),
                        _lejant(r, r.anaRenk, "Okundu"),
                      ],
                    ),
                  ],
                ),
        );
      },
    );
  }

  Widget _lejant(AppThemeColors r, Color renk, String ad) => Expanded(
        child: Row(
          children: [
            Container(width: 12, height: 12, decoration: BoxDecoration(color: renk, borderRadius: BorderRadius.circular(3))),
            const SizedBox(width: 4),
            Flexible(child: Text(ad, style: TextStyle(color: r.pasifRenk, fontSize: 11))),
          ],
        ),
      );

  Future<void> _cuzaDokun(BuildContext context, OrtakHatim hatim, int cuz, String uid, NamazProvider provider) async {
    final d = hatim.cuzler[cuz]!;
    final messenger = ScaffoldMessenger.of(context);
    final servis = HatimServisi();
    if (d.bos) {
      final hata = await servis.cuzAl(hatim.id, cuz, uid, provider.currentUsername);
      messenger.showSnackBar(SnackBar(content: Text(hata ?? "$cuz. cüzü üstlendin.")));
    } else if (d.uid == uid) {
      if (!context.mounted) return;
      showModalBottomSheet(
        context: context,
        builder: (sheet) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(d.bitti ? Icons.undo_rounded : Icons.check_circle_rounded),
                title: Text(d.bitti ? "Okunmadı olarak işaretle" : "Okudum"),
                onTap: () async {
                  Navigator.pop(sheet);
                  await servis.cuzBitir(hatim.id, cuz, !d.bitti);
                  await provider.xpEkle(d.bitti ? -_cuzXp : _cuzXp);
                },
              ),
              if (!d.bitti)
                ListTile(
                  leading: const Icon(Icons.person_remove_rounded),
                  title: const Text("Cüzü bırak"),
                  onTap: () {
                    Navigator.pop(sheet);
                    servis.cuzBirak(hatim.id, cuz);
                  },
                ),
            ],
          ),
        ),
      );
    } else {
      messenger.showSnackBar(SnackBar(
        content: Text("$cuz. cüz ${d.ad} arkadaşımızda${d.bitti ? ', okundu' : ''}."),
      ));
    }
  }
}
