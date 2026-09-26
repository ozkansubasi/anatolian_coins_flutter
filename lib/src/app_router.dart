import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/app_log.dart';
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
import 'features/auth/register_screen.dart';
import 'features/legal/legal.dart';
import 'features/assistant/assistant_screen.dart';
import 'prokit_ui/widgets/num_bottom_nav.dart';

/// Stream -> Listenable köprüsü: stream bir olay yayınlayınca router'ı yeniler.
class GoRouterRefreshStream extends ChangeNotifier {
  late final StreamSubscription<dynamic> _sub;
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _sub = stream.asBroadcastStream().listen((_) => notifyListeners());
  }
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}

/// Alt çubuğun dalları. Sıra [NumBottomNav] ile birebir aynıdır.
///
/// Kural (2026-09-21): başka sekmelerden de açılan ekranlar (sikke detayı,
/// makale, koleksiyon, Menü sayfaları) bir dala AİT olsa da `context.push` ile
/// açılır. go_router bu durumda sayfayı bulunulan sekmenin ÜSTÜNE koyar: alt
/// çubuk görünür kalır, sekme değişmez, geri tuşu doğru yere döner. `go` ise
/// sahibi olan sekmeye atlar ve geri dönüş kalmaz (ölçüldü: go_router 14.8.1).
enum ShellBranch { home, browse, scan, favorites, menu }

/// Tek yönlendirici örneği. Eskiden kök widget her yeniden çizildiğinde
/// `appRouter(ref)` yeni bir GoRouter kuruyordu: dil ya da tema değişince
/// (ve her hot reload'da) gezinme geçmişi sıfırlanıp Ana Sayfa'ya dönülüyordu
/// (2026-09-26 cihaz incelemesi).
final appRouterProvider = Provider<GoRouter>((ref) => appRouter());

GoRouter appRouter() {
  // ❌ REMOVED: GoRouter refresh on auth changes causes navigation loops
  // Each page handles its own auth state with ref.watch()

  final router = GoRouter(
    // No refreshListenable - pages manage their own auth state
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            NumShellScaffold(navigationShell: navigationShell),
        branches: [
          // --- Ana Sayfa ---
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const ProkitHomeScreen(),
            ),
          ]),

          // --- Keşfet ---
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/browse',
              builder: (context, state) => const ProkitVariantListPage(),
            ),
            GoRoute(
              path: '/variant/:id',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return ProkitVariantDetailPage(articleId: id);
              },
            ),
          ]),

          // --- Tara ---
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/recognition',
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
          ]),

          // --- Favoriler (koleksiyonlar ve tarama geçmişi de burada) ---
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/favorites',
              builder: (context, state) => const FavoritesPage(),
            ),
            GoRoute(
              path: '/collections',
              builder: (context, state) => const CollectionsPage(),
            ),
            GoRoute(
              path: '/collection/:id',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return CollectionDetailPage(collectionId: id);
              },
            ),
            GoRoute(
              path: '/history',
              builder: (context, state) => const HistoryPage(),
            ),
          ]),

          // --- Menü: alt çubukta hedefi yok (Menü bir alt sayfa açar), ama
          // bu rotalar kabuğun içinde kalsın diye bir dala bağlı. ---
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/account',
              builder: (context, state) => const AccountScreen(),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => const SettingsScreen(),
            ),
            GoRoute(
              path: '/assistant',
              builder: (context, state) => AssistantScreen(
                initialQuestion: state.uri.queryParameters['q'],
              ),
            ),
            GoRoute(
              path: '/regions',
              builder: (context, state) => const RegionsListPage(),
            ),
            GoRoute(
              path: '/mints',
              builder: (context, state) => const MintsListPage(),
            ),
            GoRoute(
              path: '/blog',
              builder: (context, state) => const ProkitBlogListScreen(),
            ),
            GoRoute(
              path: '/article/:id',
              builder: (context, state) {
                final id = int.tryParse(state.pathParameters['id'] ?? '') ?? 0;
                return ProkitArticleDetailScreen(articleId: id);
              },
            ),
            GoRoute(
              path: '/login',
              builder: (context, state) => const LoginScreen(),
            ),
            GoRoute(
              path: '/register',
              builder: (context, state) => const RegisterScreen(),
            ),
            GoRoute(
              path: '/subscription',
              builder: (context, state) => const ProkitSubscriptionPage(),
            ),
            GoRoute(
              path: '/university-application',
              builder: (context, state) => const ProkitUniversityFormScreen(),
            ),
            // Legal pages
            GoRoute(
              path: '/terms-of-service',
              builder: (context, state) => const TermsOfServicePage(),
            ),
            GoRoute(
              path: '/privacy-policy',
              builder: (context, state) => const PrivacyPolicyPage(),
            ),
            GoRoute(
              path: '/kvkk',
              builder: (context, state) => const KvkkPage(),
            ),
            GoRoute(
              path: '/subscription-agreement',
              builder: (context, state) => const SubscriptionAgreementPage(),
            ),
          ]),
        ],
      ),
    ],
  );
  // Ekran geçişleri hata günlüğüne: bir hatanın hangi ekranda çıktığı görünsün.
  String? last;
  router.routerDelegate.addListener(() {
    final loc = router.routerDelegate.currentConfiguration.uri.toString();
    if (loc != last) appLog('NAV', last = loc);
  });
  return router;
}
