import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/utils/responsive.dart';

/// Bir bölümü (başlık + içerik) tek bir zemine oturtan kart. Arka plan
/// görselinin üstünde başlıklar, seçiciler ve listeler havada durmasın diye.
class BolumPaneli extends StatelessWidget {
  const BolumPaneli({
    super.key,
    required this.children,
    this.margin,
    this.padding,
    this.crossAxisAlignment = CrossAxisAlignment.stretch,
  });

  final List<Widget> children;
  final EdgeInsetsGeometry? margin;
  final EdgeInsetsGeometry? padding;
  final CrossAxisAlignment crossAxisAlignment;

  @override
  Widget build(BuildContext context) {
    final r = context.renkler;
    return Container(
      margin: margin ?? EdgeInsets.symmetric(horizontal: Responsive.w(12), vertical: Responsive.h(8)),
      padding: padding ?? EdgeInsets.symmetric(vertical: Responsive.h(6)),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: r.kartRengi,
        borderRadius: BorderRadius.circular(Responsive.w(24)),
        border: Border.all(color: r.anaRenk.withOpacity(0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: crossAxisAlignment,
        children: children,
      ),
    );
  }
}

extension PanelRenkleri on AppThemeColors {
  /// Panelin içindeki satır ve kartların zemini: kart renginden bir ton koyu,
  /// tamamen opak (arka plan içinden görünmez)
  Color get icYuzey => Color.alphaBlend(anaRenk.withOpacity(0.05), kartRengi);

  /// [renk]'i verilen saydamlıkla kart renginin üstüne karıştırır (opak sonuç)
  Color kartUstunde(Color renk, double opaklik) => Color.alphaBlend(renk.withOpacity(opaklik), kartRengi);
}
