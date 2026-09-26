import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../core/region_data.dart';
import '../../prokit_ui/prokit_ui.dart';
import '../../prokit_ui/widgets/num_bottom_nav.dart';
import '../favorites/favorites_service.dart';
import '../articles/editors_pick_card.dart';
import 'widgets/home_banner.dart';

/// Profil ikonundaki bildirim noktasi.
///
/// Uygulamada bildirim altyapisi YOK; bu saglayici bilerek `false` donuyor ve
/// nokta hic cizilmiyor. Bildirim kaynagi (ornegin okunmamis tarama sonucu veya
/// sunucu bildirimi) eklendiginde yalniz burasi degisir, AppBar kodu aynen kalir.
final bildirimVarProvider = Provider<bool>((ref) => false);

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
      // Tek kaynak: NumBottomNav, kabukta (NumShellScaffold) çizilir.
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
        // Arama ikonu 2026-09-21'de kaldırıldı: aynı hedef alt çubukta (Keşfet)
        // ve hızlı erişimde (Sikke Ara) zaten var; üçüncü kopya gereksizdi.
        // Zil yerine PROFIL: bildirim ekrani yok, zil ikonu "yakinda" diyen bos
        // bir aksiyona gidiyordu. Bildirim oldugunda ikonun uzerinde kahverengi
        // nokta gorunur (2026-09-20 karari).
        IconButton(
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.account_circle_outlined,
                  color: isDark ? Colors.white : numTextPrimary),
              if (ref.watch(bildirimVarProvider))
                Positioned(
                  right: -1,
                  top: -1,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: numSecondary,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? numCardDark : numCardLight,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => context.openRoute('/account'),
          tooltip: l10n.translate('profile'),
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
        // Bilgi bankası = makaleler (kullanıcı kararı 2026-09-26); eskiden
        // Keşfet'e gidip Keşfet ikonuyla aynı yere düşüyordu.
        onTap: () => context.openRoute('/blog'),
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
        onTap: () => context.openRoute('/regions'),
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
    final allRegions = RegionData.getAllRegions(l10n);
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
          onAction: () => context.openRoute('/regions'),
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
                      onTap: () => context.openRoute('/browse?region=${region.key}'),
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
        tint: const Color(0xFFFDF3E0),
        onTap: () => context.go('/recognition'),
      ),
      _QuickFeature(
        title: l10n.translate('browse_coins'),
        icon: Icons.search,
        color: numPrimary,
        tint: const Color(0xFFF6EEE2),
        onTap: () => context.go('/browse'),
      ),
      _QuickFeature(
        title: l10n.translate('my_favorites'),
        icon: Icons.favorite_border,
        color: numPrimary,
        tint: const Color(0xFFF9E9E2),
        badge: favoritesCount > 0 ? favoritesCount.toString() : null,
        onTap: () => context.go('/favorites'),
      ),
      _QuickFeature(
        title: l10n.translate('collections_short'),
        icon: Icons.collections_bookmark_outlined,
        color: numPrimary,
        tint: const Color(0xFFF1EFE2),
        onTap: () => context.openRoute('/collections'),
      ),
      _QuickFeature(
        title: l10n.translate('blog'),
        icon: Icons.menu_book_outlined,
        color: numPrimary,
        tint: const Color(0xFFF5EEE6),
        onTap: () => context.openRoute('/blog'),
      ),
      _QuickFeature(
        title: l10n.translate('assistant_short'),
        icon: Icons.chat_bubble_outline,
        color: numPrimary,
        tint: const Color(0xFFEFEDE6),
        onTap: () => context.openRoute('/assistant'),
      ),
    ];

    // HIZLI ERISIM: 2 sutun x 3 satir YATAY tile.
    // Bugunun dorduncu revizyonu. Oncekiler: golgeli beyaz kare kartlar ->
    // "amator"; cercevesiz ikon-only -> etiketsiz anlasilmiyordu; etiketli kare
    // kartlar -> dikeyde cok yer kapliyor ve "tiklanabilir" hissi vermiyordu.
    // Yatay tile kart yuksekligini ~64dp'ye indirir ve soldaki ikon + sagdaki
    // ok ucuyla klasik "satira bas" afordansini kurar.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.6,
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
          onAction: () => context.openRoute('/blog'),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: EditorsPickCard(),
        ),
      ],
    );
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

  /// Kartin zemin rengi (acik tema). Hepsi TOPRAK TONU: kum, fildisi, bronz,
  /// terrakota, adaçayı, tas. Pastel kirmizi/mavi/turuncu bilerek kullanilmiyor --
  /// altin-fildisi paletle cakisiyor ve "amator" gorunuyordu (2026-09-20 olcumu).
  final Color tint;
  final String? badge;
  final VoidCallback onTap;

  const _QuickFeature({
    required this.title,
    required this.icon,
    required this.color,
    required this.tint,
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
/// Kisayol tile'i: solda ikon, ortada etiket, sagda ok ucu.
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
        color: isDark ? theme.colorScheme.surfaceContainerLow : feature.tint,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: feature.onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              // Ince altin cerceve: zemin tonlari birbirine yakin oldugu icin
              // kartin siniri tek basina renkle okunmuyordu.
              border: Border.all(color: numPrimary.withAlpha(70)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: numPrimary.withAlpha(isDark ? 45 : 40),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(feature.icon, color: numPrimary, size: 22),
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    feature.title,
                    // 12sp: 14sp'de hucre genisligi (~91dp) yetmiyor ve
                    // "Favorilerim" / "Koleksiyonlar" kelime ortasindan boluniyordu.
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white70 : numTextPrimary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.chevron_right, size: 16, color: numPrimary.withAlpha(160)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

