import '../core/utils/bildirim.dart';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/utils/responsive.dart';
import '../core/theme/app_theme.dart';
import '../providers/namaz_provider.dart';
import '../providers/theme_provider.dart';

/// Zikir çekerken verilecek geri bildirim: telefonun zil modundan bağımsız,
/// uygulama içinden seçilir
enum ZikirGeriBildirim { titresim, ses, ikisi, kapali }

class ZikirmatikScreen extends StatefulWidget {
  const ZikirmatikScreen({super.key});

  @override
  State<ZikirmatikScreen> createState() => _ZikirmatikScreenState();
}

class _ZikirmatikScreenState extends State<ZikirmatikScreen> with TickerProviderStateMixin {
  static const _modAnahtari = 'zikirGeriBildirim';

  final AudioPlayer _tikPlayer = AudioPlayer();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _canVibrate = false;
  ZikirGeriBildirim _mod = ZikirGeriBildirim.titresim;

  bool _basili = false;
  // Her dokunuşta: dışa yayılan halka ve sayının hafifçe büyüyüp yerine oturması
  late final AnimationController _dalga =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 550));
  late final AnimationController _sayiPop =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  // İçeriğin üstünde beliren bildirimler (yerleşimi itmez)
  late final AnimationController _xpCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _hedefCtrl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  bool get _sesAcik => _mod == ZikirGeriBildirim.ses || _mod == ZikirGeriBildirim.ikisi;
  bool get _titresimAcik =>
      _canVibrate && (_mod == ZikirGeriBildirim.titresim || _mod == ZikirGeriBildirim.ikisi);

  @override
  void initState() {
    super.initState();
    _hazirla();
  }

  Future<void> _hazirla() async {
    // Kısa tık sesi için düşük gecikmeli oynatıcı; arka plandaki müziği durdurmaz
    final karisik = AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build();
    try {
      await _tikPlayer.setPlayerMode(PlayerMode.lowLatency);
      await _tikPlayer.setAudioContext(karisik);
      await _tikPlayer.setReleaseMode(ReleaseMode.stop);
      await _tikPlayer.setSource(AssetSource('sounds/tik.wav'));
      await _audioPlayer.setAudioContext(karisik);
    } catch (_) {}
    final titresim = await Vibration.hasVibrator();
    final prefs = await SharedPreferences.getInstance();
    final kayitli = prefs.getInt(_modAnahtari);
    if (!mounted) return;
    setState(() {
      _canVibrate = titresim;
      if (kayitli != null && kayitli >= 0 && kayitli < ZikirGeriBildirim.values.length) {
        _mod = ZikirGeriBildirim.values[kayitli];
      }
    });
  }

  Future<void> _modSec(ZikirGeriBildirim mod) async {
    setState(() => _mod = mod);
    _dokunusGeriBildirimi(); // Seçilen modu hemen hissettir
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_modAnahtari, mod.index);
  }

  @override
  void dispose() {
    _tikPlayer.dispose();
    _audioPlayer.dispose();
    _dalga.dispose();
    _sayiPop.dispose();
    _xpCtrl.dispose();
    _hedefCtrl.dispose();
    super.dispose();
  }

  void _dokunusGeriBildirimi() {
    if (_titresimAcik) Vibration.vibrate(duration: 40);
    if (_sesAcik) {
      _tikPlayer.stop().then((_) => _tikPlayer.resume()).catchError((_) {});
    }
  }

  void _zikirCek(NamazProvider provider) {
    final hedefeUlasti = provider.zikirSayaci + 1 == provider.zikirHedefi;
    final xpGelecek = (provider.zikirSayaci + 1) % 10 == 0;
    provider.zikirArtir();

    _dalga.forward(from: 0);
    _sayiPop.forward(from: 0);
    if (xpGelecek) _xpCtrl.forward(from: 0);

    if (hedefeUlasti) {
      if (_sesAcik) _audioPlayer.play(AssetSource('sounds/success.mp3'));
      if (_titresimAcik) Vibration.vibrate(pattern: [0, 120, 90, 120, 90, 300]);
      _hedefCtrl.forward(from: 0);
    } else {
      _dokunusGeriBildirimi();
    }
  }

  void _showOzelHedefDialog(BuildContext context, NamazProvider provider) {
    final TextEditingController controller = TextEditingController();
    final tema = context.read<ThemeProvider>().aktifTema;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: tema.kartRengi,
        title: Text("Özel Hedef", style: TextStyle(color: tema.yaziRengi)),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: TextStyle(color: tema.yaziRengi),
          decoration: InputDecoration(
            hintText: "Örn: 500",
            hintStyle: TextStyle(color: tema.yaziRengi.withOpacity(0.5)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: tema.anaRenk)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: tema.anaRenk)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("İptal", style: TextStyle(color: tema.pasifRenk)),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                provider.zikirHedefBelirle(val);
                Navigator.pop(ctx);
              }
            },
            child: Text("Kaydet", style: TextStyle(color: tema.anaRenk)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();
    final tema = context.watch<ThemeProvider>().aktifTema;

    final progress = provider.zikirHedefi > 0
        ? (provider.zikirSayaci / provider.zikirHedefi).clamp(0.0, 1.0)
        : 0.0;
    final tamam = provider.zikirHedefi > 0 && provider.zikirSayaci >= provider.zikirHedefi;
    const yesil = Color(0xFF2E9D57);
    final halkaRengi = tamam ? yesil : tema.anaRenk;

    return Scaffold(
      backgroundColor: tema.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: tema.yaziRengi),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Zikirmatik",
          style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(22)),
        ),
        actions: [
          IconButton(
            tooltip: 'Sıfırlamak için basılı tutun',
            icon: Icon(Icons.refresh_rounded, color: tema.yaziRengi),
            onPressed: () {
              Bildirim.snackBar(
                SnackBar(
                  content: const Text("Sıfırlamak için ikona basılı tutun."),
                  backgroundColor: tema.pasifRenk,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
            onLongPress: () {
              if (_titresimAcik) Vibration.vibrate(duration: 300);
              provider.zikirSifirla();
              Bildirim.snackBar(
                SnackBar(
                  content: const Text("Sayaç sıfırlandı."),
                  backgroundColor: tema.anaRenk,
                  duration: const Duration(seconds: 1),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                SizedBox(height: Responsive.h(12)),
                // Hedef Butonları
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                  child: Row(
                    children: [
                      _buildHedefBtn(tema, provider, 33),
                      _buildHedefBtn(tema, provider, 99),
                      _buildHedefBtn(tema, provider, 100),
                      _buildHedefBtn(tema, provider, 1000),
                      _buildOzelHedefBtn(tema, provider),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: _sayacButonu(tema, provider, progress, halkaRengi, tamam),
                  ),
                ),
                _modSecici(tema),
                SizedBox(height: Responsive.h(14)),
                Padding(
                  padding: EdgeInsets.only(bottom: Responsive.h(28)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.star_rounded, color: Colors.amber, size: Responsive.w(18)),
                      SizedBox(width: Responsive.w(4)),
                      Text(
                        "${provider.zikirXpKazanilan} XP",
                        style: TextStyle(
                            color: tema.yaziRengi, fontWeight: FontWeight.w800, fontSize: Responsive.sp(14)),
                      ),
                      Text(
                        "  ·  Sonraki XP'ye ${10 - (provider.zikirSayaci % 10)} zikir",
                        style: TextStyle(color: tema.yaziRengi.withOpacity(0.6), fontSize: Responsive.sp(14)),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // +1 XP: sayacın üstünden yükselip kaybolur, hiçbir şeyi itmez
            Positioned(
              top: Responsive.h(64),
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _xpCtrl,
                  builder: (context, child) {
                    final t = _xpCtrl.value;
                    if (t == 0 || t == 1) return const SizedBox.shrink();
                    final gorunurluk = t < 0.15 ? t / 0.15 : (t > 0.7 ? (1 - t) / 0.3 : 1.0);
                    final olcek = t < 0.15 ? 0.6 + 0.4 * Curves.easeOutBack.transform(t / 0.15) : 1.0;
                    return Opacity(
                      opacity: gorunurluk.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, -Responsive.h(24) * t),
                        child: Transform.scale(scale: olcek, child: child),
                      ),
                    );
                  },
                  child: Center(
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(8)),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade700,
                        borderRadius: BorderRadius.circular(Responsive.w(20)),
                        boxShadow: [
                          BoxShadow(color: Colors.amber.withOpacity(0.45), blurRadius: 14, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, color: Colors.white, size: Responsive.w(18)),
                          SizedBox(width: Responsive.w(6)),
                          Text("+1 XP kazandın",
                              style: TextStyle(
                                  color: Colors.white, fontWeight: FontWeight.w900, fontSize: Responsive.sp(14))),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Hedef tamamlandı: ekranın üstünde kart olarak belirir
            Positioned(
              top: Responsive.h(8),
              left: Responsive.w(24),
              right: Responsive.w(24),
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _hedefCtrl,
                  builder: (context, child) {
                    final t = _hedefCtrl.value;
                    if (t == 0 || t == 1) return const SizedBox.shrink();
                    final giris = Curves.easeOutBack.transform((t / 0.15).clamp(0.0, 1.0));
                    final cikis = t > 0.85 ? (1 - t) / 0.15 : 1.0;
                    return Opacity(
                      opacity: (giris.clamp(0.0, 1.0) * cikis).clamp(0.0, 1.0),
                      child: Transform.translate(offset: Offset(0, -20 * (1 - giris)), child: child),
                    );
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(18), vertical: Responsive.h(14)),
                    decoration: BoxDecoration(
                      color: yesil,
                      borderRadius: BorderRadius.circular(Responsive.w(18)),
                      boxShadow: [BoxShadow(color: yesil.withOpacity(0.4), blurRadius: 18, offset: const Offset(0, 6))],
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle_rounded, color: Colors.white, size: Responsive.w(28)),
                        SizedBox(width: Responsive.w(12)),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("Hedef tamamlandı",
                                  style: TextStyle(
                                      color: Colors.white, fontWeight: FontWeight.w900, fontSize: Responsive.sp(16))),
                              Text("${provider.zikirHedefi} zikir. Allah kabul etsin.",
                                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: Responsive.sp(13))),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sayacButonu(AppThemeData tema, NamazProvider provider, double progress, Color halkaRengi, bool tamam) {
    final boyut = Responsive.w(280);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Sayım parmak değdiği an yapılır: hızlı çekerken gecikme hissedilmez
      onTapDown: (_) {
        setState(() => _basili = true);
        _zikirCek(provider);
      },
      onTapUp: (_) => setState(() => _basili = false),
      onTapCancel: () => setState(() => _basili = false),
      child: SizedBox(
        width: boyut * 1.25,
        height: boyut * 1.25,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Dışa yayılan dalga
            AnimatedBuilder(
              animation: _dalga,
              builder: (context, _) {
                final t = Curves.easeOut.transform(_dalga.value);
                if (_dalga.value == 0 || _dalga.value == 1) return const SizedBox.shrink();
                return Container(
                  width: boyut * (1 + 0.22 * t),
                  height: boyut * (1 + 0.22 * t),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: halkaRengi.withOpacity(0.45 * (1 - t)), width: 3 + 5 * (1 - t)),
                  ),
                );
              },
            ),
            AnimatedScale(
              scale: _basili ? 0.94 : 1.0,
              duration: Duration(milliseconds: _basili ? 60 : 160),
              curve: _basili ? Curves.easeOut : Curves.easeOutBack,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                width: boyut,
                height: boyut,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _basili ? Color.alphaBlend(halkaRengi.withOpacity(0.08), tema.kartRengi) : tema.kartRengi,
                  boxShadow: [
                    BoxShadow(
                      color: halkaRengi.withOpacity(_basili ? 0.30 : 0.15),
                      blurRadius: _basili ? 18 : 30,
                      spreadRadius: _basili ? 4 : 10,
                    ),
                  ],
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: Responsive.w(250),
                      height: Responsive.w(250),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: progress),
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                        builder: (context, deger, _) => CircularProgressIndicator(
                          value: deger,
                          strokeWidth: Responsive.w(12),
                          strokeCap: StrokeCap.round,
                          backgroundColor: halkaRengi.withOpacity(0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(halkaRengi),
                        ),
                      ),
                    ),
                    Container(
                      width: Responsive.w(210),
                      height: Responsive.w(210),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [halkaRengi.withOpacity(_basili ? 0.12 : 0.05), halkaRengi.withOpacity(_basili ? 0.28 : 0.15)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedBuilder(
                          animation: _sayiPop,
                          builder: (context, child) {
                            final t = _sayiPop.value;
                            // 1 → 1.12 → 1: kısa bir "pıt"
                            final olcek = 1 + 0.12 * (t < 0.4 ? t / 0.4 : (1 - t) / 0.6);
                            return Transform.scale(scale: _sayiPop.isAnimating ? olcek : 1, child: child);
                          },
                          child: Text(
                            "${provider.zikirSayaci}",
                            style: TextStyle(
                              fontSize: Responsive.sp(60),
                              fontWeight: FontWeight.bold,
                              color: tamam ? halkaRengi : tema.yaziRengi,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (tamam) ...[
                              Icon(Icons.check_rounded, color: halkaRengi, size: Responsive.w(18)),
                              SizedBox(width: Responsive.w(4)),
                            ],
                            Text(
                              "Hedef: ${provider.zikirHedefi}",
                              style: TextStyle(
                                fontSize: Responsive.sp(16),
                                color: tamam ? halkaRengi : tema.pasifRenk,
                                fontWeight: tamam ? FontWeight.w700 : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Uygulama içi geri bildirim seçimi: telefonun sessiz/titreşim modundan bağımsız
  Widget _modSecici(AppThemeData tema) {
    Widget secenek(ZikirGeriBildirim mod, IconData ikon, String ad) {
      final secili = _mod == mod;
      return Expanded(
        child: GestureDetector(
          onTap: () => _modSec(mod),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: EdgeInsets.symmetric(vertical: Responsive.h(9)),
            decoration: BoxDecoration(
              color: secili ? tema.anaRenk : Colors.transparent,
              borderRadius: BorderRadius.circular(Responsive.w(14)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(ikon, size: Responsive.w(20), color: secili ? Colors.white : tema.pasifRenk),
                SizedBox(height: Responsive.h(2)),
                Text(ad,
                    style: TextStyle(
                        fontSize: Responsive.sp(11),
                        fontWeight: FontWeight.w700,
                        color: secili ? Colors.white : tema.pasifRenk)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: Responsive.w(24)),
      padding: EdgeInsets.all(Responsive.w(4)),
      decoration: BoxDecoration(
        color: tema.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(18)),
        border: Border.all(color: tema.anaRenk.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          secenek(ZikirGeriBildirim.titresim, Icons.vibration_rounded, "Titreşim"),
          secenek(ZikirGeriBildirim.ses, Icons.volume_up_rounded, "Ses"),
          secenek(ZikirGeriBildirim.ikisi, Icons.graphic_eq_rounded, "İkisi"),
          secenek(ZikirGeriBildirim.kapali, Icons.do_not_disturb_on_outlined, "Kapalı"),
        ],
      ),
    );
  }

  Widget _buildHedefBtn(AppThemeData tema, NamazProvider provider, int hedef) {
    bool isSelected = provider.zikirHedefi == hedef;
    return GestureDetector(
      onTap: () => provider.zikirHedefBelirle(hedef),
      child: Container(
        margin: EdgeInsets.only(right: Responsive.w(10)),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(10)),
        decoration: BoxDecoration(
          color: isSelected ? tema.anaRenk : tema.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(color: isSelected ? tema.anaRenk : tema.anaRenk.withOpacity(0.3)),
        ),
        child: Text(
          "$hedef",
          style: TextStyle(
            color: isSelected ? Colors.white : tema.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(14),
          ),
        ),
      ),
    );
  }

  Widget _buildOzelHedefBtn(AppThemeData tema, NamazProvider provider) {
    bool isOzelSecili = ![33, 99, 100, 1000].contains(provider.zikirHedefi);
    return GestureDetector(
      onTap: () => _showOzelHedefDialog(context, provider),
      child: Container(
        margin: EdgeInsets.only(right: Responsive.w(10)),
        padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(10)),
        decoration: BoxDecoration(
          color: isOzelSecili ? tema.anaRenk : tema.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(20)),
          border: Border.all(color: isOzelSecili ? tema.anaRenk : tema.anaRenk.withOpacity(0.3)),
        ),
        child: Text(
          isOzelSecili ? "${provider.zikirHedefi}" : "Özel",
          style: TextStyle(
            color: isOzelSecili ? Colors.white : tema.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(14),
          ),
        ),
      ),
    );
  }
}
