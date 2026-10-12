// M18 (2026-10-10, cihaz gözlemi): Tara sekmesinden çıkınca kamera arka planda
// açık kalıyordu (`dumpsys media.camera` uygulamayı gösteriyordu). Sekmeler
// StatefulShellRoute ile ağaçta tutulur; kamera ekranı artık görünürlüğü
// (TickerMode) değişince kamerayı bırakır, yeniden görünür olunca açar.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/features/recognition/prokit_camera_screen.dart';
import 'package:anatolian_coins/src/features/recognition/recognition_service.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

import 'helpers/fake_camera.dart';

/// Nabız animasyonu sürekli döndüğü için pumpAndSettle bitmez; sayfa geçişi
/// (~300 ms) ve sahte kameranın açılışı için birkaç kare yeter.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<GoRouter> _pumpShell(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final router = GoRouter(initialLocation: '/recognition', routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => Scaffold(body: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/', builder: (_, __) => const Text('ana-sayfa')),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(
            path: '/recognition',
            builder: (_, __) => const ProkitCameraScreen(),
            routes: [
              GoRoute(
                path: 'preview',
                builder: (_, __) => const Scaffold(body: Text('onizleme')),
              ),
            ],
          ),
        ]),
      ],
    ),
  ]);

  await tester.pumpWidget(ProviderScope(
    overrides: [
      scanQuotaProvider.overrideWith(
          (ref) async => ScanQuota(used: 0, limit: 10, remaining: 10, isPro: false)),
    ],
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
  return router;
}

void main() {
  late FakeCameraPlatform camera;

  setUp(() => camera = FakeCameraPlatform.install());

  testWidgets('başka sekmeye geçince kamera bırakılır, dönünce yeniden açılır', (tester) async {
    final router = await _pumpShell(tester);
    expect(camera.open.values, [FakeCameraPlatform.back]);

    router.go('/');
    await _settle(tester);
    expect(find.text('ana-sayfa'), findsOneWidget);
    expect(camera.open, isEmpty);

    router.go('/recognition');
    await _settle(tester);
    expect(camera.open.values, [FakeCameraPlatform.back]);
    expect(camera.created, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('üstte önizleme sayfası açıkken kamera kapalı, geri dönünce açık', (tester) async {
    final router = await _pumpShell(tester);
    expect(camera.open, hasLength(1));

    router.push('/recognition/preview');
    await _settle(tester);
    expect(find.text('onizleme'), findsOneWidget);
    expect(camera.open, isEmpty);

    router.pop();
    await _settle(tester);
    expect(camera.open, hasLength(1));
  });

  testWidgets('kamera çevirme: eskisi bırakılır, yalnız ön kamera açık', (tester) async {
    await _pumpShell(tester);

    await tester.tap(find.byIcon(Icons.flip_camera_ios));
    await _settle(tester);
    expect(camera.open.values, [FakeCameraPlatform.front]);

    // Seçim sekme değişiminden sonra da korunur.
    await tester.tap(find.byIcon(Icons.flip_camera_ios));
    await _settle(tester);
    expect(camera.open.values, [FakeCameraPlatform.back]);
  });

  testWidgets('açılış sürerken sekme değişirse kamera açık kalmaz', (tester) async {
    final router = await _pumpShell(tester);
    router.go('/');
    await _settle(tester);

    // Dön ve açılış bitmeden hemen yeniden ayrıl.
    router.go('/recognition');
    await tester.pump();
    router.go('/');
    await _settle(tester);
    expect(camera.open, isEmpty);
  });
}
