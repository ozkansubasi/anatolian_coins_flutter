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
import 'widgets/home_banner.dart';

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

          // Quick Features Section
          _buildQuickFeatures(context, l10n),

          // Editor's Pick Section
          _buildEditorsPickSection(context, l10n),

          100.height, // Bottom padding
        ],
      ),
    );
  }

  /// Ana sayfa banner'lari: fotograf + slogan (2026-09-20).
  ///
  /// Onceki surum jenerik ikon + gradyan tasiyordu (Icons.explore, camera,
  /// collections); uygulamanin icerigi -- gercek sikke fotograflari -- ana
  /// sayfada hic gorunmuyordu. Gorseller: BnF kamu mali (ADR-008 lisans
  /// haritasinda "serbest" kumesi), Sagalassos icin mevcut bolge banner'i.
  Widget _buildBannerCarousel(BuildContext context, AppLocalizations l10n) {
    final banners = <Widget>[
      HomeBanner(
        image: 'assets/images/banners/coin_tanima.jpg',
        slogan: l10n.translate('banner_recognize'),
        fit: BoxFit.contain,
        onTap: () => context.go('/recognition'),
      ),
      HomeBanner(
        image: 'assets/images/banners/coin_bilgi.jpg',
        slogan: l10n.translate('banner_knowledge'),
        fit: BoxFit.contain,
        onTap: () => context.go('/browse'),
        // Isaretler: sikkenin okunan kisimlarina dikkat ceker. Konumlar bu
        // fotografa gore ayarlandi; gorsel degisirse yeniden hizalanmali.
        markers: [
          BannerMarker(const Alignment(-0.10, -0.55), l10n.translate('marker_portrait')),
          BannerMarker(const Alignment(0.22, 0.10), l10n.translate('marker_legend')),
        ],
      ),
      HomeBanner(
        image: 'assets/images/regions/pisidia_banner.jpg',
        slogan: l10n.translate('banner_regions'),
        onTap: () => context.go('/regions'),
      ),
    ];

    return Container(
      height: 185,
      margin: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          Expanded(
            child: PageView.builder(
              controller: _bannerController,
              itemCount: banners.length,
              itemBuilder: (context, index) => banners[index],
            ),
          ),
          // Gosterge ARTIK kartin icinde degil: onceki surumde Positioned ile
          // kartin uzerine biniyor, gradyan metnin ustune geliyordu.
          const SizedBox(height: 8),
          SmoothPageIndicator(
            controller: _bannerController,
            count: banners.length,
            effect: WormEffect(
              dotHeight: 7,
              dotWidth: 7,
              activeDotColor: numPrimary,
              dotColor: numTextHint.withAlpha(100),
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

  /// Quick Features Grid
  Widget _buildQuickFeatures(BuildContext context, AppLocalizations l10n) {
    final favoritesCount = ref.watch(favoritesControllerProvider).length;

    // TEK VURGU RENGI. Onceki surumde her kart ayri pastel renkteydi (kirmizi,
    // mavi, turuncu, teal); altin-fildisi paletle cakisiyor ve amator
    // gorunuyordu. Ayrimi renk degil ikon + etiket tasir.
    final features = [
      // Sikke Tani artik kisayollardan biri. Onceki full-width kart kaldirildi:
      // ayni aksiyon alt cubuk + kart + kisayol olarak UC kez tekrarlaniyordu
      // (Material: ekran basina tek birincil aksiyon).
      _QuickFeature(
        title: l10n.translate('coin_recognition'),
        icon: Icons.photo_camera_outlined,
        color: numPrimary,
        onTap: () => context.go('/recognition'),
      ),
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
        title: l10n.translate('collections_short'),
        icon: Icons.collections_bookmark_outlined,
        color: numPrimary,
        onTap: () => context.go('/collections'),
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
        childAspectRatio: 0.95,
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
          // Blog menusune gider; "sikke arama" (/browse) yanlis hedefti.
          onAction: () => context.go('/blog'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: EditorsPickCard(),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n, String feature) {
    toast(l10n.translate('coming_soon_feature', params: {'feature': feature}));
  }

}

// =============================================================================
// HELPER WIDGETS
// =============================================================================

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
/// Kisayol dugmesi: yalnizca yuvarlak ikon (etiket yok).
///
/// Etiketler 2026-09-20'de kaldirildi (kullanici karari: "ikon yeterli").
/// ERISILEBILIRLIK: ikon tek basina ekran okuyucuya hicbir sey soylemez, bu yuzden
/// her dugme Semantics(label:) ve Tooltip tasir -- uzun basinca etiket gorunur.
/// Kisayol karti: ikon + etiket, Editor'den blogundaki kart tipiyle ayni yuzey.
///
/// Tarihce (aynı gun, iki revizyon): once golgeli beyaz kartlardi -> "amator"
/// bulundu, cercevesiz ikon-only yapildi -> etiketsiz ikonlar anlasilmiyordu.
/// Son hal: Editor'den karti ile AYNI dil -- surfaceContainerLow yuzey, hafif
/// yukselti, 16 yaricap -- yani sayfada iki farkli kart tipi yok.
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
      child: Material(
        elevation: 1,
        color: theme.colorScheme.surfaceContainerLow,
        shadowColor: theme.colorScheme.shadow,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: feature.onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
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
                const SizedBox(height: 8),
                // Etiket sabit puntoda: FittedBox ile kucultmek kartlar arasinda
                // farkli punto uretiyordu (eski _QuickFeatureCard hatasi).
                Text(
                  feature.title,
                  style: theme.textTheme.labelMedium?.copyWith(
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
      ),
    );
  }
}

