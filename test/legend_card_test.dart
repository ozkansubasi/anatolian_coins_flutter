// AI15: lejant kartı yazıyı ve adı gösterir, yapay zekâ uyarısı hep görünür.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/recognition/prokit_recognition_results_screen.dart';
import 'package:anatolian_coins/src/features/recognition/recognition_service.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

void main() {
  Future<void> kur(WidgetTester tester, LegendReading l, String dil) async {
    await tester.pumpWidget(MaterialApp(
      locale: Locale(dil),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(builder: (c) => LegendCard(legend: l, l10n: AppLocalizations.of(c))),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('iki yüz, Türkçe ad ve uyarı', (tester) async {
    await kur(
      tester,
      const LegendReading(
          obverse: 'IMP C CLAVDIVS AVG', reverse: 'MARTI PACIF', person: 'Claudius II', personTr: 'II. Claudius'),
      'tr',
    );
    expect(find.text('Sikkenin üzerindeki yazı'), findsOneWidget);
    expect(find.textContaining('IMP C CLAVDIVS AVG'), findsOneWidget);
    expect(find.textContaining('MARTI PACIF'), findsOneWidget);
    expect(find.text('II. Claudius'), findsOneWidget);
    expect(find.text('Yapay zekâ okumasıdır, kesin değildir.'), findsOneWidget);
  });

  testWidgets('yazı temiz değilse başlık çıkmaz, ad ve uyarı kalır', (tester) async {
    await kur(tester, const LegendReading(person: 'Antiochus'), 'en');
    expect(find.text('Inscription on the coin'), findsNothing);
    expect(find.text('Antiochus'), findsOneWidget);
    expect(find.text('Read by AI, may not be accurate.'), findsOneWidget);
  });
}
