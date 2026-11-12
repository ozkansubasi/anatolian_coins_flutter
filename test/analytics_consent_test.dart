// Firebase Analytics onayı (Prime NT-261112-01321879 / -015431th, 12 Kas 2026).
// Sınanan: onay kaydı, Firebase'siz derlemede sessizlik, benzerlik kovası,
// onay penceresinin iki düğmesinin aynı biçimde olması ve kararı döndürmesi.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anatolian_coins/src/core/analytics/app_analytics.dart';
import 'package:anatolian_coins/src/core/analytics/consent_prompt.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppAnalytics (Firebase yapılandırması yok = dev/test)', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('env/firebase.json verilmeyince Firebase başlamaz', () async {
      final a = await AppAnalytics.init(await SharedPreferences.getInstance());
      expect(a.isAvailable, isFalse);
      expect(FirebaseEnv.currentPlatformOptions(), isNull);
    });

    test('ilk açılışta karar yok; karar kalıcı', () async {
      final prefs = await SharedPreferences.getInstance();
      final a = await AppAnalytics.init(prefs);
      expect(a.consent, AnalyticsConsent.unknown);

      await a.setConsent(true);
      expect(a.consent, AnalyticsConsent.granted);
      expect(prefs.getString(AppAnalytics.consentPrefKey), 'granted');

      await a.setConsent(false);
      expect(a.consent, AnalyticsConsent.denied);

      // Yeniden açılış: karar okunur, pencere tekrar sorulmaz.
      final again = await AppAnalytics.init(prefs);
      expect(again.consent, AnalyticsConsent.denied);
    });

    test('Firebase yokken olaylar sessizce düşer', () async {
      final a = await AppAnalytics.init(await SharedPreferences.getInstance());
      await a.setConsent(true);
      await a.recognitionComplete(
          candidateCount: 5, noMatch: false, uncertain: true, sides: 2, modernCoin: false, topConfidence: 0.42);
      await a.screenView('/variant/:id');
      await a.viewItem(30671);
      await a.purchase(productId: 'pro_annual', value: 39.99, currency: 'USD');
    });
  });

  test('benzerlik kovası (sunucu ölçeği 0–1)', () {
    expect(AppAnalytics.scoreBucket(null), 'none');
    expect(AppAnalytics.scoreBucket(0.35), '0-40');
    expect(AppAnalytics.scoreBucket(0.55), '40-60');
    expect(AppAnalytics.scoreBucket(0.79), '60-80');
    expect(AppAnalytics.scoreBucket(0.8), '80-100');
    expect(AppAnalytics.scoreBucket(1.0), '80-100');
  });

  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('onay penceresi (${locale.languageCode}): iki düğme aynı biçim, karar döner',
        (tester) async {
      bool? result;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          locale: locale,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('tr')],
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async => result = await showModalBottomSheet<bool>(
                  context: context,
                  isDismissible: false,
                  enableDrag: false,
                  isScrollControlled: true,
                  builder: (_) => const AnalyticsConsentSheet(),
                ),
                child: const Text('ac'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ac'));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(tester.element(find.byType(AnalyticsConsentSheet)));
      final allow = find.widgetWithText(FilledButton, l10n.translate('analytics_consent_allow'));
      final deny = find.widgetWithText(FilledButton, l10n.translate('analytics_consent_deny'));
      expect(allow, findsOneWidget);
      expect(deny, findsOneWidget);
      // Çeviri anahtarı ham kalmamış olmalı.
      expect(find.textContaining('analytics_consent_'), findsNothing);

      // Dışarıya dokunmak kapatmaz (karar zorunlu).
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.byType(AnalyticsConsentSheet), findsOneWidget);

      await tester.tap(deny);
      await tester.pumpAndSettle();
      expect(result, isFalse);
      expect(find.byType(AnalyticsConsentSheet), findsNothing);
    });
  }
}
