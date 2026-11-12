// context.push ile açılan sayfa (sikke ayrıntısı, yazı) go_router'da ImperativeRouteMatch olarak
// durur ve RouteMatchList'in uri / fullPath'inden dışlanır; gezinme günlüğü ve analitik
// (screen_view, view_item) itilen sayfayı görmüyordu (cihaz, 13 Kas 2026).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/app_router.dart';

void main() {
  testWidgets('kabuk dalında push edilen sayfa en üst eşleşme olarak okunur', (tester) async {
    final router = GoRouter(initialLocation: '/browse', routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => Scaffold(body: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, __) => const Text('ana')),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/browse', builder: (_, __) => const Text('liste')),
            GoRoute(
              path: '/variant/:id',
              builder: (_, s) => Text('sikke ${s.pathParameters['id']}'),
            ),
          ]),
        ],
      ),
    ]);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    var top = topRouteMatches(router.routerDelegate.currentConfiguration);
    expect(top.fullPath, '/browse');

    router.push('/variant/3775');
    await tester.pumpAndSettle();
    expect(find.text('sikke 3775'), findsOneWidget);

    // Ham yapılandırma itilen sayfayı göstermez; yardımcı gösterir.
    expect(router.routerDelegate.currentConfiguration.fullPath, isNot('/variant/:id'));
    top = topRouteMatches(router.routerDelegate.currentConfiguration);
    expect(top.fullPath, '/variant/:id');
    expect(top.pathParameters['id'], '3775');
    expect(top.uri.path, '/variant/3775');

    router.pop();
    await tester.pumpAndSettle();
    expect(topRouteMatches(router.routerDelegate.currentConfiguration).fullPath, '/browse');
  });
}
