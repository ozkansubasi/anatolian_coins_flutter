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
        _error = e.toString().contains('404')
            ? 'Coin not found in database'
            : 'Loading error';
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
    final text = 'NumisTR - ${_variant!.title}\n'
        'Region: ${_variant!.regionCode ?? '-'}\n'
        'Material: ${_variant!.material ?? '-'}\n'
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
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: numPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.lock, color: numPrimary, size: 20),
            ),
            12.width,
            Text(l10n.translate('pro_feature'), style: boldTextStyle(size: 18)),
          ],
        ),
        content: Text(
          l10n.translate('feature_locked_message', params: {'featureName': featureName}),
          style: secondaryTextStyle(size: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('close'), style: primaryTextStyle(color: numTextSecondary)),
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
      ),
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

  String _formatDateRange(int? from, int? to) {
    if (from == null && to == null) return '-';
    final fromStr = from != null ? '${from.abs()} ${from < 0 ? 'BC' : 'AD'}' : '';
    final toStr = to != null ? '${to.abs()} ${to < 0 ? 'BC' : 'AD'}' : '';
    if (from == to) return fromStr;
    return '$fromStr - $toStr'.trim();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final favorites = ref.watch(favoritesControllerProvider);
    final isFavorite = favorites.contains(widget.articleId);

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
      body: DefaultTabController(
        length: 3,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverAppBar(
                expandedHeight: 380,
                floating: false,
                pinned: true,
                backgroundColor: numPrimary,
                iconTheme: const IconThemeData(color: Colors.white),
                title: innerBoxIsScrolled
                    ? Text(
                        v.title,
                        style: boldTextStyle(size: 16, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : null,
                actions: [
                  IconButton(
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite ? Colors.red : Colors.white,
                    ),
                    onPressed: _handleFavoriteToggle,
                  ),
                  // ADR-006 Faz 3: asistana bu sikke hakkında sor (soru önceden doldurulur, gönderilmez)
                  IconButton(
                    icon: const Icon(Icons.smart_toy_outlined, color: Colors.white),
                    tooltip: l10n.translate('ask_assistant'),
                    onPressed: () => context.push(
                      '/assistant?q=${Uri.encodeQueryComponent(l10n.translate('assistant_prefill', params: {'title': v.title}))}',
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _handleShare,
                  ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: _buildImageSlider(),
                  collapseMode: CollapseMode.pin,
                ),
              ),
              SliverPersistentHeader(
                pinned: true,
                delegate: _SliverTabBarDelegate(
                  TabBar(
                    controller: _tabController,
                    labelColor: numPrimary,
                    unselectedLabelColor: numTextSecondary,
                    indicatorColor: numPrimary,
                    labelStyle: boldTextStyle(size: 14),
                    tabs: [
                      Tab(text: l10n.translate('coin_info')),
                      Tab(text: l10n.translate('images')),
                      Tab(text: l10n.translate('ancient_map')),
                      Tab(text: l10n.translate('source')),
                    ],
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
      ),
    );
  }

  Widget _buildImageSlider() {
    if (_images.isEmpty) {
      return Container(
        color: numBackgroundGrey,
        child: Center(
          child: Icon(
            Icons.monetization_on_outlined,
            size: 64,
            color: numTextSecondary.withValues(alpha: 0.5),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            v.title,
            style: boldTextStyle(size: 20),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          16.height,

          // Basic Info Card
          _buildInfoCard(
            title: l10n.translate('coin_info'),
            icon: Icons.info_outline,
            children: [
              _buildInfoRow(l10n.translate('coin_name'), v.title ?? '-'),
              if (v.authorityName != null && v.authorityName!.isNotEmpty)
                _buildInfoRow(l10n.translate('authority_label'), v.authorityName!),
              if (v.mintName != null && v.mintName!.isNotEmpty)
                _buildInfoRow(l10n.translate('mint_label'), v.mintName!),
              if (v.coordinates != null && v.coordinates!.isNotEmpty)
                _buildInfoRow(l10n.translate('mint_coordinates'), v.coordinates!),
              _buildInfoRow(l10n.translate('material_label'), v.material ?? '-'),
              _buildInfoRow(l10n.translate('period'), _formatDateRange(v.dateFrom, v.dateTo)),
            ],
          ),

          // Obverse & Reverse Combined
          if ((obverseText != null && obverseText.isNotEmpty) ||
              (reverseText != null && reverseText.isNotEmpty)) ...[
            16.height,
            _buildInfoCard(
              title: l10n.translate('obverse_reverse'),
              icon: Icons.monetization_on,
              iconColor: numPrimary,
              children: [
                if (obverseText != null && obverseText.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.blue,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('obverse'),
                              style: boldTextStyle(size: 14, color: Colors.blue),
                            ),
                            4.height,
                            Text(
                              obverseText,
                              style: secondaryTextStyle(size: 14, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                if ((obverseText != null && obverseText.isNotEmpty) &&
                    (reverseText != null && reverseText.isNotEmpty)) ...[
                  16.height,
                  Divider(color: numBorder, height: 1),
                  16.height,
                ],
                if (reverseText != null && reverseText.isNotEmpty) ...[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        margin: const EdgeInsets.only(top: 6, right: 8),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('reverse'),
                              style: boldTextStyle(size: 14, color: Colors.red),
                            ),
                            4.height,
                            Text(
                              reverseText,
                              style: secondaryTextStyle(size: 14, height: 1.5),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ],

          80.height, // Bottom padding
        ],
      ),
    );
  }

  Widget _buildAncientMapTab(Variant v, AppLocalizations l10n) {
    if (v.coordinates == null || v.coordinates!.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map_outlined, size: 64, color: numTextSecondary.withValues(alpha: 0.5)),
            16.height,
            Text(l10n.translate('coordinates'), style: secondaryTextStyle(size: 14)),
            8.height,
            Text('-', style: boldTextStyle(size: 16)),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Yatay mod için bilgi mesajı
        Container(
          padding: const EdgeInsets.all(12),
          color: numPrimary.withValues(alpha: 0.1),
          child: Row(
            children: [
              const Icon(Icons.screen_rotation, size: 20, color: numPrimary),
              12.width,
              Expanded(
                child: Text(
                  'Haritayı tam ekran görmek için telefonunuzu yatay çevirin',
                  style: secondaryTextStyle(size: 12, color: numPrimary),
                ),
              ),
            ],
          ),
        ),
        // Harita preview alanı
        Expanded(
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
                              style: boldTextStyle(size: 18, color: Colors.white),
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
                                style: secondaryTextStyle(size: 12, color: Colors.white70),
                              ),
                            ),
                            24.height,
                            Text(
                              l10n.translate('tap_for_fullscreen'),
                              style: secondaryTextStyle(size: 12, color: Colors.white60),
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown,
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
                      foregroundColor: numPrimary,
                      side: const BorderSide(color: numPrimary),
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
    if (_images.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported, size: 64, color: numTextSecondary.withValues(alpha: 0.5)),
            16.height,
            Text(l10n.translate('no_images_found'), style: secondaryTextStyle(size: 14)),
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
              color: Colors.white,
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
                                style: boldTextStyle(size: 10, color: Colors.white),
                              ),
                            if (img.weight != null && img.diameter != null) 8.width,
                            if (img.diameter != null && img.diameter!.isNotEmpty)
                              Text(
                                '${img.diameter}mm',
                                style: boldTextStyle(size: 10, color: Colors.white),
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
                      style: boldTextStyle(size: 18, color: numPrimary),
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
                    foregroundColor: numPrimary,
                    side: const BorderSide(color: numPrimary),
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
                Text(
                  v.sourceCitation!,
                  style: secondaryTextStyle(size: 14, height: 1.5),
                ),
              ],
            ),
          ],
          if (v.findspotName != null && v.findspotName!.isNotEmpty) ...[
            16.height,
            _buildInfoCard(
              title: l10n.translate('findspot'),
              icon: Icons.place,
              children: [
                Text(
                  v.findspotName!,
                  style: secondaryTextStyle(size: 14),
                ),
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

  Widget _buildInfoCard({
    required String title,
    required IconData icon,
    Color? iconColor,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
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
              Icon(icon, size: 20, color: iconColor ?? numPrimary),
              8.width,
              Text(title, style: boldTextStyle(size: 16)),
            ],
          ),
          12.height,
          Divider(color: numBorder, height: 1),
          12.height,
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: secondaryTextStyle(size: 14)),
          ),
          Expanded(
            child: Text(value, style: primaryTextStyle(size: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    final l10n = AppLocalizations.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          16.height,
          Text(_error!, style: boldTextStyle(size: 16, color: Colors.red)),
          16.height,
          ElevatedButton.icon(
            onPressed: () => GoRouter.of(context).pop(),
            icon: const Icon(Icons.arrow_back),
            label: Text(l10n.translate('go_back')),
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _SliverTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _SliverTabBarDelegate oldDelegate) => false;
}
