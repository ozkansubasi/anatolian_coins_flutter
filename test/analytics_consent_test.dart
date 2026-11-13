// Firebase Analytics onayı (Prime NT-261112-01321879 / -015431th, 12 Kas 2026).
// Sınanan: onay kaydı, Firebase'siz derlemede sessizlik, benzerlik kovası,
// onay penceresinin iki düğmesinin aynı biçimde olması ve kararı döndürmesi.
import 'package:firebase_core/firebase_core.dart';
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

  // 13 Kas 2026 iOS bulgusu: Firebase başlar başlamaz (toplama kapalıyken bile) Installations
  // kaydı gidiyordu → Firebase yalnız onayla başlar.
  group('Firebase yalnız onayla başlar', () {
    const opts = FirebaseOptions(
        apiKey: 'k', appId: '1:1:ios:1', messagingSenderId: '1', projectId: 'p');
    late int starts;
    Future<AppAnalytics> make(SharedPreferences prefs) => AppAnalytics.init(prefs,
        options: opts, starter: (_) async {
      starts++;
      return null;
    });

    setUp(() {
      starts = 0;
      SharedPreferences.setMockInitialValues({});
    });

    test('karar yokken başlamaz; onay penceresi yine sorulur', () async {
      final a = await make(await SharedPreferences.getInstance());
      expect(a.isAvailable, isTrue);
      expect(a.consent, AnalyticsConsent.unknown);
      expect(a.started, isFalse);
      expect(starts, 0);
    });

    test('"İzin verme" → hiç başlamaz; sonraki açılışta da başlamaz', () async {
      final prefs = await SharedPreferences.getInstance();
      final a = await make(prefs);
      await a.setConsent(false);
      expect(starts, 0);
      final again = await make(prefs);
      expect(again.started, isFalse);
      expect(starts, 0);
    });

    test('"İzin ver" → bir kez başlar; tekrar onay yeniden başlatmaz', () async {
      final a = await make(await SharedPreferences.getInstance());
      await a.setConsent(true);
      expect(a.started, isTrue);
      expect(starts, 1);
      await a.setConsent(false);
      await a.setConsent(true);
      expect(starts, 1);
    });

    test('daha önce onay verilmişse açılışta başlar', () async {
      SharedPreferences.setMockInitialValues({'flutter.${AppAnalytics.consentPrefKey}': 'granted'});
      final a = await make(await SharedPreferences.getInstance());
      expect(a.started, isTrue);
      expect(starts, 1);
    });

    test('başlatma hatası uygulamayı düşürmez; olaylar sessizce düşer', () async {
      final a = await AppAnalytics.init(await SharedPreferences.getInstance(),
          options: opts, starter: (_) async => throw Exception('yok'));
      await a.setConsent(true);
      expect(a.started, isTrue);
      await a.screenView('/');
      await a.viewItem(1);
    });
  });

  // 14 Kas 2026 kullanıcı kararı: iOS'ta ATT yok → reklam sinyalleri hep kapalı (ADPLA §3.3.3(E)).
  test('onay sinyalleri: iOS\'ta reklam hep kapalı, Android\'de onayla açık, kişiselleştirme hep kapalı', () {
    final iosOn = AppAnalytics.consentSignals(granted: true, ios: true);
    expect(iosOn.analytics, isTrue);
    expect(iosOn.ads, isFalse);
    expect(iosOn.personalization, isFalse);

    final androidOn = AppAnalytics.consentSignals(granted: true, ios: false);
    expect(androidOn.analytics, isTrue);
    expect(androidOn.ads, isTrue);
    expect(androidOn.personalization, isFalse);

    for (final ios in [true, false]) {
      final off = AppAnalytics.consentSignals(granted: false, ios: ios);
      expect([off.analytics, off.ads, off.personalization], everyElement(isFalse));
    }
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
