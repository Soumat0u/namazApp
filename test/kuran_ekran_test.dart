import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:namaz_app/providers/theme_provider.dart';
import 'package:namaz_app/views/kuran_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in ['xyz.luan/audioplayers', 'xyz.luan/audioplayers.global']) {
      m.setMockMethodCallHandler(MethodChannel(ch), (_) async => null);
    }
    m.setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/path_provider'), (_) async => '.');
  });

  testWidgets('sure sayfasında ayar düğmesi okuma ayarlarını açar', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MaterialApp(home: KuranSureScreen(sure: 112)),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.byIcon(Icons.tune_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Meali göster'), findsOneWidget);
    expect(find.text('Okuma hızı'), findsOneWidget);
    await tester.tap(find.text('0.75x'));
    await tester.pumpAndSettle();
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getDouble('kuran_hiz'), 0.75);

    // Ayete dokununca açılan menü de çalışmalı
    Navigator.of(tester.element(find.text('Okuma hızı'))).pop();
    await tester.pumpAndSettle();
    await tester.longPress(find.text('1').first);
    await tester.pumpAndSettle();
    expect(find.text('Kaldığım yer olarak işaretle'), findsOneWidget);
  });
}
