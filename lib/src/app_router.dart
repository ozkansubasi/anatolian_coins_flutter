import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/home/prokit_home_screen.dart';
import 'features/variants/prokit_variant_list_page.dart';
import 'features/variants/prokit_variant_detail_page.dart';
import 'features/account/account_screen.dart';
import 'features/subscription/prokit_subscription_page.dart';
import 'features/subscription/prokit_university_form_screen.dart';
import 'features/recognition/prokit_camera_screen.dart';
import 'features/recognition/prokit_image_preview_screen.dart';
import 'features/recognition/prokit_recognition_results_screen.dart';
import 'features/settings/settings_screen.dart';
import 'features/articles/prokit_blog_list_screen.dart';
import 'features/articles/prokit_article_detail_screen.dart';
import 'features/explore/regions_list_page.dart';
import 'features/explore/mints_list_page.dart';
import 'features/favorites/favorites_page.dart';
import 'features/history/history_page.dart';
import 'features/collections/collections_page.dart';
import 'features/collections/collection_detail_page.dart';
import 'features/auth/login_screen.dart';
import 'features/legal/legal.dart';

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
  // ❌ REMOVED: GoRouter refresh on auth changes causes navigation loops
  // Each page handles its own auth state with ref.watch()

  return GoRouter(
    // No refreshListenable - pages manage their own auth state
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const ProkitHomeScreen(),
        routes: [
          GoRoute(
            path: 'browse',
            builder: (context, state) => const ProkitVariantListPage(),
          ),
          GoRoute(
            path: 'favorites',
            builder: (context, state) => const FavoritesPage(),
          ),
          GoRoute(
            path: 'history',
            builder: (context, state) => const HistoryPage(),
          ),
          GoRoute(
            path: 'collections',
            builder: (context, state) => const CollectionsPage(),
          ),
          GoRoute(
            path: 'collection/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return CollectionDetailPage(collectionId: id);
            },
          ),
          GoRoute(
            path: 'variant/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return ProkitVariantDetailPage(articleId: id);
            },
          ),
          GoRoute(
            path: 'blog',
            builder: (context, state) => const ProkitBlogListScreen(),
          ),
          GoRoute(
            path: 'regions',
            builder: (context, state) => const RegionsListPage(),
          ),
          GoRoute(
            path: 'mints',
            builder: (context, state) => const MintsListPage(),
          ),
          GoRoute(
            path: 'article/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
              return ProkitArticleDetailScreen(articleId: id);
            },
          ),
          GoRoute(
            path: 'account',
            builder: (context, state) => const AccountScreen(),
          ),
          GoRoute(
            path: 'login',
            builder: (context, state) => const LoginScreen(),
          ),
          GoRoute(
            path: 'subscription',
            builder: (context, state) => const ProkitSubscriptionPage(),
          ),
          GoRoute(
            path: 'university-application',
            builder: (context, state) => const ProkitUniversityFormScreen(),
          ),
          GoRoute(
            path: 'settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          // Legal pages
          GoRoute(
            path: 'terms-of-service',
            builder: (context, state) => const TermsOfServicePage(),
          ),
          GoRoute(
            path: 'privacy-policy',
            builder: (context, state) => const PrivacyPolicyPage(),
          ),
          GoRoute(
            path: 'kvkk',
            builder: (context, state) => const KvkkPage(),
          ),
          GoRoute(
            path: 'subscription-agreement',
            builder: (context, state) => const SubscriptionAgreementPage(),
          ),
          GoRoute(
            path: 'recognition',
            builder: (context, state) => const ProkitCameraScreen(),
            routes: [
              GoRoute(
                path: 'preview',
                builder: (context, state) {
                  // Can be String (single image) or Map (dual images)
                  final imageData = state.extra;
                  return ProkitImagePreviewScreen(imageData: imageData);
                },
              ),
              GoRoute(
                path: 'results',
                builder: (context, state) {
                  // Can be String (single image) or Map (dual images)
                  final imageData = state.extra;
                  return ProkitRecognitionResultsScreen(imageData: imageData);
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}