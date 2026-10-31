import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/constants/app_colors.dart';
import '../core/utils/responsive.dart';
import '../services/namaz_servis.dart';

class Cami {
  final String ad;
  final LatLng konum;
  final double mesafe; // metre
  const Cami(this.ad, this.konum, this.mesafe);
}

/// Yakındaki camiler: OpenStreetMap verisi (Overpass API), API anahtarı gerektirmez
class CamilerScreen extends StatefulWidget {
  const CamilerScreen({super.key});

  @override
  State<CamilerScreen> createState() => _CamilerScreenState();
}

class _CamilerScreenState extends State<CamilerScreen> {
  static const int _yaricap = 3000; // metre
  final MapController _harita = MapController();
  LatLng? _ben;
  List<Cami> _camiler = [];
  String? _hata;
  bool _yukleniyor = true;

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  Future<void> _yukle() async {
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      final pos = await NamazServisi().konumGetir(izinIste: true);
      if (pos == null) throw Exception('Konum izni verilmedi.');
      final ben = LatLng(pos.latitude, pos.longitude);
      final camiler = await _camileriGetir(ben);
      if (!mounted) return;
      setState(() {
        _ben = ben;
        _camiler = camiler;
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.toString().replaceFirst('Exception: ', '');
        _yukleniyor = false;
      });
    }
  }

  Future<List<Cami>> _camileriGetir(LatLng ben) async {
    final sorgu = '[out:json][timeout:20];('
        'node["amenity"="place_of_worship"]["religion"="muslim"](around:$_yaricap,${ben.latitude},${ben.longitude});'
        'way["amenity"="place_of_worship"]["religion"="muslim"](around:$_yaricap,${ben.latitude},${ben.longitude});'
        ');out center 60;';
    final cevap = await http
        .post(Uri.parse('https://overpass-api.de/api/interpreter'), body: {'data': sorgu})
        .timeout(const Duration(seconds: 25));
    if (cevap.statusCode != 200) throw Exception('Cami bilgisi alınamadı (${cevap.statusCode}).');
    final ogeler = (json.decode(utf8.decode(cevap.bodyBytes))['elements'] as List).cast<Map<String, dynamic>>();
    final liste = <Cami>[];
    for (final o in ogeler) {
      final lat = (o['lat'] ?? o['center']?['lat']) as num?;
      final lon = (o['lon'] ?? o['center']?['lon']) as num?;
      if (lat == null || lon == null) continue;
      final ad = (o['tags']?['name'] as String?) ?? 'Cami';
      final mesafe = Geolocator.distanceBetween(ben.latitude, ben.longitude, lat.toDouble(), lon.toDouble());
      liste.add(Cami(ad, LatLng(lat.toDouble(), lon.toDouble()), mesafe));
    }
    liste.sort((a, b) => a.mesafe.compareTo(b.mesafe));
    return liste;
  }

  Future<void> _yolTarifi(Cami c) async {
    final url = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${c.konum.latitude},${c.konum.longitude}&travelmode=walking');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Harita uygulaması açılamadı.')));
    }
  }

  String _mesafe(double m) => m < 1000 ? '${m.round()} m' : '${(m / 1000).toStringAsFixed(1)} km';

  @override
  Widget build(BuildContext context) {
    Responsive.init(context);
    final r = context.renkler;
    return Scaffold(
      backgroundColor: r.arkaPlanRengi,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text("Yakındaki Camiler", style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.bold)),
        actions: [IconButton(icon: Icon(Icons.refresh_rounded, color: r.anaRenk), onPressed: _yukle)],
      ),
      body: _yukleniyor
          ? Center(child: CircularProgressIndicator(color: r.anaRenk))
          : _hata != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_off_rounded, color: r.pasifRenk, size: 48),
                        const SizedBox(height: 12),
                        Text(_hata!, textAlign: TextAlign.center, style: TextStyle(color: r.pasifRenk)),
                        const SizedBox(height: 12),
                        OutlinedButton(onPressed: _yukle, child: const Text("Tekrar Dene")),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.38,
                      child: FlutterMap(
                        mapController: _harita,
                        options: MapOptions(initialCenter: _ben!, initialZoom: 14.5),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.namaz_app',
                          ),
                          MarkerLayer(markers: [
                            Marker(
                              point: _ben!,
                              child: const Icon(Icons.my_location_rounded, color: Colors.blue, size: 26),
                            ),
                            for (final c in _camiler)
                              Marker(
                                point: c.konum,
                                width: 36,
                                height: 36,
                                child: GestureDetector(
                                  onTap: () => _yolTarifi(c),
                                  child: Icon(Icons.mosque_rounded, color: r.anaRenk, size: 30),
                                ),
                              ),
                          ]),
                          const RichAttributionWidget(attributions: [TextSourceAttribution('OpenStreetMap katkıcıları')]),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _camiler.isEmpty
                          ? Center(
                              child: Text("${_yaricap ~/ 1000} km içinde kayıtlı cami bulunamadı.",
                                  style: TextStyle(color: r.pasifRenk)))
                          : ListView.builder(
                              itemCount: _camiler.length,
                              itemBuilder: (_, i) {
                                final c = _camiler[i];
                                return ListTile(
                                  leading: Icon(Icons.mosque_rounded, color: r.anaRenk),
                                  title: Text(c.ad, style: TextStyle(color: r.yaziRengi, fontWeight: FontWeight.w600)),
                                  subtitle: Text(_mesafe(c.mesafe), style: TextStyle(color: r.pasifRenk)),
                                  trailing: IconButton(
                                    tooltip: "Yol tarifi",
                                    icon: Icon(Icons.directions_walk_rounded, color: r.anaRenk),
                                    onPressed: () => _yolTarifi(c),
                                  ),
                                  onTap: () => _harita.move(c.konum, 16.5),
                                );
                              },
                            ),
                    ),
                  ],
                ),
    );
  }
}
