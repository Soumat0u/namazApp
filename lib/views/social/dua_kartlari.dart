part of '../social_screen.dart';

// ═══════════════════════════════════════════════
// DUA GRID KART (Dua Duvarı modal'ında kullanılır)
// ═══════════════════════════════════════════════

/// Duaya basılı tutunca: kendi duasıysa sil; başkasınınsa şikâyet et / kullanıcıyı engelle
void duaSecenekleriniGoster(BuildContext context, AppThemeColors r, PrayerPost prayer, String? currentUid) {
  if (currentUid == null) return;
  final servis = FirebaseService();
  final benim = prayer.senderUid == currentUid;

  Future<void> calistir(BuildContext sheet, Future<String?> islem, String basari) async {
    Navigator.pop(sheet);
    final hata = await islem;
    Bildirim.snackBar(SnackBar(content: Text(hata ?? basari)));
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: r.arkaPlanRengi,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
    builder: (sheet) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          if (benim)
            ListTile(
              leading: Icon(Icons.delete_outline_rounded, color: r.kirmizi),
              title: Text("Duayı Sil", style: TextStyle(color: r.kirmizi, fontWeight: FontWeight.bold)),
              onTap: () async {
                final provider = context.read<NamazProvider>();
                Navigator.pop(sheet);
                final hata = await servis.duayiSil(prayer.id);
                // Paylaşırken verilen XP geri alınır: sil-paylaş döngüsüyle XP kasılmasın
                if (hata == null) await provider.xpEkle(-SeviyeServisi.duaXp);
                Bildirim.snackBar(SnackBar(content: Text(hata ?? "Dua silindi.")));
              },
            )
          else ...[
            ListTile(
              leading: Icon(Icons.flag_outlined, color: r.kirmizi),
              title: Text("Şikâyet Et", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
              subtitle: Text("Uygunsuz içerik. Dua senden gizlenir.", style: TextStyle(color: r.pasifRenk, fontSize: 12)),
              onTap: () => calistir(sheet, servis.duayiSikayetEt(prayer.id, currentUid),
                  "Şikâyetin alındı. Bu dua artık sana gösterilmeyecek."),
            ),
            ListTile(
              leading: Icon(Icons.block_rounded, color: r.kirmizi),
              title: Text("@${prayer.senderUsername} kullanıcısını engelle",
                  style: TextStyle(color: r.kirmizi, fontWeight: FontWeight.bold)),
              subtitle: Text("Duaları ve bildirimleri gizlenir, arkadaşlıktan çıkarılır.",
                  style: TextStyle(color: r.pasifRenk, fontSize: 12)),
              onTap: () => calistir(sheet, servis.kullaniciyiEngelle(currentUid, prayer.senderUid),
                  "@${prayer.senderUsername} engellendi."),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

class _DuaGridCard extends StatelessWidget {
  final PrayerPost prayer;
  final AppThemeColors r;
  final bool isFullView;
  final String? currentUid;
  final FirebaseService firebaseService;
  final List<PrayerPost>? allPrayers;
  final int? index;
  final Function(List<PrayerPost>, int)? onReelTap;

  const _DuaGridCard({
    required this.prayer, 
    required this.r, 
    this.isFullView = false,
    this.currentUid,
    required this.firebaseService,
    this.allPrayers,
    this.index,
    this.onReelTap,
  });

  void _showDuaOdakModu(BuildContext context) {
    if (isFullView) return;

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: "Dua Detay",
      barrierColor: Colors.black.withOpacity(0.8),
      transitionDuration: const Duration(milliseconds: 400),
      pageBuilder: (context, anim1, anim2) {
        return Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: Responsive.w(20)),
            child: Material(
              color: Colors.transparent,
              child: _DuaGridCard(
                prayer: prayer, 
                r: r, 
                isFullView: true,
                currentUid: currentUid,
                firebaseService: firebaseService,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return FadeTransition(opacity: anim1, child: ScaleTransition(scale: anim1, child: child));
      },
    ).whenComplete(() {
      FocusManager.instance.primaryFocus?.unfocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final benAminDedimMi = currentUid != null && 
                           currentUid!.isNotEmpty && 
                           prayer.aminBy.contains(currentUid);

    return GestureDetector(
      key: ValueKey("grid_${prayer.id}"),
      onLongPress: () => duaSecenekleriniGoster(context, r, prayer, currentUid),
      onTap: () {
        if (onReelTap != null && allPrayers != null && index != null) {
          onReelTap!(allPrayers!, index!);
        } else {
          _showDuaOdakModu(context);
        }
      },
      child: Container(
        padding: EdgeInsets.all(Responsive.w(12)),
        decoration: BoxDecoration(
          color: r.kartRengi,
          borderRadius: BorderRadius.circular(Responsive.w(15)),
          border: Border.all(color: r.anaRenk.withOpacity(isFullView ? 0.3 : 0.1)),
          boxShadow: isFullView ? [BoxShadow(color: r.anaRenk.withOpacity(0.2), blurRadius: 20)] : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: isFullView ? 12 : 8, 
                  backgroundColor: r.anaRenk.withOpacity(0.1), 
                  child: Text(
                    prayer.senderName.isNotEmpty ? prayer.senderName[0].toUpperCase() : "?",
                    style: TextStyle(color: r.anaRenk, fontWeight: FontWeight.bold, fontSize: isFullView ? 12 : 8),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(prayer.senderName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: Responsive.sp(isFullView ? 14 : 10), color: r.yaziRengi), overflow: TextOverflow.ellipsis),
                      if (prayer.senderUsername.isNotEmpty)
                        Text("@${prayer.senderUsername}", style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(isFullView ? 11 : 8)), overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                if (isFullView) 
                  IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close_rounded, size: 20, color: r.yaziRengi.withOpacity(0.4)))
                else
                  Text(prayer.zamanFarki, style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(8))),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              "\"${prayer.text}\"",
              maxLines: isFullView ? null : 2,
              overflow: isFullView ? TextOverflow.visible : TextOverflow.ellipsis,
              style: TextStyle(
                color: r.yaziRengi.withOpacity(0.8),
                fontSize: Responsive.sp(isFullView ? 16 : 11),
                height: 1.4,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (prayer.aminCount > 0)
                  Text(
                    "${prayer.aminCount} Amîn",
                    style: TextStyle(color: r.pasifRenk, fontSize: Responsive.sp(isFullView ? 12 : 9), fontWeight: FontWeight.w600),
                  ),
                const Spacer(),
                if (isFullView) ...[
                  Text("Allah kabul etsin", style: TextStyle(color: r.anaRenk.withOpacity(0.6), fontSize: Responsive.sp(12), fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                ],
                AminParticleButton(
                  key: ValueKey("grid_anim_${prayer.id}"),
                  isAmind: benAminDedimMi,
                  r: r,
                  child: GestureDetector(
                    onTap: () async {
                      if (currentUid == null) return;
                      HapticFeedback.lightImpact();
                      await firebaseService.toggleAmin(prayerId: prayer.id, userUid: currentUid!);
                    },
                    child: Icon(
                      benAminDedimMi ? Icons.favorite_rounded : Icons.favorite_border_rounded, 
                      size: isFullView ? 20 : 16, 
                      color: benAminDedimMi ? Colors.redAccent : r.anaRenk.withOpacity(0.7),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════
// ETKİLEŞİMLİ AMİN BUTONU EFEKTİ
// ═══════════════════════════════════════════════

class AminParticleButton extends StatefulWidget {
  final bool isAmind;
  final Widget child;
  final AppThemeColors r;

  const AminParticleButton({
    super.key,
    required this.isAmind,
    required this.child,
    required this.r,
  });

  @override
  State<AminParticleButton> createState() => _AminParticleButtonState();
}

class _AminParticleButtonState extends State<AminParticleButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _starScaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    
    _scaleAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.85), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 0.85, end: 1.1).chain(CurveTween(curve: Curves.elasticOut)), weight: 80),
    ]).animate(_controller);

    _starScaleAnimation = Tween<double>(begin: 0.0, end: 2.2).animate(CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
    ));

    _opacityAnimation = TweenSequence([
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 1.0), weight: 20),
      TweenSequenceItem(tween: Tween<double>(begin: 1.0, end: 0.0).chain(CurveTween(curve: Curves.easeIn)), weight: 80),
    ]).animate(_controller);
  }

  @override
  void didUpdateWidget(AminParticleButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Eğer amîn durumuna geçilmişse parlamayı başlat
    if (widget.isAmind && !oldWidget.isAmind) {
      _controller.forward(from: 0.0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // Parlayan (patlayan) dört köşeli yıldız efekti
        AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            if (_controller.value == 0 || _controller.value == 1) return const SizedBox.shrink();
            return Transform.scale(
              scale: _starScaleAnimation.value,
              child: Opacity(
                opacity: _opacityAnimation.value,
                child: const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 28),
              ),
            );
          },
        ),
        // Esneyen ana buton
        ScaleTransition(
          scale: _scaleAnimation,
          child: widget.child,
        ),
      ],
    );
  }
}
