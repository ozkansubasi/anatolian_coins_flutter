// App Store 3.1.2(a): abonelik sayfasında satın alma seçeneklerinin altında
// otomatik yenileme koşulu (mağazaya göre) ve Kullanım Koşulları / Gizlilik
// Politikası bağlantıları görünmeli; adresler uygulama diline göre seçilir.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/core/web_links.dart';
import 'package:anatolian_coins/src/features/subscription/subscription_legal_notice.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

Future<AppLocalizations> _pump(
    WidgetTester tester, TargetPlatform platform, Locale locale) async {
  late AppLocalizations l10n;
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(platform: platform),
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: const [Locale('en'), Locale('tr')],
    home: Scaffold(
      body: Builder(builder: (context) {
        l10n = AppLocalizations.of(context);
        return const SubscriptionLegalNotice();
      }),
    ),
  ));
  await tester.pumpAndSettle();
  return l10n;
}

void main() {
  testWidgets('iOS: App Store yenileme koşulu + iki bağlantı', (tester) async {
    final l10n = await _pump(tester, TargetPlatform.iOS, const Locale('tr'));
    expect(find.text(l10n.translate('subscription_auto_renew_ios')), findsOneWidget);
    expect(find.text(l10n.translate('subscription_auto_renew_android')), findsNothing);
    expect(find.text(l10n.translate('terms_of_service')), findsOneWidget);
    expect(find.text(l10n.translate('privacy_policy')), findsOneWidget);
    expect(l10n.translate('subscription_auto_renew_ios'), contains('24'));
  });

  testWidgets('Android: Google Play yenileme koşulu + iki bağlantı', (tester) async {
    final l10n = await _pump(tester, TargetPlatform.android, const Locale('en'));
    expect(find.text(l10n.translate('subscription_auto_renew_android')), findsOneWidget);
    expect(find.text(l10n.translate('subscription_auto_renew_ios')), findsNothing);
    expect(find.text(l10n.translate('terms_of_service')), findsOneWidget);
    expect(find.text(l10n.translate('privacy_policy')), findsOneWidget);
  });

  test('yasal sayfa adresleri dile göre (2026-10-13 ikisi de 200)', () {
    expect(termsOfUseWebUrl('tr').toString(), 'https://www.numistr.org/tr/kullanim-kosullari');
    expect(termsOfUseWebUrl('en').toString(), 'https://www.numistr.org/en/terms-of-use');
    expect(privacyPolicyWebUrl('tr').toString(),
        'https://www.numistr.org/tr/kvkk-ve-gizlilik-politikasi');
    expect(privacyPolicyWebUrl('en').toString(), 'https://www.numistr.org/en/privacy-policy-gdpr');
  });
}
