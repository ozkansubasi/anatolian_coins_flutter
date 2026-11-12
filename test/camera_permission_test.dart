// M39 (2026-11-12, kullanıcı gözlemi): iPhone'da kamera izni ilk soruda reddedilince
// ekran yalnız "Kamera başlatılamadı" + "Geri dön" gösteriyordu; iOS bir daha sormaz.
// Artık önizleme yerine açıklama + "Ayarları aç" (kısıtlıda yok) + "Galeriden seç";
// yuvalar ve galeri akışı açık; uygulamaya dönünce (resumed) kamera yeniden denenir.

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/features/recognition/prokit_camera_screen.dart';
import 'package:anatolian_coins/src/features/recognition/recognition_service.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

import 'helpers/fake_camera.dart';

/// İzin reddi taklidi: [denyCode] doluyken kamera açılışı CameraException atar.
class _DenyingCamera extends FakeCameraPlatform {
  String? denyCode;

  @override
  Future<int> createCameraWithSettings(
      CameraDescription cameraDescription, MediaSettings mediaSettings) async {
    if (denyCode != null) throw CameraException(denyCode!, 'izin yok');
    return super.createCameraWithSettings(cameraDescription, mediaSettings);
  }
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<AppLocalizations> _pump(WidgetTester tester, {Locale locale = const Locale('tr')}) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);

  final router = GoRouter(initialLocation: '/recognition', routes: [
    GoRoute(path: '/', builder: (_, __) => const Text('ana-sayfa')),
    GoRoute(path: '/recognition', builder: (_, __) => const ProkitCameraScreen()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      scanQuotaProvider.overrideWith(
          (ref) async => ScanQuota(used: 0, limit: 10, remaining: 10, isPro: false)),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
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
  return AppLocalizations.of(tester.element(find.byType(ProkitCameraScreen)));
}

void main() {
  late _DenyingCamera camera;

  setUp(() {
    camera = _DenyingCamera();
    CameraPlatform.instance = camera;
  });

  test('hata kodu → izin durumu', () {
    expect(cameraPermissionState('CameraAccessDenied'), 'denied');
    expect(cameraPermissionState('CameraAccessDeniedWithoutPrompt'), 'denied');
    expect(cameraPermissionState('CameraAccessRestricted'), 'restricted');
    expect(cameraPermissionState('cameraNotFound'), isNull);
    expect(cameraPermissionState('AudioAccessDenied'), isNull);
  });

  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('reddedilmiş izin (${locale.languageCode}): açıklama + Ayarlar + galeri, yuvalar duruyor',
        (tester) async {
      camera.denyCode = 'CameraAccessDeniedWithoutPrompt';
      final l10n = await _pump(tester, locale: locale);

      expect(find.text(l10n.translate('camera_permission_title')), findsOneWidget);
      expect(find.text(l10n.translate('camera_permission_body')), findsOneWidget);
      expect(find.text(l10n.translate('camera_permission_open_settings')), findsOneWidget);
      expect(find.text(l10n.translate('camera_permission_gallery')), findsOneWidget);
      // Eski çıkmaz ekran yok; ön/arka yüz yuvaları görünür.
      expect(find.text(l10n.translate('camera_error')), findsNothing);
      expect(find.text(l10n.translate('obverse')), findsWidgets);
      expect(find.text(l10n.translate('reverse')), findsWidgets);
      expect(find.textContaining('camera_permission_'), findsNothing);
      expect(camera.open, isEmpty);

      // Çekim düğmesi etkisiz: dokunmak hata atmaz, kamera açılmaz.
      await tester.tap(find.byIcon(Icons.camera_alt));
      await _settle(tester);
      expect(tester.takeException(), isNull);
      expect(camera.open, isEmpty);
    });
  }

  testWidgets('kısıtlı (Ekran Süresi): Ayarlar düğmesi yok, galeri var', (tester) async {
    camera.denyCode = 'CameraAccessRestricted';
    final l10n = await _pump(tester);
    expect(find.text(l10n.translate('camera_permission_restricted')), findsOneWidget);
    expect(find.text(l10n.translate('camera_permission_open_settings')), findsNothing);
    expect(find.text(l10n.translate('camera_permission_gallery')), findsOneWidget);
  });

  testWidgets('Ayarlar\'dan dönünce (resumed) kamera yeniden açılır', (tester) async {
    camera.denyCode = 'CameraAccessDenied';
    final l10n = await _pump(tester);
    expect(find.text(l10n.translate('camera_permission_title')), findsOneWidget);

    camera.denyCode = null; // kullanıcı Ayarlar'da izni açtı
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await _settle(tester);

    expect(camera.open.values, [FakeCameraPlatform.back]);
    expect(find.text(l10n.translate('camera_permission_title')), findsNothing);
  });

  testWidgets('izin dışı hata eskisi gibi genel hata ekranı', (tester) async {
    camera.denyCode = 'cameraNotFound';
    final l10n = await _pump(tester);
    expect(find.text(l10n.translate('camera_error')), findsOneWidget);
    expect(find.text(l10n.translate('camera_permission_title')), findsNothing);
  });
}
