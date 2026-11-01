// AI14: sunucu ilk turda doğrulayamazsa sikkeyi farklı açılarla yeniden arar, tarama ~14 sn sürer.
// Bekleme metni 8 saniyede bunu söyler; yanıt gelip ekran kapanınca zamanlayıcı temizlenir.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/recognition/prokit_recognition_results_screen.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

void main() {
  Widget app(Locale locale, Widget child) => MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(body: child),
      );

  testWidgets('8 saniyede ikinci metne geçer', (tester) async {
    await tester.pumpWidget(app(const Locale('tr'), const ScanProgressMessage()));
    await tester.pumpAndSettle();
    expect(find.text('Sikke analiz ediliyor...'), findsOneWidget);

    await tester.pump(const Duration(seconds: 7));
    expect(find.text('Sikke analiz ediliyor...'), findsOneWidget);
    expect(find.text('Sikke farklı açılardan karşılaştırılıyor...'), findsNothing);

    await tester.pump(const Duration(seconds: 2));
    expect(find.text('Sikke analiz ediliyor...'), findsNothing);
    expect(find.text('Sikke farklı açılardan karşılaştırılıyor...'), findsOneWidget);
    expect(find.text('Bu birkaç saniye daha sürebilir'), findsOneWidget);
  });

  testWidgets('İngilizce metin', (tester) async {
    await tester.pumpWidget(app(const Locale('en'), const ScanProgressMessage()));
    await tester.pumpAndSettle();
    await tester.pump(ScanProgressMessage.secondStageAfter);
    expect(find.text('Comparing the coin from different angles...'), findsOneWidget);
  });

  testWidgets('yanıt erken gelirse zamanlayıcı iptal edilir', (tester) async {
    await tester.pumpWidget(app(const Locale('tr'), const ScanProgressMessage()));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpWidget(app(const Locale('tr'), const SizedBox()));
    await tester.pump(const Duration(seconds: 10)); // bekleyen zamanlayıcı kalsaydı test bozulurdu
    expect(find.text('Sikke farklı açılardan karşılaştırılıyor...'), findsNothing);
  });
}
