// Kalınlıklar gerçekten uygulanıyor mu? (2026-11-24 font incelemesi)
//
// Eskiden Inter google_fonts ile her ağırlık ayrı aile adıyla (Inter_regular, Inter_700…)
// yükleniyordu; temadan aile miras alan kalın stiller (NumText, boldTextStyle, yazı h2)
// normal kesimle çiziliyordu. Gömülü tek `Inter` ailesiyle kalın metin normalden geniş olur.
// Test gerçek yazı tipi dosyalarını yükler; ölçüm genişlik üzerinden yapılır.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;

import 'package:anatolian_coins/src/core/app_theme.dart';
import 'package:anatolian_coins/src/core/app_typography.dart';
import 'package:anatolian_coins/src/core/num_text.dart';

const _sample = 'Palaiskepsis Sikkeleri';

Future<void> _loadInter() async {
  final loader = FontLoader(AppTheme.fontFamily);
  for (final f in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/inter/Inter-$f.ttf'));
  }
  await loader.load();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await _loadInter();
    initNumistrTypography();
  });

  test('pubspec Inter ailesini 400/500/600/700 olarak gömer; dosyalar yerinde', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- family: Inter'));
    for (final (file, weight) in const [
      ('Inter-Regular', 400),
      ('Inter-Medium', 500),
      ('Inter-SemiBold', 600),
      ('Inter-Bold', 700),
    ]) {
      expect(pubspec, contains('assets/fonts/inter/$file.ttf\n          weight: $weight'));
      expect(File('assets/fonts/inter/$file.ttf').lengthSync(), greaterThan(250000));
    }
    expect(File('assets/fonts/inter/OFL.txt').readAsStringSync(), contains('The Inter Project Authors'));
  });

  test('kodda GoogleFonts.inter yok (her ağırlığı ayrı aile yapar)', () {
    final hits = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && f.readAsStringSync().contains('GoogleFonts.inter('))
        .map((f) => f.path)
        .toList();
    expect(hits, isEmpty);
  });

  test('tema metin stilleri gömülü Inter ailesini kullanır', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final t = theme.textTheme;
      for (final s in [t.bodyMedium, t.bodyLarge, t.titleLarge, t.titleSmall, t.labelLarge]) {
        expect(s?.fontFamily, AppTheme.fontFamily);
      }
      expect(theme.appBarTheme.titleTextStyle?.fontFamily, AppTheme.fontFamily);
    }
  });

  testWidgets('temadan aile miras alan kalın stiller gerçekten kalın çizilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Builder(builder: (context) {
          final nt = context.numText;
          return Column(children: [
            // Aynı punto, farklı ağırlık; aile verilmiyor (temadan miras).
            const Text(_sample, key: Key('w400'), style: TextStyle(fontSize: 20)),
            const Text(_sample, key: Key('w600'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const Text(_sample, key: Key('w700'), style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            // NumText.pageTitle (20/700) ve aynı stilin normal ağırlıklısı (harf aralığı -0,2 dahil).
            Text(_sample, key: const Key('pageTitle'), style: nt.pageTitle),
            Text(_sample, key: const Key('pageTitle400'), style: nt.pageTitle.copyWith(fontWeight: FontWeight.w400)),
            // nb_utils (ProKit) stilleri: 18 kalın ve 18 normal.
            Text(_sample, key: const Key('bold18'), style: boldTextStyle(size: 18)),
            Text(_sample, key: const Key('primary18'), style: primaryTextStyle(size: 18)),
          ]);
        }),
      ),
    ));
    double w(String k) => tester.getSize(find.byKey(Key(k))).width;

    expect(w('w600'), greaterThan(w('w400') * 1.02), reason: 'w600 normal kesimle çiziliyor');
    expect(w('w700'), greaterThan(w('w600')), reason: 'w700, w600 ile aynı');
    expect(w('pageTitle'), greaterThan(w('pageTitle400') * 1.02), reason: 'NumText.pageTitle kalın değil');
    expect(w('bold18'), greaterThan(w('primary18') * 1.02), reason: 'boldTextStyle kalın değil');
  });

  testWidgets('yazı içeriğindeki h2 gövdeden kalın çizilir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: Scaffold(
        body: Column(children: [
          SizedBox(
            key: const Key('h2'),
            child: IntrinsicWidth(
              child: Html(data: '<h2>$_sample</h2>', style: {
                'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
                'h2': Style(fontSize: FontSize(20), fontWeight: FontWeight.bold, margin: Margins.zero),
              }),
            ),
          ),
          SizedBox(
            key: const Key('p'),
            child: IntrinsicWidth(
              child: Html(data: '<p>$_sample</p>', style: {
                'body': Style(margin: Margins.zero, padding: HtmlPaddings.zero),
                'p': Style(fontSize: FontSize(20), margin: Margins.zero),
              }),
            ),
          ),
        ]),
      ),
    ));
    final h2 = tester.getSize(find.byKey(const Key('h2'))).width;
    final p = tester.getSize(find.byKey(const Key('p'))).width;
    expect(h2, greaterThan(p * 1.02), reason: 'h2 gövdeyle aynı kalınlıkta');
  });
}
