import 'dart:async';
import 'dart:math' show pi, atan2;
import 'package:flutter/material.dart';
import 'package:flutter_qiblah/flutter_qiblah.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';

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
  
  StreamSubscription? _qiblahSub;
  double _smoothHeading = 0; // Yumuşatılmış (Lerp) cihaz açısı
  double _qiblaFixedAngle = 0; // Kabe'nin cihaza / konuma göre sabit pusula açısı

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    _initSensors();
  }

  void _initSensors() {
    // Kusursuz ve eğime duyarlı pusula verisini dinleyip yumuşatma filtresinden geçiriyoruz
    _qiblahSub = FlutterQiblah.qiblahStream.listen((QiblahDirection direction) {
      if (mounted) {
        setState(() {
          _qiblaFixedAngle = direction.qiblah;
          // Pürüzsüzlük (FPS) hissini artıran Low-Pass Filtresi asıl pusula yönü üzerine uygulanır
          _smoothHeading = _lerpAngle(_smoothHeading, direction.direction, 0.15);
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

    // Fark açısı: Kıble açısı ile cihazın pürüzsüz (smoothed) dönüş açısı arasındaki kısa fark (0-180)
    double diff = (_qiblaFixedAngle - _smoothHeading) % 360;
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
        title: Text(
          "Kıble Pusulası",
          style: TextStyle(
            color: tema.yaziRengi,
            fontWeight: FontWeight.bold,
            fontSize: Responsive.sp(18),
          ),
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
            
            // Veri varsa, Pusula UI çizimi
            return _buildCompassUI(tema, _smoothHeading, _qiblaFixedAngle, kalanAci);
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
            Text(
              "Kıbleye Kalan Açı: ${kalanAci.toStringAsFixed(1)}°",
              style: TextStyle(
                color: tema.yaziRengi.withOpacity(0.7),
                fontSize: Responsive.sp(14),
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: Responsive.h(40)),
            Stack(
              alignment: Alignment.center,
              children: [
                // 1. Pusula Diski: Cihazın yumuşatılmış yönüne (-smoothCompassHeading) göre dönerek N'yi Kuzeye sabitler
                Transform.rotate(
                  angle: (smoothCompassHeading * (pi / 180) * -1),
                  child: _buildCompassDisk(tema, qiblaFixedAngle),
                ),
              ],
            ),
            _handleVibration(kalanAci),
            SizedBox(height: Responsive.h(40)),
            _buildStatusIndicator(tema, kalanAci),
          ],
        ),
      ),
    );
  }

  // Diskin ta kendisi + İçindeki İğne
  Widget _buildCompassDisk(tema, double qiblaFixedAngle) {
    return SizedBox(
      width: Responsive.w(320),
      height: Responsive.w(320),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Derece Çizgileri
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
          Positioned(top: 0, child: Text("N", style: TextStyle(color: tema.anaRenk, fontWeight: FontWeight.bold, fontSize: Responsive.sp(24)))),
          Positioned(bottom: 0, child: Text("S", style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(20)))),
          Positioned(right: 0, child: Text("E", style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(20)))),
          Positioned(left: 0, child: Text("W", style: TextStyle(color: tema.yaziRengi, fontWeight: FontWeight.bold, fontSize: Responsive.sp(20)))),
          
          // İç Çerçeve (Diske sabitlenmiş)
          Container(
            width: Responsive.w(240),
            height: Responsive.w(240),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: tema.anaRenk.withOpacity(0.2), width: 2),
            ),
          ),
          
          // 2. Kıble İğnesi (Diske Entegre Ok)
          // İğne dışarıda değil, diskin üzerinde. Sabit 'qiblaFixedAngle' yönüne döndürüldüğünde, disk cihazla dışarıdan döndükçe, o da Kabe'ye şaşmaz şekilde kilitlenir!
          Transform.rotate(
            // İkon %45 derece eğik tasarımdadır (- pi/4 rotasyonu simgeyi tam 0 noktasına bakar hale getirir)
            angle: (qiblaFixedAngle * (pi / 180)) - (pi / 4),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.navigation_rounded,
                  size: Responsive.w(150),
                  color: tema.anaRenk,
                ),
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
    );
  }

  Widget _handleVibration(double kalanAci) {
    if (kalanAci < 3.0 && !_vibratedTarget) {
      // Hedefe girildi
      Future.microtask(() {
        if (mounted) {
          setState(() => _vibratedTarget = true);
          HapticFeedback.lightImpact();
        }
      });
    } else if (kalanAci >= 3.0 && _vibratedTarget) {
      // Hedef dışına çıkıldı
      Future.microtask(() {
        if (mounted) setState(() => _vibratedTarget = false);
      });
    }
    return const SizedBox.shrink();
  }

  Widget _buildStatusIndicator(tema, double kalanAci) {
    bool onTarget = kalanAci < 3.0;
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
            style: TextStyle(
              color: onTarget ? tema.anaRenk : tema.yaziRengi,
              fontWeight: FontWeight.bold,
              fontSize: Responsive.sp(16),
            ),
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

  @override
  void dispose() {
    _qiblahSub?.cancel();
    FlutterQiblah().dispose();
    super.dispose();
  }
}