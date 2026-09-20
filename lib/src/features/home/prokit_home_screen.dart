import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../core/region_data.dart';
import '../../prokit_ui/prokit_ui.dart';
import '../favorites/favorites_service.dart';
import '../articles/editors_pick_card.dart';

/// ProKit Style Dashboard - ShopHop Inspired Design
class ProkitHomeScreen extends ConsumerStatefulWidget {
  const ProkitHomeScreen({super.key});

  @override
  ConsumerState<ProkitHomeScreen> createState() => _ProkitHomeScreenState();
}

class _ProkitHomeScreenState extends ConsumerState<ProkitHomeScreen> {
  final PageController _bannerController = PageController();

  @override
  void dispose() {
    _bannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? numScaffoldDark : numScaffoldLight,
      appBar: _buildAppBar(context, l10n, isDark),
      body: _buildBody(context, l10n, authState),
      // 2026-09-20: dashboard kendi alt menu kopyasini tasiyordu (7 oge,
      // paylasilan widget'ta 6 vardi ve _NavItem iki dosyada kopyalanmisti).
      // Tek kaynak: NumBottomNav.
      bottomNavigationBar: const NumBottomNav(currentTab: NavTab.home),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, AppLocalizations l10n, bool isDark) {
    return AppBar(
      backgroundColor: isDark ? numCardDark : numCardLight,
      elevation: 0,
      scrolledUnderElevation: 1,
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon/app_icon.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: numPrimary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monetization_on, color: numPrimary, size: 20),
              ),
            ),
          ),
          8.width,
          Text(
            l10n.translate('app_name'),
            // Sayfa başlığı standardı: NumTypo.title (18), Inter w600
            style: boldTextStyle(size: 18, color: isDark ? Colors.white : numTextPrimary),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.search, color: isDark ? Colors.white : numTextPrimary),
          onPressed: () => context.go('/browse'),
          tooltip: l10n.translate('search'),
        ),
        IconButton(
          icon: Icon(Icons.notifications_outlined, color: isDark ? Colors.white : numTextPrimary),
          onPressed: () => _showComingSoon(context, l10n, 'Notifications'),
        ),
      ],
    );
  }

  Widget _buildBody(BuildContext context, AppLocalizations l10n, authState) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Hero Banner Carousel
          _buildBannerCarousel(context, l10n),

          // Region Categories (Horizontal)
          _buildRegionCategories(context, l10n),

          // Coin Recognition Card (Hero Action)
          _buildRecognitionCard(context, l10n, authState),

          // Quick Features Section
          _buildQuickFeatures(context, l10n),

          // Editor's Pick Section
          _buildEditorsPickSection(context, l10n),

          100.height, // Bottom padding
        ],
      ),
    );
  }

  /// Banner Carousel - ShopHop Style
  Widget _buildBannerCarousel(BuildContext context, AppLocalizations l10n) {
    final banners = [
      _BannerData(
        title: l10n.translate('banner_discover_title'),
        subtitle: l10n.translate('banner_discover_subtitle'),
        gradient: numGradientPrimary,
        icon: Icons.explore,
      ),
      _BannerData(
        title: l10n.translate('banner_ai_title'),
        subtitle: l10n.translate('banner_ai_subtitle'),
        gradient: numGradientSecondary,
        icon: Icons.camera_alt,
      ),
      _BannerData(
        title: l10n.translate('banner_collection_title'),
        subtitle: l10n.translate('banner_collection_subtitle'),
        gradient: numGradientAccent,
        icon: Icons.collections,
      ),
    ];

    return Container(
      height: 150,
      margin: const EdgeInsets.only(top: 16),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _bannerController,
            itemCount: banners.length,
            itemBuilder: (context, index) {
              final banner = banners[index];
              return _BannerCard(
                title: banner.title,
                subtitle: banner.subtitle,
                gradient: banner.gradient,
                icon: banner.icon,
                onTap: () {
                  if (index == 0) context.go('/browse');
                  if (index == 1) context.go('/recognition');
                  if (index == 2) context.go('/collections');
                },
              );
            },
          ),
          Positioned(
            bottom: 16,
            child: SmoothPageIndicator(
              controller: _bannerController,
              count: banners.length,
              effect: WormEffect(
                dotHeight: 8,
                dotWidth: 8,
                activeDotColor: numPrimary,
                dotColor: numTextHint.withAlpha(100),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Region Categories - Horizontal Scroll with navigation arrows
  Widget _buildRegionCategories(BuildContext context, AppLocalizations l10n) {
    final allRegions = RegionData.getAllRegions();
    // "Diğer Bölgeler" (other-ancient-regions-coins) en sona taşı
    final regions = [...allRegions];
    final otherIndex = regions.indexWhere((r) => r.key.contains('other'));
    if (otherIndex != -1) {
      final other = regions.removeAt(otherIndex);
      regions.add(other);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        numSectionHeader(
          title: l10n.translate('ancient_regions'),
          actionText: l10n.translate('see_all'),
          // Tümü → bölge dizini (sikke arama değil)
          onAction: () => context.go('/regions'),
        ),
        SizedBox(
          height: 100,
          child: Row(
            children: [
              // Left arrow
              Container(
                width: 28,
                alignment: Alignment.center,
                child: Icon(Icons.chevron_left, color: numPrimary.withAlpha(150), size: 28),
              ),
              // Region list
              Expanded(
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  itemCount: regions.length,
                  itemBuilder: (context, index) {
                    final region = regions[index];
                    return _RegionChip(
                      regionCode: region.key,
                      regionName: region.value,
                      color: getRegionColor(region.key.replaceAll('-coins', '')),
                      onTap: () => context.go('/browse?region=${region.key}'),
                    );
                  },
                ),
              ),
              // Right arrow
              Container(
                width: 28,
                alignment: Alignment.center,
                child: Icon(Icons.chevron_right, color: numPrimary.withAlpha(150), size: 28),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Coin Recognition Hero Card
  Widget _buildRecognitionCard(BuildContext context, AppLocalizations l10n, authState) {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        shadowColor: numPrimary.withAlpha(50),
        child: InkWell(
          onTap: () {
            if (authState.authenticated) {
              context.go('/recognition');
            } else {
              _showAuthDialog(context, l10n);
            }
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: numGradientPrimary,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    // QR DEGIL: goruntu tanima yapiliyor, kod okunmuyor.
                    Icons.photo_camera_outlined,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                16.width,
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('coin_recognition'),
                        style: boldTextStyle(size: 18, color: Colors.white),
                      ),
                      4.height,
                      Text(
                        authState.authenticated
                            ? l10n.translate('coin_recognition_subtitle')
                            : l10n.translate('sign_in_to_scan'),
                        style: secondaryTextStyle(size: 14, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
                // Arrow
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(30),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Quick Features Grid
  Widget _buildQuickFeatures(BuildContext context, AppLocalizations l10n) {
    final favoritesCount = ref.watch(favoritesControllerProvider).length;

    // TEK VURGU RENGI. Onceki surumde her kart ayri pastel renkteydi (kirmizi,
    // mavi, turuncu, teal); altin-fildisi paletle cakisiyor ve amator
    // gorunuyordu. Ayrimi renk degil ikon + etiket tasir.
    final features = [
      _QuickFeature(
        title: l10n.translate('browse_coins'),
        icon: Icons.search,
        color: numPrimary,
        onTap: () => context.go('/browse'),
      ),
      _QuickFeature(
        title: l10n.translate('my_favorites'),
        icon: Icons.favorite_border,
        color: numPrimary,
        badge: favoritesCount > 0 ? favoritesCount.toString() : null,
        onTap: () => context.go('/favorites'),
      ),
      _QuickFeature(
        title: l10n.translate('my_collections'),
        icon: Icons.collections_bookmark_outlined,
        color: numPrimary,
        onTap: () => context.go('/collections'),
      ),
      _QuickFeature(
        title: l10n.translate('scan_history'),
        icon: Icons.history,
        color: numPrimary,
        onTap: () => context.go('/history'),
      ),
      _QuickFeature(
        title: l10n.translate('blog'),
        icon: Icons.menu_book_outlined,
        color: numPrimary,
        onTap: () => context.go('/blog'),
      ),
      _QuickFeature(
        title: l10n.translate('assistant_short'),
        icon: Icons.chat_bubble_outline,
        color: numPrimary,
        onTap: () => context.push('/assistant'),
      ),
    ];

    // HIZLI ERISIM: baslik ve kart YOK.
    // Gerekce (2026-09-20): once yatay liste vardi (5 kart x 104 px = 520 px,
    // ekran 412 px -> son kart hic gorunmuyordu). Grid tasmayi cozdu ama
    // golgeli/cerceveli kartlar amator duruyordu: her kisayol, sayfadaki
    // "Sikke Tani" gibi gercek bir kartla ayni gorsel agirliktaydi.
    // Modern kisayol bloklari (bankacilik/e-ticaret deseni) cercevesizdir:
    // yuvarlak ikon + altinda etiket, golge yok, ayirici yok. Bolum basligi da
    // gereksiz -- ikonlar zaten kendini anlatiyor ve dikey yer kazanildi.
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
      child: GridView.count(
        // 3 sutun: 6 kisayol tam iki satir eder (4 sutunda ikinci satirda bosluk
        // kaliyordu) ve hucre genisligi ~132 dp'ye cikinca "Koleksiyonlarim" gibi
        // uzun etiketler kelime ortasindan bolunmuyor.
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 8,
        mainAxisSpacing: 12,
        childAspectRatio: 1.15,
        children: [
          for (final feature in features) _QuickAction(feature: feature),
        ],
      ),
    );
  }

  /// Editor's Pick Section
  Widget _buildEditorsPickSection(BuildContext context, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        numSectionHeader(
          title: l10n.translate('editors_pick'),
          actionText: l10n.translate('more'),
          onAction: () => context.go('/browse'),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark ? numSurfaceDark : numSurfaceLight,
            borderRadius: BorderRadius.circular(16),
          ),
          child: const EditorsPickCard(),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n, String feature) {
    toast(l10n.translate('coming_soon_feature', params: {'feature': feature}));
  }

  void _showAuthDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: numPrimary.withAlpha(30),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.lock_outline, color: numPrimary, size: 32),
        ),
        title: Text(l10n.translate('sign_in'), style: boldTextStyle(size: 18)),
        content: Text(
          l10n.translate('auth_required_message'),
          style: secondaryTextStyle(size: 14),
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              context.go('/login');
            },
            child: Text(l10n.translate('sign_in')),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

class _BannerData {
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final IconData icon;

  const _BannerData({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
  });
}

class _BannerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final IconData icon;
  final VoidCallback onTap;

  const _BannerCard({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        elevation: 4,
        borderRadius: BorderRadius.circular(16),
        shadowColor: numPrimary.withAlpha(50),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              gradient: gradient,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        title,
                        // Kart başlığı standardı: NumTypo.title (18)
                        style: boldTextStyle(size: 18, color: Colors.white),
                        maxLines: 2,
                      ),
                      4.height,
                      Text(
                        subtitle,
                        style: secondaryTextStyle(size: 14, color: Colors.white70),
                        maxLines: 2,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(40),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 28, color: Colors.white),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RegionChip extends StatelessWidget {
  final String regionCode;
  final String regionName;
  final Color color;
  final VoidCallback onTap;

  const _RegionChip({
    required this.regionCode,
    required this.regionName,
    required this.color,
    required this.onTap,
  });

  String _getRegionIconPath() {
    // regionCode örn: "pisidia-coins" -> "pisidia_ikon.png"
    final baseName = regionCode.replaceAll('-coins', '').replaceAll('-', '_');
    // Özel durumlar
    if (baseName.contains('other')) {
      return 'assets/images/regions/other_ancient_regions_ikon.png';
    }
    return 'assets/images/regions/${baseName}_ikon.png';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withAlpha(25),
                shape: BoxShape.circle,
                border: Border.all(color: color.withAlpha(60), width: 2),
              ),
              child: ClipOval(
                child: Image.asset(
                  _getRegionIconPath(),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Icon(Icons.location_on, color: color, size: 24),
                ),
              ),
            ),
            6.height,
            SizedBox(
              width: 60,
              child: Text(
                regionName,
                style: secondaryTextStyle(size: 10, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : numTextPrimary),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickFeature {
  final String title;
  final IconData icon;
  final Color color;
  final String? badge;
  final VoidCallback onTap;

  const _QuickFeature({
    required this.title,
    required this.icon,
    required this.color,
    this.badge,
    required this.onTap,
  });
}

/// Kisayol dugmesi: yuvarlak ikon + altinda etiket. Kart/golge/cerceve YOK.
///
/// Onceki `_QuickFeatureCard` her kisayolu golgeli bir karta koyuyordu; sayfadaki
/// gercek kartlarla (Sikke Tani) ayni gorsel agirligi tasidigi icin hiyerarsi
/// bozuluyordu. Ayrica sabit 96x100 boyut yatay tasmanin kaynagiydi ve uzun
/// etiketler FittedBox ile kuculdugu icin kartlar arasinda punto tutarsizdi.
/// Burada etiket iki satira sarar, punto sabit kalir.
class _QuickAction extends StatelessWidget {
  final _QuickFeature feature;

  const _QuickAction({required this.feature});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: feature.title,
      child: InkWell(
        onTap: feature.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: numPrimary.withAlpha(isDark ? 45 : 28),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(feature.icon, color: numPrimary, size: 24),
                  ),
                  if (feature.badge != null)
                    Positioned(
                      top: -2,
                      right: -2,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.error,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          feature.badge!,
                          style: TextStyle(
                            color: theme.colorScheme.onError,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                feature.title,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: isDark ? Colors.white70 : numTextPrimary,
                  height: 1.15,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

