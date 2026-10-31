import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

/// Profil fotoğrafı varsa onu, yoksa ismin baş harfini gösteren yuvarlak avatar.
/// Fotoğraf "data:image/...;base64,..." (uygulamada yüklenen) ya da http adresi olabilir.
class ProfilAvatar extends StatelessWidget {
  final String? photoUrl;
  final String isim;
  final double radius;
  final Color arkaPlan;
  final Color yaziRengi;

  const ProfilAvatar({
    super.key,
    required this.photoUrl,
    required this.isim,
    required this.radius,
    required this.arkaPlan,
    required this.yaziRengi,
  });

  // Aynı fotoğraf her rebuild'de yeniden çözülmesin
  static final Map<String, Uint8List> _onbellek = {};

  static ImageProvider? gorsel(String? url) {
    if (url == null || url.isEmpty) return null;
    if (url.startsWith('data:image')) {
      try {
        final bytes = _onbellek.putIfAbsent(url, () => base64Decode(url.substring(url.indexOf(',') + 1)));
        if (_onbellek.length > 100) _onbellek.remove(_onbellek.keys.first);
        return MemoryImage(bytes);
      } catch (_) {
        return null;
      }
    }
    if (url.startsWith('http')) return NetworkImage(url);
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final foto = gorsel(photoUrl);
    return CircleAvatar(
      radius: radius,
      backgroundColor: arkaPlan,
      backgroundImage: foto,
      child: foto != null
          ? null
          : Text(
              isim.isNotEmpty ? isim[0].toUpperCase() : "?",
              style: TextStyle(color: yaziRengi, fontWeight: FontWeight.bold, fontSize: radius * 0.8),
            ),
    );
  }
}
