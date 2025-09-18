import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/variants/variant_list_page.dart';
import 'features/variants/variant_detail_page.dart';
import 'features/account/account_page.dart';
import 'auth/auth_controller.dart';

/// Stream -> Listenable köprüsü: stream bir olay yayınlayınca router'ı yeniler.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}

GoRouter appRouter(WidgetRef ref) {
  // StateNotifier<AuthState> => notifier.stream (Stream<AuthState>)
  final authStream = ref.read(authControllerProvider.notifier).stream;

  return GoRouter(
    refreshListenable: GoRouterRefreshStream(authStream),
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const VariantListPage(),
        routes: [
          GoRoute(
            path: 'variant/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return VariantDetailPage(articleId: id);
            },
          ),
          GoRoute(
            path: 'account',
            builder: (context, state) => const AccountPage(),
          ),
        ],
      ),
    ],
  );
}
