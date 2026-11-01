// Önizleme yakınlaştırması: iki parmak görseli büyütür, tam ölçekte tek parmak yüz değiştirir,
// yakınken sayfa kaymaz, geri küçültünce başa döner.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:anatolian_coins/src/features/recognition/prokit_image_preview_screen.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

void main() {
  late Directory dir;
  late String on;
  late String ark;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('zoom_test');
    final im = img.Image(width: 300, height: 600);
    on = '${dir.path}/on.jpg';
    ark = '${dir.path}/ark.jpg';
    File(on).writeAsBytesSync(img.encodeJpg(im));
    File(ark).writeAsBytesSync(img.encodeJpg(im));
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  Future<void> pumpScreen(WidgetTester tester, dynamic data) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ProkitImagePreviewScreen(imageData: data),
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> pinch(WidgetTester tester, Offset center, double from, double to) async {
    final a = await tester.startGesture(center - Offset(from, 0), pointer: 1);
    final b = await tester.startGesture(center + Offset(from, 0), pointer: 2);
    await tester.pump();
    for (var i = 1; i <= 6; i++) {
      final d = from + (to - from) * i / 6;
      await a.moveTo(center - Offset(d, 0));
      await b.moveTo(center + Offset(d, 0));
      await tester.pump();
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
  }

  InteractiveViewer viewerOf(WidgetTester tester) =>
      tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).first);

  double scaleOf(WidgetTester tester) =>
      viewerOf(tester).transformationController!.value.getMaxScaleOnAxis();

  testWidgets('iki parmak yakınlaştırır, ipucu kalkar; küçültünce başa döner', (tester) async {
    await pumpScreen(tester, on);
    expect(find.text('İki parmağınızı kullanarak sikke görselini yakınlaştırın'), findsOneWidget);
    expect(viewerOf(tester).panEnabled, isFalse);

    final center = tester.getCenter(find.byType(InteractiveViewer).first);
    await pinch(tester, center, 40, 120);
    expect(scaleOf(tester), greaterThan(1.5));
    expect(find.text('İki parmağınızı kullanarak sikke görselini yakınlaştırın'), findsNothing);
    expect(viewerOf(tester).panEnabled, isTrue);

    await pinch(tester, center, 120, 10);
    expect(scaleOf(tester), 1);
    expect(viewerOf(tester).panEnabled, isFalse);
    expect(find.text('İki parmağınızı kullanarak sikke görselini yakınlaştırın'), findsOneWidget);
  });

  testWidgets('tam ölçekte tek parmak diğer yüze geçer; yakınken sayfa kaymaz', (tester) async {
    await pumpScreen(tester, <String, dynamic>{'obverse': on, 'reverse': ark});
    final page = find.byType(PageView);
    final controller = tester.widget<PageView>(page).controller!;
    expect(controller.page, 0);

    await tester.fling(page, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 1);

    await tester.fling(page, const Offset(300, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 0);

    final center = tester.getCenter(find.byType(InteractiveViewer).first);
    await pinch(tester, center, 40, 120);
    expect(scaleOf(tester), greaterThan(1.5));
    expect(tester.widget<PageView>(page).physics, isA<NeverScrollableScrollPhysics>());

    await tester.fling(page, const Offset(-300, 0), 1000);
    await tester.pumpAndSettle();
    expect(controller.page, 0);
  });
}
