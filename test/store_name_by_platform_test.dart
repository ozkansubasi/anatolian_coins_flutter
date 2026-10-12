// Mağaza adı platforma göre (App Store 2.3.10): iOS'ta "App Store", Android'de
// "Google Play". Metnin iOS karşılığı `<anahtar>_ios` anahtarında durur;
// AppLocalizations.translateForPlatform onu seçer, yasal sayfalar ve abonelik
// yönetimi penceresi bunu kullanır.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/legal/subscription_agreement_page.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

Map<String, String> _table(String lang) =>
    (jsonDecode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>)
        .cast<String, String>();

Future<AppLocalizations> _pumpAgreement(WidgetTester tester, TargetPlatform platform) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: platform),
    locale: const Locale('tr'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('tr')],
    home: const SubscriptionAgreementPage(),
  ));
  await tester.pumpAndSettle();
  final l10n = AppLocalizations.of(tester.element(find.byType(SubscriptionAgreementPage)));
  // Ödeme bölümü kapalı başlar: başlığa dokunup aç
  final title = find.text(l10n.translate('sub_payment_title'));
  await tester.scrollUntilVisible(title, 200, scrollable: find.byType(Scrollable).first);
  await tester.tap(title);
  await tester.pumpAndSettle();
  return l10n;
}

void main() {
  group('translateForPlatform', () {
    final l10n = AppLocalizations(const Locale('tr'), const {
      'store': 'Google Play',
      'store_ios': 'App Store',
      'plain': 'ortak',
    });

    test('iOS: _ios karşılığı varsa o', () {
      expect(l10n.translateForPlatform('store', TargetPlatform.iOS), 'App Store');
    });

    test('Android: temel anahtar', () {
      expect(l10n.translateForPlatform('store', TargetPlatform.android), 'Google Play');
    });

    test('iOS karşılığı yoksa temel anahtar', () {
      expect(l10n.translateForPlatform('plain', TargetPlatform.iOS), 'ortak');
    });
  });

  for (final lang in AppLocalizations.supportedLocales.map((l) => l.languageCode)) {
    test('$lang: her _ios metninin temel anahtarı var, iOS metninde Google Play geçmez', () {
      final table = _table(lang);
      final iosKeys = table.keys.where((k) => k.endsWith('_ios'));
      expect(iosKeys, isNotEmpty);
      for (final key in iosKeys) {
        final base = key.substring(0, key.length - 4);
        // subscription_auto_renew_ios / _android çifti kendi seçimini yapar
        if (base == 'subscription_auto_renew') continue;
        expect(table.containsKey(base), isTrue, reason: key);
        expect(table[key], isNot(contains('Google Play')), reason: key);
        expect(table[key], isNot(contains('Play Store')), reason: key);
        expect(table[key], contains('App Store'), reason: key);
        expect(table[base], isNot(contains('App Store')), reason: base);
      }
    });
  }

  testWidgets('Abonelik Sözleşmesi iOS\'ta App Store maddesini gösterir', (tester) async {
    final l10n = await _pumpAgreement(tester, TargetPlatform.iOS);
    expect(find.text(l10n.translate('sub_payment_1_ios')), findsOneWidget);
    expect(find.text(l10n.translate('sub_payment_1')), findsNothing);
  });

  testWidgets('Abonelik Sözleşmesi Android\'de Google Play maddesini gösterir', (tester) async {
    final l10n = await _pumpAgreement(tester, TargetPlatform.android);
    expect(find.text(l10n.translate('sub_payment_1')), findsOneWidget);
    expect(find.text(l10n.translate('sub_payment_1_ios')), findsNothing);
  });
}
