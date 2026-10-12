// App Store 5.1.1(v) — Hesabım → Hesabımı Sil ekranı.
//
// Onay kelimesi yazılmadan silme düğmesi kapalı; mağaza aboneliği varsa
// "hesap silmek aboneliği iptal etmez" uyarısı ve "Aboneliği Yönet"; Apple
// girişinde Apple Kimliği notu; web aboneliğinde iptal notu; hata ve başarı.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/auth/auth_controller.dart';
import 'package:anatolian_coins/src/auth/auth_repository.dart';
import 'package:anatolian_coins/src/features/account/account_deletion_api.dart';
import 'package:anatolian_coins/src/features/account/account_deletion_service.dart';
import 'package:anatolian_coins/src/features/account/delete_account_screen.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

class _FakeRepo implements AuthRepository {
  _FakeRepo(this.sub);

  final String sub;

  @override
  Future<AuthTokens?> load() async => AuthTokens(accessToken: 'tok', email: 'a@b.c', sub: sub);

  @override
  Future<AuthTokens?> ensureFresh(AuthTokens? current, {bool force = false}) async => current;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeService implements AccountDeletionService {
  _FakeService(this.result);

  final AccountDeletionResult result;
  int calls = 0;

  @override
  Future<AccountDeletionResult> deleteAccount() async {
    calls++;
    return result;
  }
}

final _submit = find.byKey(DeleteAccountScreen.submitKey);
final _field = find.byKey(DeleteAccountScreen.confirmFieldKey);

bool _enabled(WidgetTester tester) =>
    tester.widget<ButtonStyleButton>(_submit).onPressed != null;

Future<AppLocalizations> _pump(
  WidgetTester tester, {
  String sub = 'auth0|x',
  ManagedStore? store,
  bool web = false,
  AccountDeletionService? service,
  Locale locale = const Locale('tr'),
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);

  final router = GoRouter(initialLocation: '/delete-account', routes: [
    GoRoute(path: '/', builder: (_, __) => const Scaffold(body: Text('ana-sayfa'))),
    GoRoute(path: '/delete-account', builder: (_, __) => const DeleteAccountScreen()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(_FakeRepo(sub))),
      activeStoreSubscriptionProvider.overrideWith((ref) async => store),
      webSubscriptionActiveProvider.overrideWith((ref) => web),
      if (service != null) accountDeletionServiceProvider.overrideWithValue(service),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('tr')],
    ),
  ));
  await tester.pumpAndSettle();
  return AppLocalizations.of(tester.element(find.byType(DeleteAccountScreen)));
}

Future<void> _tapSubmit(WidgetTester tester) async {
  await tester.ensureVisible(_submit);
  await tester.pumpAndSettle();
  await tester.tap(_submit);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('onay kelimesi yazılmadan düğme kapalı; "sil" yazınca açılır', (tester) async {
    final l10n = await _pump(tester);
    expect(find.text(l10n.translate('delete_account_removed_title')), findsOneWidget);
    expect(find.text(l10n.translate('delete_account_kept_title')), findsOneWidget);
    expect(_enabled(tester), isFalse);

    await tester.enterText(_field, 'si');
    await tester.pump();
    expect(_enabled(tester), isFalse);

    await tester.enterText(_field, 'sil'); // küçük harf + noktalı i kabul
    await tester.pump();
    expect(_enabled(tester), isTrue);

    await tester.enterText(_field, 'DELETE'); // İngilizce kelime Türkçe arayüzde geçmez
    await tester.pump();
    expect(_enabled(tester), isFalse);
  });

  testWidgets('İngilizce arayüzde onay kelimesi DELETE', (tester) async {
    final l10n = await _pump(tester, locale: const Locale('en'));
    expect(l10n.translate('delete_account_confirm_word'), 'DELETE');
    await tester.enterText(_field, 'delete');
    await tester.pump();
    expect(_enabled(tester), isTrue);
  });

  testWidgets('App Store aboneliği: iptal edilmez uyarısı + Aboneliği Yönet', (tester) async {
    final l10n = await _pump(tester, store: ManagedStore.appStore);
    expect(find.text(l10n.translate('delete_account_store_sub_title')), findsOneWidget);
    expect(find.text(l10n.translate('delete_account_store_sub_app_store')), findsOneWidget);
    expect(find.text(l10n.translate('delete_account_store_sub_play')), findsNothing);
    expect(find.text(l10n.translate('manage_subscription')), findsOneWidget);
  });

  testWidgets('Google Play aboneliği: Play metni', (tester) async {
    final l10n = await _pump(tester, store: ManagedStore.playStore);
    expect(find.text(l10n.translate('delete_account_store_sub_play')), findsOneWidget);
    expect(find.text(l10n.translate('delete_account_store_sub_app_store')), findsNothing);
  });

  testWidgets('mağaza aboneliği yoksa uyarı yok; Apple ve web notları yalnız gerekince',
      (tester) async {
    final l10n = await _pump(tester);
    expect(find.text(l10n.translate('delete_account_store_sub_title')), findsNothing);
    expect(find.text(l10n.translate('manage_subscription')), findsNothing);
    expect(find.text(l10n.translate('delete_account_apple_note')), findsNothing);
    expect(find.text(l10n.translate('delete_account_web_sub_note')), findsNothing);
  });

  testWidgets('Apple ile giriş: Apple Kimliği notu; web aboneliği: iptal notu', (tester) async {
    final l10n = await _pump(tester, sub: 'apple|001234.abc', web: true);
    expect(find.text(l10n.translate('delete_account_apple_note')), findsOneWidget);
    expect(find.text(l10n.translate('delete_account_web_sub_note')), findsOneWidget);
  });

  testWidgets('502: "hiçbir şey silinmedi" mesajı, düğme yeniden denemeye açık', (tester) async {
    final service = _FakeService(const AccountDeletionResult(AccountDeletionStatus.auth0Failed));
    final l10n = await _pump(tester, service: service);
    await tester.enterText(_field, 'SİL');
    await tester.pump();
    await _tapSubmit(tester);

    expect(service.calls, 1);
    expect(find.text(l10n.translate('delete_account_error_retry')), findsOneWidget);
    expect(find.byType(DeleteAccountScreen), findsOneWidget);
    expect(_enabled(tester), isTrue);
  });

  testWidgets('429: bekleme süresi dakika olarak', (tester) async {
    final service = _FakeService(const AccountDeletionResult(AccountDeletionStatus.rateLimited,
        retryAfterSeconds: 120));
    final l10n = await _pump(tester, service: service);
    await tester.enterText(_field, 'sil');
    await tester.pump();
    await _tapSubmit(tester);

    expect(
        find.text(l10n.translate('delete_account_error_rate_limited', params: {'minutes': '2'})),
        findsOneWidget);
  });

  testWidgets('başarı: Ana Sayfa\'ya döner, "Hesabınız silindi" bildirimi', (tester) async {
    final service = _FakeService(const AccountDeletionResult(AccountDeletionStatus.deleted));
    final l10n = await _pump(tester, service: service);
    await tester.enterText(_field, 'sil');
    await tester.pump();
    await _tapSubmit(tester);

    expect(service.calls, 1);
    expect(find.text('ana-sayfa'), findsOneWidget);
    expect(find.byType(DeleteAccountScreen), findsNothing);
    expect(find.text(l10n.translate('delete_account_done')), findsOneWidget);

    // Bildirimin zamanlayıcısı bitsin (test sonunda bekleyen zamanlayıcı kalmasın)
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
