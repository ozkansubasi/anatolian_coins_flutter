// Oturumsuz deneme hakkı bitince (M17) kamera ekranındaki pencere: metin hesap
// açmaya davet ediyor (kullanıcı metni, 2026-10-12), düğme de "Hesap Aç" olup
// kayıt ekranını açmalı. Hak okunamıyorsa eski "Giriş Yap" penceresi kalır.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/features/recognition/prokit_camera_screen.dart';
import 'package:anatolian_coins/src/features/recognition/recognition_service.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

import 'helpers/fake_camera.dart';

Future<void> _settle(WidgetTester tester) async {
  // Nabız animasyonu sürekli döner; pumpAndSettle bitmez.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _pump(WidgetTester tester, Future<ScanQuota> Function() quota) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final router = GoRouter(initialLocation: '/recognition', routes: [
    GoRoute(path: '/recognition', builder: (_, __) => const ProkitCameraScreen()),
    GoRoute(path: '/register', builder: (_, __) => const Text('kayit-ekrani')),
    GoRoute(path: '/login', builder: (_, __) => const Text('giris-ekrani')),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [scanQuotaProvider.overrideWith((ref) => quota())],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('tr'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('tr')],
    ),
  ));
  await _settle(tester);
}

void main() {
  setUp(() {
    FakeCameraPlatform.install();
    FlutterSecureStorage.setMockInitialValues({}); // oturum yok
  });

  testWidgets('deneme bitti: hesap açma daveti, "Hesap Aç" kayıt ekranını açar', (tester) async {
    await _pump(
        tester,
        () async => ScanQuota(
            used: 3, limit: 3, remaining: 0, isPro: false, isAnonymous: true, trialEnabled: true));

    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settle(tester);

    expect(find.text('Sikke taramaya devam etmek için hesap açabilirsiniz'), findsOneWidget);
    expect(find.textContaining('her ay 10 sikke taraması'), findsOneWidget);
    expect(find.text('Giriş Yap'), findsNothing);

    await tester.tap(find.text('Hesap Aç'));
    await _settle(tester);
    expect(find.text('kayit-ekrani'), findsOneWidget);
  });

  testWidgets('deneme hakkı okunamıyorsa giriş penceresi kalır', (tester) async {
    await _pump(tester, () async => throw Exception('ağ yok'));

    await tester.tap(find.byIcon(Icons.camera_alt));
    await _settle(tester);

    expect(find.text('Hesap Aç'), findsNothing);
    await tester.tap(find.text('Giriş Yap'));
    await _settle(tester);
    expect(find.text('giris-ekrani'), findsOneWidget);
  });
}
