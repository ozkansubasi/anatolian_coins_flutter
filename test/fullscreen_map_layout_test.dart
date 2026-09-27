// Tam ekran harita yatay telefon boyutunda taşmadan çizilir (2026-09-26
// cihaz testi: başlık ekranın ~%20'si, kart + lejant çakışıyordu).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/map/ancient_map_widget.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

import 'helpers/fake_google_maps.dart';

/// Tam ekran haritayı kurar.
Future<void> _pumpMap(WidgetTester tester) async {
  await tester.pumpWidget(const ProviderScope(child: MaterialApp(
    locale: Locale('tr'),
    localizationsDelegates: [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: [Locale('tr'), Locale('en')],
    home: FullScreenAncientMapPage(coordinates: '39.49, 26.336', mintName: 'assos'),
  )));
  await tester.pump(const Duration(seconds: 1));
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUp(() {
    // Varlık önbelleği testler arasında temizlenir: önceki testin sahte zamanında
    // başlayan okuma önbellekte kalıyor, sonraki testte hiç tamamlanmıyordu
    // (harita yükleniyor çarkında kalıyordu).
    rootBundle.clear();
    FakeGoogleMapsPlatform.install();
  });

  testWidgets('yatay 844x390: taşma yok, başlık darphane adı, lejant kapalı', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpMap(tester);

    expect(tester.takeException(), isNull);
    // Başlık ham kod değil ('assos'); vurgulanan darphanenin kartı da açık → 2.
    expect(find.text('Assos'), findsNWidgets(2));
    expect(find.byType(AppBar), findsNothing);
    expect(find.text('Lejant'), findsNothing);

    // Lejantı aç: kart kapanır, lejant görünür (üst üste binmezler)
    await tester.tap(find.byIcon(Icons.info_outline));
    await tester.pump();
    expect(find.text('Lejant'), findsOneWidget);
    expect(find.text('Assos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('darphane kartında Pro güncel harita bağlantısı; ücretsizde abonelik penceresi', (tester) async {
    tester.view.physicalSize = const Size(844, 390);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await _pumpMap(tester);

    // Kart açık: bağlantı + PRO rozeti görünür, taşma yok
    expect(find.text('Güncel haritada göster'), findsOneWidget);
    expect(find.text('PRO'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Ücretsiz kullanıcı (isPro varsayılan false): dış bağlantı değil, Pro penceresi
    await tester.tap(find.text('Güncel haritada göster'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
