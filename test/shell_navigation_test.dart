// Alt çubuk kabuğu (StatefulShellRoute) davranış testi.
//
// Gerçek NumShellScaffold + NumBottomNav, yer tutucu sayfalarla. Dal sırası
// app_router.dart ile aynı: Ana Sayfa, Keşfet, Tara, Favoriler, Menü.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/core/navigation.dart';
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
        // Gerçek ekranlardaki gibi: sekme kökünde başka yerden gelinmişse geri oku.
        appBar: AppBar(leading: context.returnLeading),
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

    test('sikke detayı açıldığı sekmede kalır', () {
      expect(navTabFor('/variant/12', 3), NavTab.favorites);
      expect(navTabFor('/variant/12', 0), NavTab.home);
      expect(navTabFor('/variant/12', 1), NavTab.browse);
    });

    test('diğer ekranlar hangi sekmenin üstünde açılırsa açılsın evini gösterir', () {
      expect(navTabFor('/account', 0), NavTab.menu);
      expect(navTabFor('/settings', 3), NavTab.menu);
      expect(navTabFor('/assistant', 1), NavTab.menu);
      expect(navTabFor('/regions', 3), NavTab.menu, reason: 'cihazda Favoriler görünüyordu');
      expect(navTabFor('/article/5', 0), NavTab.menu);
      expect(navTabFor('/collections', 0), NavTab.favorites);
      expect(navTabFor('/history', 4), NavTab.favorites);
      // eşleşme yol parçasına bakar, önek değil
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

  testWidgets('sistem geri tuşu: önce sekme içi, sekme kökünde Ana Sayfa', (tester) async {
    final router = await _pumpApp(tester);

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    router.push('/variant/7');
    await tester.pumpAndSettle();
    expect(find.text('variant:0'), findsOneWidget);

    // 1) sekme içindeki detay kapanır
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('scan:0'), findsOneWidget);

    // 2) Tara kökünde uygulamadan çıkılmaz, Ana Sayfa'ya dönülür
    final handled = await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('home:0'), findsOneWidget);
    expect(_isSelected(tester, 'Home'), isTrue);
    expect(router.state.uri.path, '/');
    expect(handled, isTrue);
  });

  testWidgets('openRoute: Menü sayfası Ana Sayfa dalına yapışmaz', (tester) async {
    final router = await _pumpApp(tester);
    final ctx = tester.element(find.text('home:0'));

    // Ana Sayfa'dan Menü'ye ait bir ekran: kendi dalında (go) açılmalı.
    ctx.openRoute('/account');
    await tester.pumpAndSettle();
    expect(find.text('account:0'), findsOneWidget);
    expect(_isSelected(tester, 'Menu'), isTrue);

    // Keşfet → Ana Sayfa: Ana Sayfa gelmeli, hesap sayfası DEĞİL (cihazda böyleydi).
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('home:0'), findsOneWidget);
    expect(router.state.uri.path, '/');

    // Sikke detayı her sekmeye ait: bulunulan sekmenin üstüne biner (push).
    tester.element(find.text('home:0')).openRoute('/variant/3');
    await tester.pumpAndSettle();
    expect(find.text('variant:0'), findsOneWidget);
    expect(_isSelected(tester, 'Home'), isTrue);
    router.pop();
    await tester.pumpAndSettle();
    expect(find.text('home:0'), findsOneWidget);
  });

  testWidgets('başka sekmede açılan ekranın geri oku geldiği yere döner', (tester) async {
    final router = await _pumpApp(tester);

    // Ana Sayfa → Menü'ye ait ekran (go): kökte açılır ama geri oku olmalı.
    tester.element(find.text('home:0')).openRoute('/account');
    await tester.pumpAndSettle();
    expect(find.text('account:0'), findsOneWidget);
    expect(router.state.uri.queryParameters['from'], '/');
    expect(find.byType(BackButton), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('home:0'), findsOneWidget);
    expect(router.state.uri.path, '/');

    // Sekmeye alt çubuktan gelinince (from yok) geri oku YOK.
    await tester.tap(find.text('Browse'));
    await tester.pumpAndSettle();
    expect(find.text('browse:0'), findsOneWidget);
    expect(find.byType(BackButton), findsNothing);
  });

  testWidgets('bulunulan sekmeye tekrar basmak köke döner', (tester) async {
    final router = await _pumpApp(tester);
    router.push('/variant/9');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home'));
    await tester.pumpAndSettle();
    expect(find.text('home:0'), findsOneWidget);
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
