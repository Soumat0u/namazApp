import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:flutter_compass_v2/flutter_compass_v2.dart';
import 'package:vibration/vibration.dart';
import '../core/utils/responsive.dart';
import '../providers/theme_provider.dart';

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
  StreamSubscription? _positionSub;
  double _smoothHeading = 0;   // Yumuşatılmış cihaz açısı (Kuzeye göre)
  double? _qiblaFixedAngle;    // Kabe'nin Kuzeye göre sabit açısı (Hesaplanana kadar null)
  double _smoothOffset = 0;    // Kıble'nin cihaza göre anlık fark açısı (yumuşatılmış)
  bool _isAccuracyLow = false; // Sensör doğruluğu düşük mü?
  int? _lastAccuracy;          // En son gelen doğruluk verisi (Takip için)

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
    _initLocationListener(); // Canlı konum dinleyicisi
    _checkVibrationSupport();
  }

  void _initLocationListener() {
    if (mounted) setState(() => _qiblaFixedAngle = null); // Her açılışta sıfırla

    // Önce mevcut konumu al ve ilk açıyı hesapla
    Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).then((position) {
      if (mounted) {
        setState(() {
          _qiblaFixedAngle = _calculateQiblaBearing(position.latitude, position.longitude);
        });
      }
    }).catchError((_) {
      // Hata durumunda (GPS yoksa) kütüphane varsayılanını dene
      FlutterQiblah.qiblahStream.first.then((direction) {
        if (mounted) setState(() => _qiblaFixedAngle = direction.qiblah);
      });
    });

    // Sonra konum değiştikçe dinlemeye devam et
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // 10 metrede bir güncelle
      ),
    ).listen((Position position) {
      if (mounted) {
        setState(() {
          _qiblaFixedAngle = _calculateQiblaBearing(position.latitude, position.longitude);
        });
      }
    });
  }

  double _calculateQiblaBearing(double lat, double lng) {
    const double meccaLat = 21.4225241;
    const double meccaLng = 39.8261818;

    double phi1 = lat * (pi / 180);
    double lambda1 = lng * (pi / 180);
    double phi2 = meccaLat * (pi / 180);
    double lambda2 = meccaLng * (pi / 180);

    double y = sin(lambda2 - lambda1) * cos(phi2);
    double x = cos(phi1) * sin(phi2) - sin(phi1) * cos(phi2) * cos(lambda2 - lambda1);
    double bearing = atan2(y, x);
    
    return (bearing * (180 / pi) + 360) % 360;
  }

  Future<void> _checkVibrationSupport() async {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (mounted) {
      setState(() => _canVibrate = hasVibrator ?? false);
    }
  }

  void _initSensors() {
    // 2. Pusula doğruluğunu (accuracy) FlutterCompass üzerinden takip et
    _compassSub = FlutterCompass.events?.listen((event) {
      if (mounted) {
        // Android'de sensör doğruluğu verisi (0: Unreliable, 1: Low, 2: Medium, 3: High)
        int currentAccuracy = event.accuracy?.toInt() ?? 3;

        setState(() {
          // Doğruluk 3'ten (High) düşükse uyarı bandını aktif et
          _isAccuracyLow = currentAccuracy < 3;

          // Kalibrasyon düşükten (0,1,2) -> yüksek (3) seviyesine çıktıysa bildirim ver
          if (_lastAccuracy != null && _lastAccuracy! < 3 && currentAccuracy == 3) {
            if (_canVibrate) {
              Vibration.vibrate(duration: 200);
            }
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Pusula Kalibre Edildi'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          _lastAccuracy = currentAccuracy;
        });
      }
    });

    // 3. Sadece cihazın pusula dönüşünü sürekli dinle
    _qiblahSub = FlutterQiblah.qiblahStream.listen((QiblahDirection direction) {
      if (mounted) {
        setState(() {
          // Sadece cihazın Kuzey'e olan açısını (heading) alıyoruz.
          // Kıble açısı (_qiblaFixedAngle) GPS ile sabit hesaplandığı için diske çakılı kalır.
          _smoothHeading = _lerpAngle(_smoothHeading, direction.direction, 0.15);
          _smoothOffset = _lerpAngle(_smoothOffset, direction.offset, 0.15);
        });
      }
    });
  }

  double _lerpAngle(double oldAngle, double newAngle, double t) {
    double diff = (newAngle - oldAngle) % 360;
    if (diff > 180) diff -= 360;
    if (diff < -180) diff += 360;
    return oldAngle + diff * t;
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
            if (_isAccuracyLow)
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
                          'Pusula hassasiyeti düşük. Kalibre edin',
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
                        angle: ((qiblaFixedAngle ?? 0) * (pi / 180)),
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
            // Çizim üstüne değil ekranda sabit duran haptic mantığı
            _handleVibration(kalanAci),
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

  // 4. Görseller ve Titreşim (< 5 Derece Kuralı)
  Widget _handleVibration(double kalanAci) {
    if (kalanAci < 5.0 && !_vibratedTarget) {
      Future.microtask(() {
        if (mounted) {
          setState(() => _vibratedTarget = true);
          if (_canVibrate) {
            Vibration.vibrate(duration: 100);
          }
        }
      });
    } else if (kalanAci >= 5.0 && _vibratedTarget) {
      Future.microtask(() {
        if (mounted) setState(() => _vibratedTarget = false);
      });
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatusIndicator(tema, double kalanAci) {
    bool onTarget = kalanAci < 5.0; // 5 derece hedef marjı
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // İçeriğin tam yükseklik almasına izin ver
      backgroundColor: tema.arkaPlanRengi,
      barrierColor: Colors.black.withOpacity(0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Responsive.w(25))),
      ),
      builder: (context) {
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
              SizedBox(height: Responsive.h(32)),
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
    );
  }

  @override
  void dispose() {
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
