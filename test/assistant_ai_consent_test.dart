// AI Asistan — üçüncü taraf yapay zekâ izni (Apple 5.1.2(i), 14 Kas 2026).
// Mesajlar Google (Gemini) ve Anthropic'e (Claude) gider; ilk mesajdan önce açıkça söylenip
// izin alınır, verilmezse gönderilmez. Karar hesap silinince sıfırlanır.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anatolian_coins/src/features/assistant/assistant_ai_consent.dart';
import 'package:anatolian_coins/src/features/settings/settings_provider.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

Future<(AppLocalizations, List<bool>)> _pump(WidgetTester tester, SharedPreferences prefs,
    {Locale locale = const Locale('tr')}) async {
  final results = <bool>[];
  final router = GoRouter(routes: [
    GoRoute(
      path: '/',
      builder: (context, _) => Scaffold(
        body: TextButton(
          onPressed: () async => results.add(await ensureAssistantAiConsent(context, prefs)),
          child: const Text('gonder'),
        ),
      ),
    ),
    GoRoute(path: '/privacy-policy', builder: (_, __) => const Text('politika')),
  ]);
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: router,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('tr')],
  ));
  await tester.pumpAndSettle();
  return (AppLocalizations.of(tester.element(find.text('gonder'))), results);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final locale in const [Locale('tr'), Locale('en')]) {
    testWidgets('ilk mesajda pencere: sağlayıcılar adıyla yazıyor (${locale.languageCode})', (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final (l10n, _) = await _pump(tester, prefs, locale: locale);
      await tester.tap(find.text('gonder'));
      await tester.pumpAndSettle();

      expect(find.byType(AssistantAiConsentSheet), findsOneWidget);
      final body = l10n.translate('assistant_ai_consent_body');
      expect(body, contains('Google (Gemini)'));
      expect(body, contains('Anthropic (Claude)'));
      expect(find.text(body), findsOneWidget);
      expect(find.text(l10n.translate('assistant_ai_consent_photos')), findsOneWidget);
      expect(find.textContaining('assistant_ai_consent_'), findsNothing); // ham anahtar yok
    });
  }

  testWidgets('"Vazgeç" → gönderilmez, izin kaydedilmez, sonra yine sorulur', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final (l10n, results) = await _pump(tester, prefs);
    await tester.tap(find.text('gonder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.translate('assistant_ai_consent_decline')));
    await tester.pumpAndSettle();

    expect(results, [false]);
    expect(hasAssistantAiConsent(prefs), isFalse);

    await tester.tap(find.text('gonder'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantAiConsentSheet), findsOneWidget);
  });

  testWidgets('"Kabul et" → kaydedilir; bir daha sorulmaz', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final (l10n, results) = await _pump(tester, prefs);
    await tester.tap(find.text('gonder'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.translate('assistant_ai_consent_accept')));
    await tester.pumpAndSettle();

    expect(results, [true]);
    expect(prefs.getBool(SettingsKeys.assistantAiConsent), isTrue);

    await tester.tap(find.text('gonder'));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantAiConsentSheet), findsNothing);
    expect(results, [true, true]);
  });

  testWidgets('dışarı dokunup kapatmak = izin yok', (tester) async {
    final prefs = await SharedPreferences.getInstance();
    final (_, results) = await _pump(tester, prefs);
    await tester.tap(find.text('gonder'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(results, [false]);
    expect(hasAssistantAiConsent(prefs), isFalse);
  });

  test('uygulama içi politika asistanı ve sağlayıcıları anlatıyor (TR + EN)', () {
    for (final lang in ['tr', 'en']) {
      final j = jsonDecode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>;
      for (final k in ['pp_assistant_data_title', 'pp_assistant_data_content', 'pp_legal_basis_6', 'pp_retention_7']) {
        expect(j[k], isA<String>(), reason: '$lang $k');
      }
      for (final k in ['pp_assistant_data_content', 'pp_transfer_technical', 'pp_legal_basis_6']) {
        expect(j[k], contains('Gemini'), reason: '$lang $k');
        expect(j[k], contains('Anthropic'), reason: '$lang $k');
      }
    }
    final page = File('lib/src/features/legal/privacy_policy_page.dart').readAsStringSync();
    for (final k in ['pp_assistant_data_title', 'pp_legal_basis_6', 'pp_retention_7']) {
      expect(page, contains("'$k'"));
    }
  });

  test('izin hesap silinince sıfırlanan tercihler arasında', () {
    expect(SettingsKeys.userScoped, contains(SettingsKeys.assistantAiConsent));
  });

  test('asistan ekranı göndermeden önce izni denetliyor (kaynak denetimi)', () {
    final src = File('lib/src/features/assistant/assistant_screen.dart').readAsStringSync();
    final i = src.indexOf('Future<void> _send() async');
    final gate = src.indexOf('ensureAssistantAiConsent(', i);
    final send = src.indexOf('.send(text', i);
    expect(i, greaterThan(0));
    expect(gate, greaterThan(i));
    expect(send, greaterThan(gate), reason: 'izin denetimi API çağrısından önce olmalı');
  });
}
