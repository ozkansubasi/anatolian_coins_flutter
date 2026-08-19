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
  int _selectedTab = 0;
  final PageController _bannerController = PageController();
  int _currentBanner = 0;

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
      bottomNavigationBar: _buildBottomNav(context, l10n, isDark),
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
            onPageChanged: (index) {
              setState(() => _currentBanner = index);
            },
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
                    Icons.qr_code_scanner,
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

    final features = [
      _QuickFeature(
        title: l10n.translate('browse_coins'),
        icon: Icons.search,
        color: numPrimary,
        onTap: () => context.go('/browse'),
      ),
      _QuickFeature(
        title: l10n.translate('my_favorites'),
        icon: Icons.favorite,
        color: Colors.red,
        badge: favoritesCount > 0 ? favoritesCount.toString() : null,
        onTap: () => context.go('/favorites'),
      ),
      _QuickFeature(
        title: l10n.translate('my_collections'),
        icon: Icons.collections_bookmark,
        color: Colors.blue,
        onTap: () => context.go('/collections'),
      ),
      _QuickFeature(
        title: l10n.translate('scan_history'),
        icon: Icons.history,
        color: Colors.orange,
        onTap: () => context.go('/history'),
      ),
      _QuickFeature(
        title: l10n.translate('blog'),
        icon: Icons.article,
        color: Colors.teal,
        onTap: () => context.go('/blog'),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        numSectionHeader(title: l10n.translate('quick_access')),
        Container(
          height: 120,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: features.length,
            itemBuilder: (context, index) {
              final feature = features[index];
              return _QuickFeatureCard(feature: feature);
            },
          ),
        ),
      ],
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

  /// Stats Section
  Widget _buildStatsSection(BuildContext context, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? numCardDark : numCardLight,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: numShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: numPrimary, size: 20),
              8.width,
              Text(
                l10n.translate('about_numistr'),
                style: boldTextStyle(size: 16, color: numTextPrimary),
              ),
            ],
          ),
          12.height,
          Text(
            l10n.translate('about_numistr_text'),
            style: secondaryTextStyle(size: 14, color: numTextSecondary),
          ),
          16.height,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatItem(value: '17', label: l10n.translate('regions')),
              _StatItem(value: '439', label: l10n.translate('mints')),
              _StatItem(value: '5000+', label: l10n.translate('coins')),
            ],
          ),
        ],
      ),
    );
  }

  /// Bottom Navigation Bar
  Widget _buildBottomNav(BuildContext context, AppLocalizations l10n, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? numCardDark : numCardLight,
        boxShadow: [
          BoxShadow(
            color: numShadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Menu popup button
                _MenuPopupButton(l10n: l10n, isDark: isDark),
                const SizedBox(width: 4),
                _NavItem(
                  icon: Icons.home,
                  label: l10n.translate('home'),
                  isSelected: _selectedTab == 0,
                  onTap: () => setState(() => _selectedTab = 0),
                ),
                _NavItem(
                  icon: Icons.search,
                  label: l10n.translate('browse'),
                  isSelected: _selectedTab == 1,
                  onTap: () {
                    setState(() => _selectedTab = 1);
                    context.go('/browse');
                  },
                ),
                _NavItem(
                  icon: Icons.qr_code_scanner,
                  label: l10n.translate('scan'),
                  isSelected: _selectedTab == 2,
                  isPrimary: true,
                  onTap: () => context.go('/recognition'),
                ),
                _NavItem(
                  icon: Icons.favorite,
                  label: l10n.translate('favorites'),
                  isSelected: _selectedTab == 3,
                  onTap: () {
                    setState(() => _selectedTab = 3);
                    context.go('/favorites');
                  },
                ),
                _NavItem(
                  icon: Icons.person,
                  label: l10n.translate('profile'),
                  isSelected: _selectedTab == 4,
                  onTap: () {
                    setState(() => _selectedTab = 4);
                    context.go('/account');
                  },
                ),
                _NavItem(
                  icon: Icons.settings,
                  label: l10n.translate('settings'),
                  isSelected: _selectedTab == 5,
                  onTap: () {
                    setState(() => _selectedTab = 5);
                    context.go('/settings');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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

class _QuickFeatureCard extends StatelessWidget {
  final _QuickFeature feature;

  const _QuickFeatureCard({required this.feature});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 96,
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(12),
        color: isDark ? numCardDark : numCardLight,
        shadowColor: numShadow,
        child: InkWell(
          onTap: feature.onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: feature.color.withAlpha(30),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(feature.icon, color: feature.color, size: 22),
                    ),
                    if (feature.badge != null)
                      Positioned(
                        top: -4,
                        right: -4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            feature.badge!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                6.height,
                // Tek satır + sığmazsa küçülterek sığdır ("Koleksiyonlarım"
                // gibi uzun etiketlerin kelime ortasından kırılmasını önler)
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      feature.title,
                      style: secondaryTextStyle(size: 12, color: isDark ? Colors.white70 : numTextPrimary),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String value;
  final String label;

  const _StatItem({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: boldTextStyle(size: 20, color: numPrimary),
        ),
        4.height,
        Text(
          label,
          style: secondaryTextStyle(size: 12, color: numTextSecondary),
        ),
      ],
    );
  }
}

/// Menu popup button that shows a bottom sheet with navigation options
class _MenuPopupButton extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isDark;

  const _MenuPopupButton({required this.l10n, required this.isDark});

  void _showMenuBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _MenuBottomSheet(l10n: l10n, isDark: isDark),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showMenuBottomSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu,
              color: numTextSecondary,
              size: 22,
            ),
            4.height,
            Text(
              l10n.translate('menu'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: numTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet content for the menu
class _MenuBottomSheet extends StatelessWidget {
  final AppLocalizations l10n;
  final bool isDark;

  const _MenuBottomSheet({required this.l10n, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? numCardDark : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.translate('menu'),
                  style: boldTextStyle(size: 18),
                ),
                16.height,
                // Regions option
                _MenuOption(
                  icon: Icons.public,
                  title: l10n.translate('regions'),
                  subtitle: l10n.translate('explore_by_region'),
                  color: numPrimary,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/regions');
                  },
                ),
                8.height,
                // Mints option
                _MenuOption(
                  icon: Icons.location_city,
                  title: l10n.translate('mints'),
                  subtitle: l10n.translate('explore_by_mint'),
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/mints');
                  },
                ),
                24.height,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Menu option item widget
class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: isDark ? numScaffoldDark : Colors.grey.shade50,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              16.width,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: boldTextStyle(size: 16)),
                    4.height,
                    Text(subtitle, style: secondaryTextStyle(size: 12)),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: isDark ? Colors.white54 : Colors.grey.shade400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: numPrimary,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: numPrimary.withAlpha(100),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: numPrimary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? numPrimary : numTextSecondary,
              size: 22,
            ),
            4.height,
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? numPrimary : numTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
