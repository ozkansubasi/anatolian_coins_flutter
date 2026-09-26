// M1 regresyonu: abonelik sayfasındaki "işleniyor" penceresi kapanmalı.
//
// Sayfa StatefulShellRoute dalında açılır (app_router.dart ile aynı yapı);
// pencere kök navigator'a açıldığı için sayfanın `Navigator.of(context)`'i
// onu kapatamıyordu. Gerçek sayfa + gerçek SubscriptionController, mağaza
// tarafı sahte.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:anatolian_coins/src/core/api_client.dart';
import 'package:anatolian_coins/src/core/revenuecat_service.dart';
import 'package:anatolian_coins/src/core/subscription_provider.dart';
import 'package:anatolian_coins/src/features/subscription/prokit_subscription_page.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

/// Geri yükleme sonucunu test elle bitirir.
class _FakeRevenueCat implements RevenueCatService {
  Completer<PurchaseOutcome> restore = Completer();
  int restoreCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<CustomerInfo?> getCustomerInfo() async => null;

  @override
  Future<Offerings?> getOfferings() async => null;

  @override
  Future<PurchaseOutcome> restorePurchases() {
    restoreCalls++;
    return restore.future;
  }

  @override
  void addCustomerInfoListener(void Function(CustomerInfo) listener) {}

  @override
  void removeCustomerInfoListener(void Function(CustomerInfo) listener) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Backend çağrısı hata verir; controller bunu "Pro değil" sayar.
class _FakeApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeRevenueCat> _pumpSubscriptionInShell(WidgetTester tester) async {
  final rc = _FakeRevenueCat();
  final router = GoRouter(
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, __, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, _) => Scaffold(
                body: TextButton(
                  onPressed: () => context.push('/subscription'),
                  child: const Text('home'),
                ),
              ),
            ),
            GoRoute(
              path: '/subscription',
              builder: (_, __) => const ProkitSubscriptionPage(),
            ),
          ]),
        ],
      ),
    ],
  );

  await tester.pumpWidget(ProviderScope(
    overrides: [
      subscriptionProvider.overrideWith(
        (ref) => SubscriptionController(rc, _FakeApi()),
      ),
      offeringsProvider.overrideWith((ref) async => null),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      locale: const Locale('en'),
      localizationsDelegates: const [AppLocalizations.delegate],
      supportedLocales: const [Locale('en'), Locale('tr')],
    ),
  ));
  await tester.pumpAndSettle();

  await tester.tap(find.text('home'));
  await tester.pumpAndSettle();
  expect(find.byType(ProkitSubscriptionPage), findsOneWidget);
  return rc;
}

void main() {
  testWidgets('geri yükleme bitince pencere kapanır, sayfa yerinde kalır',
      (tester) async {
    final rc = await _pumpSubscriptionInShell(tester);

    await tester.tap(find.byIcon(Icons.restore));
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);

    rc.restore.complete(PurchaseOutcome(success: true, isPro: false));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ProkitSubscriptionPage), findsOneWidget);
  });

  testWidgets('hata sonucunda da pencere kapanır', (tester) async {
    final rc = await _pumpSubscriptionInShell(tester);

    await tester.tap(find.byIcon(Icons.restore));
    await tester.pump();

    rc.restore.completeError(Exception('ağ yok'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(ProkitSubscriptionPage), findsOneWidget);
  });

  testWidgets('işlem sürerken geri tuşu pencereyi kapatmaz', (tester) async {
    final rc = await _pumpSubscriptionInShell(tester);

    await tester.tap(find.byIcon(Icons.restore));
    await tester.pump();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(rc.restoreCalls, 1);

    rc.restore.complete(PurchaseOutcome(success: true, isPro: false));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
