import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../providers/namaz_provider.dart';
import '../providers/theme_provider.dart';
import 'widgets/vakit_background.dart';

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final provider = context.watch<NamazProvider>();

    if (provider.isLoading && provider.vakitler == null) {
      return Center(
        child: CircularProgressIndicator(color: context.renkler.anaRenk),
      );
    }

    if (provider.hataMesaji.contains("çevrimdışı") &&
        provider.vakitler != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(provider.hataMesaji)));
        provider.hataMesaji = "";
      });
    }

    if (provider.vakitler == null && provider.hataMesaji.isNotEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
                child: Text(
                  provider.hataMesaji,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.renkler.yaziRengi,
                    fontSize: Responsive.sp(16),
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(20)),
              ElevatedButton(
                onPressed: () => context.read<NamazProvider>().konumVeApiIstegi(
                  kullaniciTetikledi: true,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.renkler.anaRenk,
                  foregroundColor: Colors.white,
                ),
                child: const Text("Konum İzni Ver / Tekrar Dene"),
              ),
              SizedBox(height: Responsive.h(30)),
              Text(
                "veya Manuel Şehir Seçin:",
                style: TextStyle(
                  color: context.renkler.yaziRengi,
                  fontSize: Responsive.sp(14),
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: Responsive.h(10)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(40)),
                child: DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.renkler.kartRengi,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  hint: const Text("Şehir Seç"),
                  items: [
                    "Adana", "Ankara", "Antalya", "Bursa", "Diyarbakır", 
                    "Erzurum", "Eskişehir", "Gaziantep", "İstanbul", "İzmir", 
                    "Kayseri", "Konya", "Mersin", "Samsun", "Trabzon", "Van"
                  ].map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      context.read<NamazProvider>().sehirVakitleriniGetir(newValue);
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SafeArea(
      left: false,
      right: false,
      child: RefreshIndicator(
        color: context.renkler.anaRenk,
        backgroundColor: context.renkler.kartRengi,
        onRefresh: () => context.read<NamazProvider>().konumVeApiIstegi(
          kullaniciTetikledi: true,
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Responsive.w(16),
                  Responsive.h(16),
                  Responsive.w(16),
                  0,
                ),
                child: _buildHeader(context, provider),
              ),
              SizedBox(height: Responsive.h(16)),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: Responsive.w(16)),
                child: _buildMainClock(context, provider),
              ),
              Padding(
                padding: EdgeInsets.all(Responsive.w(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildVakitGrid(context, provider),
                    SizedBox(height: Responsive.h(16)),
                    _buildPrayerButton(context, provider),
                    SizedBox(height: Responsive.h(10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _buildHeader(BuildContext context, NamazProvider provider) {
  final r = context.renkler;
  return Container(
    padding: EdgeInsets.all(Responsive.w(16)),
    decoration: _sikKutuDecoration(context),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                provider.ekranTarihi.isNotEmpty
                    ? provider.ekranTarihi.split(',')[0]
                    : "Pazartesi",
                style: TextStyle(
                  fontSize: Responsive.sp(18),
                  fontWeight: FontWeight.bold,
                  color: r.yaziRengi,
                ),
              ),
              Text(
                provider.ekranTarihi.contains(',')
                    ? provider.ekranTarihi.split(',')[1].trim()
                    : "10 Mart",
                style: TextStyle(
                  fontSize: Responsive.sp(13),
                  color: r.yaziRengi.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: Responsive.w(12),
            vertical: Responsive.h(8),
          ),
          decoration: BoxDecoration(
            color: r.anaRenk.withOpacity(0.15),
            borderRadius: BorderRadius.circular(Responsive.w(20)),
          ),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: r.anaRenk,
                size: Responsive.w(24),
              ),
              SizedBox(width: Responsive.w(4)),
              Text(
                "${provider.streakCount}",
                style: TextStyle(
                  fontSize: Responsive.sp(20),
                  fontWeight: FontWeight.bold,
                  color: r.yaziRengi,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildMainClock(BuildContext context, NamazProvider provider) {
  return VakitBackground(
    tema: provider.vaktinTemasi,
    borderRadius: BorderRadius.circular(Responsive.w(20)),
    child: Container(
      padding: EdgeInsets.symmetric(
        vertical: Responsive.h(24),
        horizontal: Responsive.w(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Konum güncelleniyor..."),
                  duration: Duration(seconds: 1),
                ),
              );
              context.read<NamazProvider>().konumVeApiIstegi(
                kullaniciTetikledi: true,
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: Responsive.w(10),
                vertical: Responsive.h(3),
              ),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.location_on,
                    size: Responsive.w(14),
                    color: Colors.white.withOpacity(0.9),
                  ),
                  SizedBox(width: Responsive.w(4)),
                  Flexible(
                    child: Text(
                      provider.konumBilgisi,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: Responsive.sp(12),
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        letterSpacing: 1,
                        shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                      ),
                    ),
                  ),
                  SizedBox(width: Responsive.w(4)),
                  Icon(
                    Icons.refresh,
                    size: Responsive.w(12),
                    color: Colors.white.withOpacity(0.7),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: Responsive.h(8)),
          Text(
            provider.aktifVakit.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: Responsive.sp(24),
              letterSpacing: 5,
              color: Colors.white,
              fontWeight: FontWeight.w900,
              shadows: [
                Shadow(
                  blurRadius: 10,
                  color: Colors.black45,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<String>(
            valueListenable: provider.guncelSaatNotifier,
            builder: (context, guncelSaat, child) {
              return Text(
                guncelSaat,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: Responsive.sp(64),
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: -2,
                  height: 1.0,
                  shadows: [
                    Shadow(
                      blurRadius: 15,
                      color: Colors.black38,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
              );
            },
          ),
          SizedBox(height: Responsive.h(8)),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: Responsive.w(16),
              vertical: Responsive.h(6),
            ),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(Responsive.w(15)),
            ),
            child: ValueListenableBuilder<String>(
              valueListenable: provider.kalanSureNotifier,
              builder: (context, kalanSure, child) {
                return Text(
                  "Kalan Süre: $kalanSure",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Responsive.sp(15),
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 4, color: Colors.black26)],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildVakitGrid(BuildContext context, NamazProvider provider) {
  return Container(
    padding: EdgeInsets.symmetric(vertical: Responsive.h(12)),
    decoration: _sikKutuDecoration(context),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _vakitKutusu(
          context,
          "Sabah",
          Icons.wb_twilight,
          provider.vakitler?["Sabah"] ?? "05:00",
          provider,
        ),
        _vakitKutusu(
          context,
          "Öğle",
          Icons.wb_sunny,
          provider.vakitler?["Öğle"] ?? "13:00",
          provider,
        ),
        _vakitKutusu(
          context,
          "İkindi",
          Icons.wb_twighlight,
          provider.vakitler?["İkindi"] ?? "16:00",
          provider,
        ),
        _vakitKutusu(
          context,
          "Akşam",
          Icons.bedtime,
          provider.vakitler?["Akşam"] ?? "19:00",
          provider,
        ),
        _vakitKutusu(
          context,
          "Yatsı",
          Icons.nights_stay,
          provider.vakitler?["Yatsı"] ?? "20:30",
          provider,
        ),
      ],
    ),
  );
}

Widget _buildPrayerButton(BuildContext context, NamazProvider provider) {
  return _AnimatedPrayerButton(
    isDone: provider.kildiMi[provider.aktifVakit] ?? false,
    onTap: () {
      bool suanki = provider.kildiMi[provider.aktifVakit] ?? false;
      provider.vaktiKildimIsaretle(provider.aktifVakit, !suanki);
    },
  );
}

BoxDecoration _sikKutuDecoration(BuildContext context) {
  final r = context.renkler;
  return BoxDecoration(
    color: r.kartRengi,
    borderRadius: BorderRadius.circular(Responsive.w(20)),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.08),
        blurRadius: 15,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

Widget _vakitKutusu(
  BuildContext context,
  String ad,
  IconData ikon,
  String saat,
  NamazProvider provider,
) {
  final r = context.renkler;
  bool kildi = provider.kildiMi[ad] ?? false;
  bool suan = provider.aktifVakit == ad;
  String temizSaat = saat.contains(" ") ? saat.split(" ")[0] : saat;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    padding: EdgeInsets.symmetric(
      horizontal: Responsive.w(8),
      vertical: Responsive.h(6),
    ),
    decoration: BoxDecoration(
      color: suan ? r.aktifYesil.withOpacity(0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(Responsive.w(12)),
      border: suan
          ? Border.all(color: r.aktifYesil.withOpacity(0.5), width: 1.5)
          : null,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _VakitIkonu(
          ikon: ikon,
          size: Responsive.w(24),
          color: kildi ? r.aktifYesil : (suan ? r.anaRenk : r.pasifRenk),
          isActive: suan,
        ),
        SizedBox(height: Responsive.h(6)),
        Text(
          temizSaat,
          style: TextStyle(
            fontSize: Responsive.sp(13),
            fontWeight: suan ? FontWeight.bold : FontWeight.w500,
            color: suan ? r.yaziRengi : r.yaziRengi.withOpacity(0.5),
          ),
        ),
        SizedBox(height: Responsive.h(3)),
        Text(
          ad,
          style: TextStyle(
            fontSize: Responsive.sp(10),
            color: suan ? r.anaRenk : Colors.transparent,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

class _AnimatedPrayerButton extends StatefulWidget {
  final bool isDone;
  final VoidCallback onTap;
  const _AnimatedPrayerButton({required this.isDone, required this.onTap});
  @override
  State<_AnimatedPrayerButton> createState() => _AnimatedPrayerButtonState();
}

class _AnimatedPrayerButtonState extends State<_AnimatedPrayerButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      lowerBound: 0.0,
      upperBound: 0.05,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    final btnHeight = Responsive.h(120);
    final circleSize = Responsive.w(60);
    final iconSize = Responsive.w(36);

    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: btnHeight,
          decoration: BoxDecoration(
            color: widget.isDone ? r.aktifYesil : r.kartRengi,
            borderRadius: BorderRadius.circular(Responsive.w(25)),
            border: widget.isDone
                ? null
                : Border.all(color: r.anaRenk.withOpacity(0.3), width: 2),
            boxShadow: [
              BoxShadow(
                color: widget.isDone
                    ? r.aktifYesil.withOpacity(0.4)
                    : Colors.black.withOpacity(0.05),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: circleSize,
                height: circleSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: r.arkaPlanRengi,
                  border: Border.all(
                    color: widget.isDone ? Colors.white : r.pasifRenk,
                    width: 3,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: iconSize,
                  color: widget.isDone ? r.aktifYesil : r.pasifRenk,
                ),
              ),
              SizedBox(height: Responsive.h(10)),
              Text(
                widget.isDone ? "ALLAH KABUL ETSİN!" : "VAKTİ KILDIM",
                style: TextStyle(
                  fontSize: Responsive.sp(15),
                  fontWeight: FontWeight.w900,
                  color: widget.isDone ? Colors.white : r.yaziRengi,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VakitIkonu extends StatefulWidget {
  final IconData ikon;
  final double size;
  final Color color;
  final bool isActive;

  const _VakitIkonu({
    required this.ikon,
    required this.size,
    required this.color,
    required this.isActive,
  });

  @override
  State<_VakitIkonu> createState() => _VakitIkonuState();
}

class _VakitIkonuState extends State<_VakitIkonu> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _animation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOutSine,
      ),
    );

    if (widget.isActive) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(_VakitIkonu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.isActive && _controller.isAnimating) {
      _controller.stop();
      _controller.reset();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isActive) {
      return Icon(
        widget.ikon,
        size: widget.size,
        color: widget.color,
      );
    }

    return ScaleTransition(
      scale: _animation,
      child: Icon(
        widget.ikon,
        size: widget.size,
        color: widget.color,
        shadows: [
          Shadow(
            color: widget.color.withOpacity(0.5),
            blurRadius: 10,
          ),
        ],
      ),
    );
  }
}
