import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../core/constants/app_colors.dart';
import '../providers/namaz_provider.dart';

class AnaSayfa extends StatelessWidget {
  const AnaSayfa({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NamazProvider>();
    final ekranYuksekligi = MediaQuery.of(context).size.height;

    if (provider.isLoading && provider.vakitler == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.anaRenk),
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
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                provider.hataMesaji,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.yaziRengi,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => context.read<NamazProvider>().konumVeApiIstegi(
                kullaniciTetikledi: true,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.anaRenk,
                foregroundColor: Colors.white,
              ),
              child: const Text("Konum İzni Ver / Tekrar Dene"),
            ),
          ],
        ),
      );
    }

    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.anaRenk,
        backgroundColor: AppColors.kartRengi,
        onRefresh: () => context.read<NamazProvider>().konumVeApiIstegi(
          kullaniciTetikledi: true,
        ),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(provider),
                const SizedBox(height: 20),
                _buildMainClock(provider, ekranYuksekligi, context),
                const SizedBox(height: 20),
                _buildVakitGrid(provider),
                const SizedBox(height: 20),
                _buildPrayerButton(provider, ekranYuksekligi),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Widget _buildHeader(NamazProvider provider) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: _sikKutuDecoration(),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              provider.ekranTarihi.isNotEmpty
                  ? provider.ekranTarihi.split(',')[0]
                  : "Pazartesi",
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.yaziRengi,
              ),
            ),
            // HİCRİ TAKVİM EKLENDİ
            Text(
              provider.hicriTarih.isNotEmpty
                  ? provider.hicriTarih
                  : "1 Ramazan 1445",
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.anaRenk,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              provider.ekranTarihi.contains(',')
                  ? provider.ekranTarihi.split(',')[1].trim()
                  : "10 Mart",
              style: TextStyle(
                fontSize: 14,
                color: AppColors.yaziRengi.withOpacity(0.7),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.anaRenk.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.local_fire_department,
                color: AppColors.anaRenk,
                size: 28,
              ),
              const SizedBox(width: 5),
              Text(
                "${provider.streakCount}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.yaziRengi,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _buildMainClock(NamazProvider provider, double h, BuildContext context) {
  return Container(
    height: h * 0.35,
    decoration: _sikKutuDecoration().copyWith(
      gradient: const LinearGradient(
        colors: [AppColors.kartRengi, Color(0xFFFFF3E0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: AppColors.yaziRengi.withOpacity(0.6),
                ),
                const SizedBox(width: 4),
                Text(
                  provider.konumBilgisi,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.yaziRengi.withOpacity(0.6),
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.refresh,
                  size: 14,
                  color: AppColors.yaziRengi.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          provider.aktifVakit.toUpperCase(),
          style: const TextStyle(
            fontSize: 28,
            letterSpacing: 5,
            color: AppColors.anaRenk,
            fontWeight: FontWeight.w900,
          ),
        ),
        Text(
          DateFormat("HH:mm").format(DateTime.now()),
          style: const TextStyle(
            fontSize: 75,
            fontWeight: FontWeight.bold,
            color: AppColors.yaziRengi,
            letterSpacing: -2,
            height: 1.0,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.yaziRengi.withOpacity(0.08),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            "Kalan Süre: ${provider.kalanSure}",
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.yaziRengi,
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildVakitGrid(NamazProvider provider) {
  return Container(
    height: 130,
    padding: const EdgeInsets.symmetric(vertical: 15),
    decoration: _sikKutuDecoration(),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _vakitKutusu(
          "Sabah",
          Icons.wb_twilight,
          provider.vakitler?["Sabah"] ?? "05:00",
          provider,
        ),
        _vakitKutusu(
          "Öğle",
          Icons.wb_sunny,
          provider.vakitler?["Öğle"] ?? "13:00",
          provider,
        ),
        _vakitKutusu(
          "İkindi",
          Icons.wb_twighlight,
          provider.vakitler?["İkindi"] ?? "16:00",
          provider,
        ),
        _vakitKutusu(
          "Akşam",
          Icons.bedtime,
          provider.vakitler?["Akşam"] ?? "19:00",
          provider,
        ),
        _vakitKutusu(
          "Yatsı",
          Icons.nights_stay,
          provider.vakitler?["Yatsı"] ?? "20:30",
          provider,
        ),
      ],
    ),
  );
}

Widget _buildPrayerButton(NamazProvider provider, double h) {
  return SizedBox(
    height: h * 0.15,
    child: _AnimatedPrayerButton(
      isDone: provider.kildiMi[provider.aktifVakit] ?? false,
      onTap: () {
        bool suanki = provider.kildiMi[provider.aktifVakit] ?? false;
        provider.vaktiKildimIsaretle(provider.aktifVakit, !suanki);
      },
    ),
  );
}

BoxDecoration _sikKutuDecoration() => BoxDecoration(
  color: AppColors.kartRengi,
  borderRadius: BorderRadius.circular(25),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.08),
      blurRadius: 15,
      offset: const Offset(0, 5),
    ),
  ],
);

Widget _vakitKutusu(
  String ad,
  IconData ikon,
  String saat,
  NamazProvider provider,
) {
  bool kildi = provider.kildiMi[ad] ?? false;
  bool suan = provider.aktifVakit == ad;
  String temizSaat = saat.contains(" ") ? saat.split(" ")[0] : saat;

  return AnimatedContainer(
    duration: const Duration(milliseconds: 400),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: suan ? AppColors.aktifYesil.withOpacity(0.2) : Colors.transparent,
      borderRadius: BorderRadius.circular(15),
      border: suan
          ? Border.all(color: AppColors.aktifYesil.withOpacity(0.5), width: 1.5)
          : null,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          ikon,
          size: 28,
          color: kildi
              ? AppColors.aktifYesil
              : (suan ? AppColors.anaRenk : AppColors.pasifRenk),
        ),
        const SizedBox(height: 8),
        Text(
          temizSaat,
          style: TextStyle(
            fontSize: 15,
            fontWeight: suan ? FontWeight.bold : FontWeight.w500,
            color: suan
                ? AppColors.yaziRengi
                : AppColors.yaziRengi.withOpacity(0.5),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          ad,
          style: TextStyle(
            fontSize: 12,
            color: suan ? AppColors.anaRenk : Colors.transparent,
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
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            color: widget.isDone ? AppColors.aktifYesil : AppColors.kartRengi,
            borderRadius: BorderRadius.circular(30),
            border: widget.isDone
                ? null
                : Border.all(
                    color: AppColors.anaRenk.withOpacity(0.3),
                    width: 2,
                  ),
            boxShadow: [
              BoxShadow(
                color: widget.isDone
                    ? AppColors.aktifYesil.withOpacity(0.4)
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
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.arkaPlanRengi,
                  border: Border.all(
                    color: widget.isDone ? Colors.white : AppColors.pasifRenk,
                    width: 4,
                  ),
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 45,
                  color: widget.isDone
                      ? AppColors.aktifYesil
                      : AppColors.pasifRenk,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                widget.isDone ? "ALLAH KABUL ETSİN!" : "VAKTİ KILDIM",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: widget.isDone ? Colors.white : AppColors.yaziRengi,
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
