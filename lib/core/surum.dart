import 'package:flutter/services.dart';

/// Uygulamanın hangi sürümle derlendiği (android/app/build.gradle.kts → productFlavors).
///
/// - `deneme`: geliştiricinin telefonundaki test sürümü ("Takva Yolum Test"). Kablosuz güncelleme
///   ve Ramazan önizlemesi gibi test araçları yalnızca bunda vardır. `./publish.sh` bunu derler.
/// - `yayin`: Play Store'a giden kullanıcı sürümü. Test araçları görünmez.
bool get denemeSurumu => appFlavor == 'deneme';
