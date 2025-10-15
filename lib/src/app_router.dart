import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/variants/variant_list_page.dart';
import 'features/variants/variant_detail_page.dart';
import 'features/account/account_page.dart';
import 'features/subscription/subscription_page.dart';
import 'features/recognition/camera_screen.dart';
import 'features/recognition/image_preview_screen.dart';
import 'features/recognition/recognition_results_screen.dart';
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
          GoRoute(
            path: 'subscription',
            builder: (context, state) => const SubscriptionPage(),
          ),
          GoRoute(
            path: 'recognition',
            builder: (context, state) => const CameraScreen(),
            routes: [
              GoRoute(
                path: 'preview',
                builder: (context, state) {
                  final imagePath = state.extra as String;
                  return ImagePreviewScreen(imagePath: imagePath);
                },
              ),
              GoRoute(
                path: 'results',
                builder: (context, state) {
                  final imagePath = state.extra as String;
                  return RecognitionResultsScreen(imagePath: imagePath);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}