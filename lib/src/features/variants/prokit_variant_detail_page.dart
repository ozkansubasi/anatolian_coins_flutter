import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../../models/variant.dart';
import '../../models/variant_image.dart';
import 'variants_api.dart';
import 'image_gallery_viewer.dart';
import '../../core/subscription_provider.dart';
import '../../core/locale_provider.dart';
import '../../core/region_data.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../core/num_colors.dart';
import '../../core/num_text.dart';
import '../../core/coin_format.dart';
import '../../core/navigation.dart';
import '../favorites/favorites_service.dart';
import '../offline/offline_service.dart';
import '../../widgets/fallback_image.dart';
import '../map/ancient_map_widget.dart';

class ProkitVariantDetailPage extends ConsumerStatefulWidget {
  final int articleId;
  const ProkitVariantDetailPage({super.key, required this.articleId});

  @override
  ConsumerState<ProkitVariantDetailPage> createState() => _ProkitVariantDetailPageState();
}

class _ProkitVariantDetailPageState extends ConsumerState<ProkitVariantDetailPage>
    with SingleTickerProviderStateMixin {
  Variant? _variant;
  List<VariantImage> _images = [];
  bool _loading = true;
  bool _isOfflineAvailable = false;
  String? _error;

  final PageController _imageController = PageController();
  int _currentImageIndex = 0;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _imageController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    // Track view history
    try {
      final db = ref.read(offlineDatabaseProvider);
      await db.addToViewHistory(widget.articleId);
    } catch (e) {
      // Silent fail
    }

    // Check offline first
    final offlineService = ref.read(offlineServiceProvider);
    final isOffline = await offlineService.isOfflineAvailable(widget.articleId);

    if (isOffline) {
      final offlineVariant = await offlineService.getOfflineVariant(widget.articleId);
      final offlineImages = await offlineService.getOfflineImages(widget.articleId);

      if (offlineVariant != null) {
        setState(() {
          _variant = offlineVariant;
          _images = offlineImages;
          _isOfflineAvailable = true;
          _loading = false;
        });
        return;
      }
    }

    // Load from API
    final api = ref.read(variantsApiProvider);

    try {
      final v = await api.getVariant(widget.articleId, includeImages: true);
      // ADR-006 Faz 2: herkes filigranlı 1600 px + Pro'ya sunucu url_hd verir (eski 'Pro=wm:0'
      // 480 px filigransız thumb idi — yüksek çözünürlük değil, küçültmeydi).
      final imgs = await api.images(widget.articleId, wm: true, abs: false);
      setState(() {
        _variant = v;
        _images = imgs;
        _isOfflineAvailable = isOffline;
        _error = null;
      });
    } catch (e) {
      setState(() {
        final l10n = AppLocalizations.of(context);
        _error = e.toString().contains('404')
            ? l10n.translate('coin_not_found')
            : l10n.translate('coin_load_failed');
      });
    } finally {
      setState(() => _loading = false);
    }
  }

  void _openGallery(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageGalleryViewer(
          images: _images,
          initialIndex: initialIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  void _handleShare() {
    if (_variant == null) return;
    final l10n = AppLocalizations.of(context);
    final region = RegionData.getRegionName(_variant!.regionCode, l10n);
    final material = CoinFormat.material(_variant!.material, l10n) ?? '-';
    final text = 'NumisTR - ${_variant!.title}\n'
        '${l10n.translate('region_prefix', params: {'region': region})}\n'
        '${l10n.translate('material_prefix', params: {'material': material})}\n'
        'https://www.numistr.org/sikke/${_variant!.slug}';
    Share.share(text, subject: _variant!.title);
  }

  Future<void> _handleFavoriteToggle() async {
    final l10n = AppLocalizations.of(context);
    final subscription = ref.read(subscriptionProvider);
    final favorites = ref.read(favoritesControllerProvider);

    if (!subscription.isPro) {
      if (!favorites.contains(widget.articleId) &&
          favorites.length >= FeatureLimits.freeMaxFavorites) {
        _showProDialog(l10n.translate('unlimited_favorites'));
        return;
      }
    }

    try {
      await ref.read(favoritesControllerProvider.notifier).toggle(
        widget.articleId,
        syncOffline: subscription.isPro,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.translate('error')}: $e')),
        );
      }
    }
  }

  void _showProDialog(String featureName) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) {
        final c = context.numColors;
        return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: numPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, color: c.accent, size: 20),
            ),
            12.width,
            Text(l10n.translate('pro_feature'), style: context.numText.section),
          ],
        ),
        content: Text(
          l10n.translate('feature_locked_message', params: {'featureName': featureName}),
          style: context.numText.body.copyWith(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('close'), style: context.numText.value.copyWith(color: c.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.push('/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.translate('buy_pro')),
          ),
        ],
      );
      },
    );
  }

  Future<void> _openInMaps() async {
    if (_variant?.coordinates == null) return;
    try {
      final coords = _variant!.coordinates!.split(',');
      if (coords.length == 2) {
        final lat = coords[0].trim();
        final lng = coords[1].trim();
        final url = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      // Silent fail
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesControllerProvider);
    final isFavorite = favorites.contains(widget.articleId);
    final c = context.numColors;

    if (_loading) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: numPrimary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: const Center(child: CircularProgressIndicator(color: numPrimary)),
      );
    }

    if (_error != null) {
      return Scaffold(
        appBar: AppBar(
          backgroundColor: numPrimary,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: _buildErrorWidget(),
      );
    }

    final v = _variant!;

    return Scaffold(
      body: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 380,
                floating: false,
                pinned: true,
                backgroundColor: numPrimary,
                iconTheme: const IconThemeData(color: Colors.white),
                // Fotoğraf görünürken (açık fonlu müze fotoğrafı) durum çubuğu
                // simgeleri koyu; başlık altın çubuğa dönüşünce açık.
                // Renksiz stil: hazır .light/.dark gezinme çubuğunu SİYAHA boyuyor
                // ve kullanımdan kalkan setNavigationBarColor'ı tetikliyordu.
                systemOverlayStyle: SystemUiOverlayStyle(
                  statusBarIconBrightness:
                      innerBoxIsScrolled ? Brightness.light : Brightness.dark,
                  statusBarBrightness:
                      innerBoxIsScrolled ? Brightness.dark : Brightness.light,
                ),
                // Beyaz ikonlar açık fotoğrafta görünmüyordu: yarı saydam koyu
                // yuvarlak zemin (cihazda görüldü).
                leading: Padding(
                  padding: const EdgeInsets.all(6),
                  child: IconButton(
                    style: _overlayIconStyle,
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    onPressed: () => context.popOrGoHome(),
                  ),
                ),
                title: innerBoxIsScrolled
                    ? Text(
                        v.title,
                        style: context.numText.section.copyWith(color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                actions: [
                  IconButton(
                    style: _overlayIconStyle,
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red.shade300 : Colors.white,
                    ),
                    onPressed: _handleFavoriteToggle,
                  ),
                  4.width,
                  // ADR-006 Faz 3: asistana bu sikke hakkında sor (soru önceden doldurulur, gönderilmez)
                  IconButton(
                    style: _overlayIconStyle,
                    icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
                    tooltip: l10n.translate('ask_assistant'),
                    onPressed: () => context.push(
                      '/assistant?q=${Uri.encodeQueryComponent(l10n.translate('assistant_prefill', params: {'title': v.title}))}',
                    ),
                  ),
                  4.width,
                  IconButton(
                    style: _overlayIconStyle,
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _handleShare,
                  ),
                  8.width,
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildImageSlider(),
                  collapseMode: CollapseMode.pin,
                ),
              ),
              // Sekmeler: kapsül (segmented) biçim, ikon + kısa etiket.
              // Eskiden 14pt kalın 4 etiket sığmıyor, "Sikke Bilg…" diye
              // kesiliyordu; etiketler kısaldı ("Künye", "Harita").
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  background: Theme.of(context).scaffoldBackgroundColor,
                  tabBar: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: c.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: c.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      dividerColor: Colors.transparent,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(color: c.shadow, blurRadius: 6, offset: const Offset(0, 1)),
                        ],
                      ),
                      labelColor: c.accent,
                      unselectedLabelColor: c.textMuted,
                      labelStyle: context.numText.tab,
                      unselectedLabelStyle: context.numText.tab.copyWith(fontWeight: FontWeight.w500),
                      labelPadding: EdgeInsets.zero,
                      splashBorderRadius: BorderRadius.circular(10),
                      tabs: [
                        _tab(Icons.badge_outlined, l10n.translate('tab_details')),
                        _tab(Icons.photo_library_outlined, l10n.translate('images')),
                        _tab(Icons.map_outlined, l10n.translate('tab_map')),
                        _tab(Icons.menu_book_outlined, l10n.translate('source')),
                      ],
                    ),
                  ),
                ),
              ),
            ];
          },
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildDetailsTab(v, l10n),
              _buildImagesTab(l10n),
              _buildAncientMapTab(v, l10n),
              _buildSourceTab(v, l10n),
            ],
          ),
      ),
    );
  }

  Widget _buildImageSlider() {
    final c = context.numColors;
    if (_images.isEmpty) {
      return Container(
        color: c.surface,
        child: Center(
          child: Icon(
            Icons.monetization_on_outlined,
            size: 64,
            color: c.textMuted.withValues(alpha: 0.5),
          ),
        ),
      );
    }

    return Stack(
      children: [
        PageView.builder(
          controller: _imageController,
          itemCount: _images.length,
          onPageChanged: (index) => setState(() => _currentImageIndex = index),
          itemBuilder: (context, index) {
            final img = _images[index];
            return GestureDetector(
              onTap: () => _openGallery(index),
              child: Container(
                color: Colors.white,
                child: FallbackImage(
                  url: img.url,
                  remoteUrl: img.remoteUrl,
                  fit: BoxFit.contain,
                ),
              ),
            );
          },
        ),
        if (_images.length > 1)
          Positioned(
            bottom: 16,
            left: 0,
            right: 0,
            child: Center(
              child: SmoothPageIndicator(
                controller: _imageController,
                count: _images.length,
                effect: WormEffect(
                  dotHeight: 8,
                  dotWidth: 8,
                  spacing: 6,
                  activeDotColor: numPrimary,
                  dotColor: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsTab(Variant v, AppLocalizations l10n) {
    final currentLocale = ref.watch(localeProvider);
    final isEnglish = currentLocale.languageCode == 'en';
    final obverseText = isEnglish ? (v.obverseDesc ?? v.obverseDescTr) : (v.obverseDescTr ?? v.obverseDesc);
    final reverseText = isEnglish ? (v.reverseDesc ?? v.reverseDescTr) : (v.reverseDescTr ?? v.reverseDesc);
    final hasObverse = obverseText != null && obverseText.isNotEmpty;
    final hasReverse = reverseText != null && reverseText.isNotEmpty;
    final t = context.numText;
    final c = context.numColors;

    final period = CoinFormat.dateRange(v.dateFrom, v.dateTo, l10n);
    final material = CoinFormat.material(v.material, l10n);
    final region = v.regionCode != null && v.regionCode!.isNotEmpty
        ? RegionData.getRegionName(v.regionCode, l10n)
        : null;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık + özet çipleri (dönem · materyal · bölge)
          Text(v.title, style: t.pageTitle, maxLines: 3, overflow: TextOverflow.ellipsis),
          16.height,

          // Künye: tekrarlar çıkarıldı (başlıkla aynı "Sikke Adı" satırı ve sekme
          // adıyla aynı kart başlığı). Koordinat Harita sekmesinde.
          _buildInfoCard(
            children: [
              if (v.authorityName != null && v.authorityName!.isNotEmpty)
                _buildInfoRow(l10n.translate('authority_label'), v.authorityName!),
              if (v.mintName != null && v.mintName!.isNotEmpty)
                _buildInfoRow(l10n.translate('mint_label'), CoinFormat.titleCase(v.mintName!)),
              if (region != null && region != '-')
                _buildInfoRow(l10n.translate('region_label'), region),
              _buildInfoRow(
                l10n.translate('material_label'),
                material ?? '-',
                dotColor: material == null ? null : CoinFormat.materialColor(v.material),
              ),
              _buildInfoRow(l10n.translate('period'), period ?? '-', last: true),
            ],
          ),

          // Yüz Tanımları
          if (hasObverse || hasReverse) ...[
            16.height,
            _buildInfoCard(
              title: l10n.translate('obverse_reverse'),
              icon: Icons.flip_outlined,
              children: [
                if (hasObverse) _faceBlock(l10n.translate('obverse'), obverseText),
                if (hasObverse && hasReverse)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Divider(color: c.divider, height: 1),
                  ),
                if (hasReverse) _faceBlock(l10n.translate('reverse'), reverseText),
              ],
            ),
          ],

          80.height, // alt çubuk payı
        ],
      ),
    );
  }

  /// Ön/Arka yüz bloğu: küçük altın etiket + okunur gövde metni.
  Widget _faceBlock(String label, String text) {
    final t = context.numText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: t.tag),
        6.height,
        Text(text, style: t.body),
      ],
    );
  }

  /// Fotoğraf üstündeki AppBar ikonları için yarı saydam koyu yuvarlak zemin.
  ButtonStyle get _overlayIconStyle => IconButton.styleFrom(
        backgroundColor: Colors.black.withValues(alpha: 0.32),
        minimumSize: const Size(40, 40),
        padding: const EdgeInsets.all(8),
        shape: const CircleBorder(),
      );

  Widget _tab(IconData icon, String label) {
    return Tab(
      height: 38,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16),
          4.width,
          Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  Widget _buildAncientMapTab(Variant v, AppLocalizations l10n) {
    final c = context.numColors;
    if (v.coordinates == null || v.coordinates!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: c.textMuted.withValues(alpha: 0.5)),
            16.height,
            Text(l10n.translate('coordinates'), style: context.numText.label),
            8.height,
            Text('-', style: context.numText.section),
          ],
        ),
      );
    }

    // Kaydırılabilir + sabit yükseklikli önizleme: eskiden önizleme Expanded
    // ile kalan alana bırakılmıştı ve 380 px fotoğraf başlığının altında ince
    // bir şeride sıkışıyordu (cihazda görüldü).
    return ListView(
      padding: const EdgeInsets.only(top: 8, bottom: 80),
      children: [
        // Yatay mod için bilgi mesajı
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.screen_rotation, size: 20, color: c.accent),
              12.width,
              Expanded(
                child: Text(
                  l10n.translate('rotate_for_fullscreen'),
                  style: context.numText.caption.copyWith(color: c.accent),
                ),
              ),
            ],
          ),
        ),
        // Harita preview alanı
        SizedBox(
          height: 260,
          child: GestureDetector(
            onTap: () => _openFullScreenMap(v.coordinates!),
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.brown.shade200,
                    Colors.brown.shade400,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  children: [
                    // Mini harita preview - gerçek harita
                    Positioned.fill(
                      child: AncientMapWidget(
                        focusPoint: _parseCoordinates(v.coordinates!),
                        highlightMint: v.mintName,
                        isFullScreen: false,
                      ),
                    ),
                    // Overlay ve içerik
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.fullscreen, size: 48, color: Colors.white),
                            ),
                            16.height,
                            Text(
                              l10n.translate('show_on_map'),
                              style: context.numText.section.copyWith(color: Colors.white),
                            ),
                            8.height,
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                v.coordinates!,
                                style: context.numText.caption.copyWith(color: Colors.white70),
                              ),
                            ),
                            24.height,
                            Text(
                              l10n.translate('tap_for_fullscreen'),
                              style: context.numText.caption.copyWith(color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Butonlar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Antik Harita butonu
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openFullScreenMap(v.coordinates!),
                  icon: const Icon(Icons.map),
                  label: Text(l10n.translate('ancient_map')),
                  // Marka rengi (eskiden paletin dışında Colors.brown'du).
                  style: ElevatedButton.styleFrom(
                    backgroundColor: numPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              // Pro kullanıcılar için Google Maps
              if (ref.watch(subscriptionProvider).isPro) ...[
                12.height,
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _openInMaps,
                    icon: const Icon(Icons.public),
                    label: Text(l10n.translate('show_on_modern_map')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.accent,
                      side: BorderSide(color: c.accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  LatLng? _parseCoordinates(String coordinates) {
    try {
      final coords = coordinates.split(',');
      if (coords.length == 2) {
        final lat = double.parse(coords[0].trim());
        final lng = double.parse(coords[1].trim());
        return LatLng(lat, lng);
      }
    } catch (e) {
      // Parse hatası - null döndür
    }
    return null;
  }

  void _openFullScreenMap(String coordinates) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenAncientMapPage(
          coordinates: coordinates,
          mintName: _variant?.mintName,
          regionCode: _variant?.regionCode,
        ),
      ),
    );
  }

  Widget _buildImagesTab(AppLocalizations l10n) {
    final c = context.numColors;
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: c.textMuted.withValues(alpha: 0.5)),
            16.height,
            Text(l10n.translate('no_images_found'), style: context.numText.caption),
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _images.length,
      itemBuilder: (context, index) {
        final img = _images[index];
        return GestureDetector(
          onTap: () => _openGallery(index),
          child: Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  FallbackImage(
                    url: img.url,
                    remoteUrl: img.remoteUrl,
                    fit: BoxFit.cover,
                  ),
                  if (img.weight != null || img.diameter != null)
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.7),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (img.weight != null && img.weight!.isNotEmpty)
                              Text(
                                '${img.weight}g',
                                style: context.numText.tag.copyWith(color: Colors.white),
                              ),
                            if (img.weight != null && img.diameter != null) 8.width,
                            if (img.diameter != null && img.diameter!.isNotEmpty)
                              Text(
                                '${img.diameter}mm',
                                style: context.numText.tag.copyWith(color: Colors.white),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourceTab(Variant v, AppLocalizations l10n) {
    // UID'den Sikke No'yu çıkar (ntr:var:00003470 -> 3470)
    String? coinNo;
    if (v.uid != null) {
      final match = RegExp(r':(\d+)$').firstMatch(v.uid!);
      if (match != null) {
        coinNo = int.tryParse(match.group(1) ?? '')?.toString();
      }
    }
    // Fallback olarak articleId kullan
    coinNo ??= v.articleId?.toString();
    final c = context.numColors;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sikke No ve Web Sitesi Linki
          _buildInfoCard(
            title: l10n.translate('coin_no'),
            icon: Icons.tag,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      coinNo ?? '-',
                      style: context.numText.pageTitle.copyWith(color: c.accent),
                    ),
                  ),
                ],
              ),
              12.height,
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _openCoinOnWebsite(v.articleId),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.translate('view_on_website')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: c.accent,
                    side: BorderSide(color: c.accent),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          if (v.sourceCitation != null && v.sourceCitation!.isNotEmpty) ...[
            16.height,
            _buildInfoCard(
              title: l10n.translate('source'),
              icon: Icons.book,
              children: [
                Text(v.sourceCitation!, style: context.numText.body),
              ],
            ),
          ],
          if (v.findspotName != null && v.findspotName!.isNotEmpty) ...[
            16.height,
            _buildInfoCard(
              title: l10n.translate('findspot'),
              icon: Icons.place,
              children: [
                Text(v.findspotName!, style: context.numText.value),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openCoinOnWebsite(int? articleId) async {
    if (articleId == null) return;
    try {
      final url = Uri.parse('https://www.numistr.org/sikke/$articleId');
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      // Silent fail
    }
  }

  /// Bilgi kartı: ince kenarlık, ağır gölge yok. Başlık isteğe bağlı —
  /// Künye kartında sekme adıyla aynı başlık tekrar edilmez.
  Widget _buildInfoCard({
    String? title,
    IconData? icon,
    required List<Widget> children,
  }) {
    final c = context.numColors;
    final t = context.numText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                if (icon != null) ...[
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: c.accent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 18, color: c.accent),
                  ),
                  10.width,
                ],
                Expanded(child: Text(title, style: t.section)),
              ],
            ),
            14.height,
          ],
          ...children,
        ],
      ),
    );
  }

  /// Etiket / değer satırı; satırlar arasında ince ayraç.
  Widget _buildInfoRow(String label, String value, {bool last = false, Color? dotColor}) {
    final c = context.numColors;
    final t = context.numText;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: last ? null : Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 96, child: Text(label, style: t.label)),
          12.width,
          if (dotColor != null) ...[
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(top: 4, right: 8),
              decoration: BoxDecoration(
                color: dotColor,
                shape: BoxShape.circle,
                border: Border.all(color: c.border),
              ),
            ),
          ],
          Expanded(child: Text(value, style: t.value)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    final l10n = AppLocalizations.of(context);
    final t = context.numText;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off_rounded, size: 56, color: context.numColors.hint),
            16.height,
            Text(_error!, style: t.section, textAlign: TextAlign.center),
            20.height,
            FilledButton.icon(
              onPressed: () => context.popOrGoHome(),
              icon: const Icon(Icons.arrow_back),
              label: Text(l10n.translate('go_back')),
              style: FilledButton.styleFrom(backgroundColor: numPrimary),
            ),
          ],
        ),
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  final Color background;
  _SliverTabBarDelegate({required this.tabBar, required this.background});

  // 12 üst + 46 kapsül + 8 alt
  static const double _height = 66;

  @override
  double get minExtent => _height;

  @override
  double get maxExtent => _height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: tabBar,
    );
  }

  // Tema değişince (renkler) yeniden çizilsin.
  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) =>
      oldDelegate.background != background || oldDelegate.tabBar != tabBar;
}
