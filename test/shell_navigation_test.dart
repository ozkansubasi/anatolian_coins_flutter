// Alt çubuk kabuğu (StatefulShellRoute) davranış testi.
//
// Gerçek NumShellScaffold + NumBottomNav, yer tutucu sayfalarla. Dal sırası
// app_router.dart ile aynı: Ana Sayfa, Keşfet, Tara, Favoriler, Menü.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/l10n/app_localizations.dart';
import 'package:anatolian_coins/src/prokit_ui/widgets/num_bottom_nav.dart';

class _CounterPage extends StatefulWidget {
  final String name;
  const _CounterPage(this.name);

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _n = 0;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: TextButton(
          onPressed: () => setState(() => _n++),
          child: Text('${widget.name}:$_n'),
        ),
      );
}

GoRoute _page(String path, String name) =>
    GoRoute(path: path, builder: (_, __) => _CounterPage(name));

GoRouter _router() => GoRouter(
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => NumShellScaffold(navigationShell: shell),
          branches: [
            StatefulShellBranch(routes: [_page('/', 'home')]),
            StatefulShellBranch(routes: [
              _page('/browse', 'browse'),
              _page('/variant/:id', 'variant'),
            ]),
            StatefulShellBranch(routes: [_page('/recognition', 'scan')]),
            StatefulShellBranch(routes: [_page('/favorites', 'favorites')]),
            StatefulShellBranch(routes: [_page('/account', 'account')]),
          ],
        ),
      ],
    );

Future<GoRouter> _pumpApp(WidgetTester tester) async {
  final router = _router();
  await tester.pumpWidget(MaterialApp.router(
    routerConfig: router,
    locale: const Locale('en'),
    localizationsDelegates: const [AppLocalizations.delegate],
    supportedLocales: const [Locale('en'), Locale('tr')],
  ));
  await tester.pumpAndSettle();
  return router;
}

bool _isSelected(WidgetTester tester, String label) =>
    tester.widget<Text>(find.text(label)).style?.fontWeight == FontWeight.w600;

void main() {
  group('navTabFor', () {
    test('dal indeksi sekmeyi belirler', () {
      expect(navTabFor('/', 0), NavTab.home);
      expect(navTabFor('/browse', 1), NavTab.browse);
      expect(navTabFor('/recognition/results', 2), NavTab.scan);
      expect(navTabFor('/collection/3', 3), NavTab.favorites);
    });

    test('paylaşılan detay açıldığı sekmede kalır', () {
      expect(navTabFor('/variant/12', 3), NavTab.favorites);
      expect(navTabFor('/article/5', 0), NavTab.home);
    });

    test('Menü sayfaları hangi sekmenin üstünde olursa olsun Menü', () {
      expect(navTabFor('/account', 0), NavTab.menu);
      expect(navTabFor('/settings', 3), NavTab.menu);
      expect(navTabFor('/assistant', 1), NavTab.menu);
      // önek eşleşmesi yol sınırına bakar
      expect(navTabFor('/accounting', 0), NavTab.home);
    });
  });

  testWidgets('push edilen detayda alt çubuk görünür, geri dönüş çalışır', (tester) async {
    final router = await _pumpApp(tester);
    expect(find.text('home:0'), findsOneWidget);

    router.push('/variant/1');
    await tester.pumpAndSettle();
    expect(find.text('variant:0'), findsOneWidget);
    expect(find.text('Browse'), findsOneWidget, reason: 'alt çubuk detayda da var');
    expect(_isSelected(tester, 'Home'), isTrue, reason: 'açıldığı sekme seçili kalır');

    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home:0'), findsOneWidget);
  });

  testWidgets('sekmeler arası geçişte sekme durumu korunur', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('browse:0'));
    await tester.pump();
    await tester.tap(find.text('browse:1'));
    await tester.pump();
    expect(find.text('browse:2'), findsOneWidget);

    await tester.tap(find.text('Favorites'));
    await tester.pumpAndSettle();
    expect(_isSelected(tester, 'Favorites'), isTrue);

    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('browse:2'), findsOneWidget, reason: 'IndexedStack durumu korur');
  });

  testWidgets('Menü sayfası açıkken Menü seçili görünür', (tester) async {
    final router = await _pumpApp(tester);
    router.push('/account');
    await tester.pumpAndSettle();
    expect(_isSelected(tester, 'Menu'), isTrue);
    expect(_isSelected(tester, 'Home'), isFalse);
  });

  testWidgets('klavye açıkken alt çubuk gizlenir', (tester) async {
    await _pumpApp(tester);
    expect(find.text('Browse'), findsOneWidget);

    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(find.text('Browse'), findsNothing);
  });
}
