import '../core/utils/bildirim.dart';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:vibration/vibration.dart';
import '../core/utils/responsive.dart';
import '../providers/theme_provider.dart';
import '../services/pusula_kalibrasyonu.dart';

class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  final _deviceSupport = FlutterQiblah.androidDeviceSensorSupport();
  bool _hasPermissions = false;
  bool _vibratedTarget = false;
  bool _canVibrate = false;
  
  StreamSubscription? _qiblahSub;
  StreamSubscription? _compassSub;
  StreamSubscription<Position>? _positionSub;
  double _smoothHeading = 0;   // Yumuşatılmış cihaz açısı (Kuzeye göre)
  // Titreşim motoru bir mıknatıstır: titrerken ve hemen ardından manyetometre
  // sapar, ok bir anlığına kırılıp geri döner. Bu süre içindeki okumalar atlanır.
  DateTime _titresimSonu = DateTime(0);
  // Ani sıçrama ayıklama: büyük bir sapma ancak art arda birkaç okumada sürerse kabul edilir
  int _sapmaSayaci = 0;
  static const _hedefGiris = 4.0; // Kıble yönüne girildi sayılan açı
  static const _hedefCikis = 8.0; // Çıkış eşiği daha geniş: sınırda gidip gelince tekrar tekrar titremesin
  double? _qiblaFixedAngle;    // Kabe'nin Kuzeye göre sabit açısı (Hesaplanana kadar null)
  double _smoothOffset = 0;    // Kıble'nin cihaza göre anlık fark açısı (yumuşatılmış)
  bool _isAccuracyLow = false; // Hassasiyet tam değil (uyarı şeridi)
  bool _parazit = false;       // Yakında mıknatıs/metal var gibi
  // Kalibrasyon: null = henüz okunmadı. Rehber bunu canlı gösterir.
  final ValueNotifier<PusulaOkuma?> _pusula = ValueNotifier(null);
  bool _bozukGoruldu = false;  // Bu açılışta kalibrasyon bozuk görüldü mü (düzelince bildirmek için)
  bool _rehberGosterildi = false; // Otomatik rehber bu açılışta yalnızca bir kez açılır
  BuildContext? _rehberContext;   // Açık rehber (kalibrasyon düzelince kapatmak için)
  Timer? _rehberZamanlayici;
  final List<double> _siddetler = [];

  @override
  void initState() {
    super.initState();
    _resetAndInit();
  }

  Future<void> _resetAndInit() async {
    // Önce temizlik yap (baştan başlaması için)
    try {
      _qiblahSub?.cancel();
      _compassSub?.cancel();
      _positionSub?.cancel();
      FlutterQiblah().dispose();
    } catch (_) {}
    
    _checkPermissions();
    _initSensors();
    _initLocationListener();
    _checkVibrationSupport();
  }


  void _initLocationListener() {
    if (mounted) setState(() => _qiblaFixedAngle = null); // Her açılışta sıfırla
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((Position position) {
      if (mounted) {
        double bearing = _calculateQiblaBearing(position.latitude, position.longitude);
        setState(() => _qiblaFixedAngle = bearing);
      }
    });
  }

  Future<void> _checkVibrationSupport() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (mounted) {
      setState(() => _canVibrate = hasVibrator);
    }
  }

  void _initSensors() {
    // 1. Kabe'nin Kuzeye olan mutlak açısını 1 kez al ve çivile
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((pos) {
      if (mounted) {
        double bearing = _calculateQiblaBearing(pos.latitude, pos.longitude);
        setState(() => _qiblaFixedAngle = bearing);
      }
    }).catchError((_) {
      // Hata durumunda (GPS yoksa) kütüphane varsayılanını dene
      FlutterQiblah.qiblahStream.first.then((direction) {
        if (mounted) setState(() => _qiblaFixedAngle = direction.qiblah);
      });
    });

    // 2. Kalibrasyonu doğrudan manyetometreden takip et. Bozuksa (Android
    // "güvenilmez"/"düşük") rehber kendiliğinden açılır; düzelince kapanır.
    _compassSub = PusulaKalibrasyonu.okumalar().listen(_pusulaOkundu, onError: (_) {});

    // 3. Sadece cihazın pusula dönüşünü sürekli dinle
    _qiblahSub = FlutterQiblah.qiblahStream.listen((QiblahDirection direction) {
      if (mounted) {
        if (DateTime.now().isBefore(_titresimSonu)) return; // titreşimin manyetik etkisi
        // Tek okumalık büyük sıçramaları yok say (gerçek dönüşler birkaç okuma sürer)
        var fark = (direction.direction - _smoothHeading) % 360;
        if (fark > 180) fark -= 360;
        if (fark.abs() > 25 && _sapmaSayaci < 3) {
          _sapmaSayaci++;
          return;
        }
        _sapmaSayaci = 0;
        setState(() {
          // Sadece cihazın Kuzey'e olan açısını (heading) alıyoruz.
          // Kıble açısı (_qiblaFixedAngle) GPS ile sabit hesaplandığı için diske çakılı kalır.
          _smoothHeading = _lerpAngle(_smoothHeading, direction.direction, 0.15);
          _smoothOffset = _lerpAngle(_smoothOffset, direction.offset, 0.15);
        });
        _hedefKontrol();
      }
    });
  }

  void _pusulaOkundu(PusulaOkuma o) {
    if (!mounted) return;
    final onceki = _pusula.value;
    _pusula.value = o;

    // Alan şiddetinin son ~2 sn ortalaması: tek tük sıçramalar uyarı çıkarmasın
    _siddetler.add(o.siddet);
    if (_siddetler.length > 10) _siddetler.removeAt(0);
    final ort = _siddetler.reduce((a, b) => a + b) / _siddetler.length;
    final parazit = _siddetler.length >= 5 && (ort < 20 || ort > 70);

    final dusuk = o.durum <= 2;
    if (dusuk != _isAccuracyLow || parazit != _parazit) {
      setState(() {
        _isAccuracyLow = dusuk;
        _parazit = parazit;
      });
    }

    if (o.bozuk) {
      _bozukGoruldu = true;
      // Sensör açılışta kısa bir an "güvenilmez" diyebilir: 1,5 sn sürerse rehberi aç
      if (!_rehberGosterildi && _rehberZamanlayici == null) {
        _rehberZamanlayici = Timer(const Duration(milliseconds: 1500), () {
          _rehberZamanlayici = null;
          if (mounted && (_pusula.value?.bozuk ?? false) && !_rehberGosterildi) {
            _showCalibrationDialog(context, context.read<ThemeProvider>().aktifTema);
          }
        });
      }
    } else if (onceki != null && onceki.bozuk && _bozukGoruldu) {
      // Bozuktan çalışır hâle geldi: rehberi kapat, haber ver
      _bozukGoruldu = false;
      _rehberZamanlayici?.cancel();
      _rehberZamanlayici = null;
      final rehber = _rehberContext;
      if (rehber != null && rehber.mounted) Navigator.of(rehber).pop();
      if (_canVibrate) {
        Vibration.vibrate(duration: 200);
        _titresimSonu = DateTime.now().add(const Duration(milliseconds: 600));
      }
      Bildirim.snackBar(
        const SnackBar(
          content: Text('Pusula kalibre edildi'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  double _lerpAngle(double oldAngle, double newAngle, double t) {
    double diff = (newAngle - oldAngle) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return oldAngle + diff * t;
  }

  // Kıble Açısı Hesaplama (Great Circle Bearing)
  double _calculateQiblaBearing(double lat1, double lon1) {
    const double lat2 = 21.42252414371485; // Kabe Enlem
    const double lon2 = 39.82618182245369; // Kabe Boylam

    double phi1 = lat1 * pi / 180;
    double phi2 = lat2 * pi / 180;
    double lambda1 = lon1 * pi / 180;
    double lambda2 = lon2 * pi / 180;

    double y = sin(lambda2 - lambda1) * cos(phi2);
    double x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(lambda2 - lambda1);
    double bearing = atan2(y, x);
    return (bearing * 180 / pi + 360) % 360;
  }

  // 5. Hata & İzin Yönetimi
  Future<void> _checkPermissions() async {
    final permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.always || permission == LocationPermission.whileInUse) {
      if (mounted) setState(() => _hasPermissions = true);
    } else {
      final req = await Geolocator.requestPermission();
      if (req == LocationPermission.always || req == LocationPermission.whileInUse) {
        if (mounted) setState(() => _hasPermissions = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final tema = context.watch<ThemeProvider>().aktifTema;

    // Hedefe olan fark açısının hesaplanması: (Kıble Açısı - Cihaz Açısı)
    double diff = ((_qiblaFixedAngle ?? 0) - _smoothHeading) % 360; 

    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    double kalanAci = diff.abs();

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
        actions: [
          IconButton(
            icon: Icon(Icons.help_outline_rounded, color: tema.yaziRengi),
            onPressed: () => _showCalibrationDialog(context, tema),
          ),
          SizedBox(width: Responsive.w(8)),
        ],
        title: Text(
          "Kıble Pusulası",
          style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(18)),
        ),
      ),
      body: FutureBuilder(
        future: _deviceSupport,
        builder: (_, AsyncSnapshot<bool?> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: tema.anaRenk));
          }
          if (snapshot.data == true) {
            if (!_hasPermissions) return _buildPermissionError(tema);
            
            if (_qiblaFixedAngle == null) {
              return Center(child: CircularProgressIndicator(color: tema.anaRenk));
            }
            
            return _buildCompassUI(tema, _smoothHeading, _qiblaFixedAngle!, kalanAci);
          } else {
            return Center(
              child: Text(
                "Cihazınızda pusula sensörü bulunmuyor.",
                style: TextStyle(color: tema.yaziRengi, fontSize: Responsive.sp(16)),
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildCompassUI(tema, double smoothCompassHeading, double qiblaFixedAngle, double kalanAci) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isAccuracyLow || _parazit)
              Padding(
                padding: EdgeInsets.only(bottom: Responsive.h(16)),
                child: GestureDetector(
                  onTap: () => _showCalibrationDialog(context, tema),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: Responsive.w(16), vertical: Responsive.h(10)),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(Responsive.w(12)),
                      border: Border.all(color: Colors.amber.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber, size: Responsive.w(20)),
                        SizedBox(width: Responsive.w(8)),
                        Text(
                          (_pusula.value?.bozuk ?? false)
                              ? 'Pusula kalibre edilmeli. Rehber için dokunun'
                              : _parazit
                                  ? 'Yakında mıknatıs veya metal olabilir'
                                  : 'Pusula hassasiyeti düşük. Kalibre edin',
                          style: TextStyle(
                            color: tema.yaziRengi,
                            fontSize: Responsive.sp(13),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            Text(
              "Kıbleye Kalan Açı: ${kalanAci.toStringAsFixed(1)}°",
              style: TextStyle(color: tema.yaziRengi.withOpacity(0.7), fontSize: Responsive.sp(14), fontWeight: FontWeight.w600),
            ),
            SizedBox(height: Responsive.h(40)),
            Stack(
              alignment: Alignment.center,
              children: [
                // 1. Fiziksel Pusula Mantığı (Tüm Gövde Tek Vektörde Döner)
                Transform.rotate(
                  angle: (smoothCompassHeading * (pi / 180) * -1), // Cihazın açısının tersine tüm pusulayı salla (Kuzeyi sabitle)
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Arkadaki pusula kadranı (N,S,E,W)
                      _buildCompassDiskBody(tema),
                      
                      // Diske 'çakılı' Kabe Oku
                      Transform.rotate(
                        angle: (qiblaFixedAngle * (pi / 180)),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 4. Görseller: navigation_rounded (45° eğik)
                            Icon(
                              Icons.navigation_rounded,
                              size: Responsive.w(150),
                              color: tema.anaRenk,
                            ),
                            // Ortasındaki beyaz daire
                            Positioned(
                              bottom: Responsive.w(80),
                              child: Container(
                                width: Responsive.w(12),
                                height: Responsive.w(12),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: Responsive.h(60)),
            _buildStatusIndicator(tema, kalanAci),
          ],
        ),
      ),
    );
  }

  // Sadece diskin görsel çizimleri
  Widget _buildCompassDiskBody(tema) {
    return SizedBox(
      width: Responsive.w(320),
      height: Responsive.w(320),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Açılar/Çizgiler
          ...List.generate(36, (index) {
            return Transform.rotate(
              angle: (index * 10) * (pi / 180),
              child: Column(
                children: [
                  SizedBox(height: Responsive.w(40)),
                  Container(
                    width: index % 9 == 0 ? 3 : 1,
                    height: index % 9 == 0 ? 12 : 6,
                    color: index % 9 == 0 ? tema.anaRenk : tema.pasifRenk.withOpacity(0.5),
                  ),
                  const Spacer(),
                ],
              ),
            );
          }),
          // Yön Harfleri
          Positioned(top: 0, child: _directionText("N", tema.anaRenk, 24)),
          Positioned(bottom: 0, child: _directionText("S", tema.yaziRengi, 20)),
          Positioned(right: 0, child: _directionText("E", tema.yaziRengi, 20)),
          Positioned(left: 0, child: _directionText("W", tema.yaziRengi, 20)),
          
          // Sabit çerçeve çizgisi
          Container(
            width: Responsive.w(240),
            height: Responsive.w(240),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tema.anaRenk.withOpacity(0.2), width: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _directionText(String label, Color color, double size) {
    return Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: Responsive.sp(size)));
  }

  /// Kıble yönüne girince bir kez titreşir (giriş/çıkış eşikleri farklı)
  void _hedefKontrol() {
    if (_qiblaFixedAngle == null) return;
    var diff = (_qiblaFixedAngle! - _smoothHeading) % 360;
    if (diff > 180) diff -= 360;
    final kalan = diff.abs();
    if (!_vibratedTarget && kalan < _hedefGiris) {
      _vibratedTarget = true;
      if (_canVibrate) {
        Vibration.vibrate(duration: 60);
        _titresimSonu = DateTime.now().add(const Duration(milliseconds: 450));
      }
    } else if (_vibratedTarget && kalan > _hedefCikis) {
      _vibratedTarget = false;
    }
  }

  Widget _buildStatusIndicator(tema, double kalanAci) {
    final onTarget = _vibratedTarget; // giriş 4°, çıkış 8° (sınırda yanıp sönmez)
    return Container(
      padding: EdgeInsets.symmetric(horizontal: Responsive.w(24), vertical: Responsive.h(12)),
      decoration: BoxDecoration(
        color: tema.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(20)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mosque, color: onTarget ? tema.anaRenk : tema.pasifRenk, size: Responsive.w(20)),
          SizedBox(width: Responsive.w(12)),
          Text(
            onTarget ? "Kıble Yönündesiniz!" : "Cihazı Döndürün",
            style: TextStyle(color: onTarget ? tema.anaRenk : tema.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(16)),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionError(tema) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(Responsive.w(20)),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_disabled_rounded, size: Responsive.w(60), color: tema.pasifRenk),
            SizedBox(height: Responsive.h(16)),
            Text(
              "Pusulanın çalışması için konum izni gerekiyor.",
              textAlign: TextAlign.center,
              style: TextStyle(color: tema.yaziRengi, fontSize: Responsive.sp(16)),
            ),
            SizedBox(height: Responsive.h(16)),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: tema.anaRenk,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Responsive.w(15))),
              ),
              onPressed: _checkPermissions,
              child: const Text("İzin İste", style: TextStyle(color: Colors.white)),
            )
          ],
        ),
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context, dynamic tema) {
    if (_rehberContext != null) return; // zaten açık
    _rehberGosterildi = true;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // İçeriğin tam yükseklik almasına izin ver
      backgroundColor: tema.arkaPlanRengi,
      barrierColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(25))),
      ),
      builder: (context) {
        _rehberContext = context;
        return SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.fromLTRB(
              Responsive.w(24),
              Responsive.w(24),
              Responsive.w(24),
              MediaQuery.of(context).padding.bottom + Responsive.w(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(Responsive.w(20)),
                child: SizedBox(
                  width: double.infinity,
                  height: Responsive.h(240),
                  child: _CalibrationVideoPlayer(),
                ),
              ),
              SizedBox(height: Responsive.h(24)),
              Text(
                'Pusulayı kalibre etmek için telefonunuzu havada büyük bir 8 rakamı çizecek şekilde 5-10 saniye boyunca hareket ettirin.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: tema.yaziRengi,
                  fontSize: Responsive.sp(16),
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: Responsive.h(10)),
              Text(
                'Telefon kılıfındaki mıknatıstan, metal masalardan ve elektronik cihazlardan uzaklaşın.',
                textAlign: TextAlign.center,
                style: TextStyle(color: tema.yaziRengi.withOpacity(0.65), fontSize: Responsive.sp(13)),
              ),
              SizedBox(height: Responsive.h(18)),
              ValueListenableBuilder<PusulaOkuma?>(
                valueListenable: _pusula,
                builder: (_, o, _) => _kalibrasyonDurumu(tema, o),
              ),
              SizedBox(height: Responsive.h(18)),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tema.anaRenk,
                    padding: EdgeInsets.symmetric(vertical: Responsive.h(16)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(Responsive.w(15)),
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Anladım',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: Responsive.sp(16),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(height: Responsive.h(12)),
            ],
          ),
        ),
      );
      },
    ).whenComplete(() => _rehberContext = null);
  }

  /// Rehberde canlı kalibrasyon durumu
  Widget _kalibrasyonDurumu(dynamic tema, PusulaOkuma? o) {
    final (String yazi, Color renk, double oran) = switch (o?.durum) {
      null => ('Sensör okunuyor…', tema.pasifRenk as Color, 0.0),
      0 => ('Kalibrasyon gerekli', Colors.red.shade400, 0.15),
      1 => ('Düşük. 8 çizmeye devam edin', Colors.orange, 0.4),
      2 => ('Orta. Biraz daha', Colors.amber.shade700, 0.75),
      _ => ('Hazır', Colors.green, 1.0),
    };
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.explore_rounded, color: renk, size: Responsive.w(18)),
            SizedBox(width: Responsive.w(6)),
            Text(yazi, style: TextStyle(color: renk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(14))),
          ],
        ),
        SizedBox(height: Responsive.h(8)),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: oran),
            duration: const Duration(milliseconds: 400),
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 6,
              color: renk,
              backgroundColor: (tema.pasifRenk as Color).withOpacity(0.2),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _rehberZamanlayici?.cancel();
    _pusula.dispose();
    _qiblahSub?.cancel();
    _compassSub?.cancel();
    _positionSub?.cancel();
    FlutterQiblah().dispose();
    super.dispose();
  }
}

class _CalibrationVideoPlayer extends StatefulWidget {
  @override
  _CalibrationVideoPlayerState createState() => _CalibrationVideoPlayerState();
}

class _CalibrationVideoPlayerState extends State<_CalibrationVideoPlayer> {
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset('assets/videos/calibration_video.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() {});
          _controller.setLooping(true);
          _controller.setVolume(0); // Sesi kapat
          _controller.play();
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    if (_controller.value.isInitialized) {
      return FittedBox(
        fit: BoxFit.cover,
        alignment: const Alignment(0, -0.2), // Yazıları kırpmak için yukarı odaklan
        child: SizedBox(
          width: _controller.value.size.width,
          height: _controller.value.size.height,
          child: VideoPlayer(_controller),
        ),
      );
    } else {
      return const Center(child: CircularProgressIndicator());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
