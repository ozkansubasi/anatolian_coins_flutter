import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../core/coin_format.dart';
import '../../core/navigation.dart';
import '../../models/variant.dart';
import '../../core/region_data.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../core/num_colors.dart';
import '../../widgets/fallback_image.dart';
import '../../l10n/app_localizations.dart';
import 'variants_api.dart';
import '../ticker/ticker_widget.dart';

class ProkitVariantListPage extends ConsumerStatefulWidget {
  const ProkitVariantListPage({super.key});

  @override
  ConsumerState<ProkitVariantListPage> createState() => _ProkitVariantListPageState();
}

class _ProkitVariantListPageState extends ConsumerState<ProkitVariantListPage> {
  final _scroll = ScrollController();
  final _items = <Variant>[];
  final _searchCtrl = TextEditingController();

  String? _selectedRegion;
  String? _selectedMint;
  String? _selectedMaterial;

  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _onlyImages = true; // Default: görseli olmayan sikkeleri gizle
  String _sort = 'uid_asc';
  bool _isGridView = true;
  bool _initialLoad = false;
  String? _errorMessage;

  final Map<int, Map<String, String?>> _thumbnailCache = {};

  List<Variant> get _filteredItems {
    if (!_onlyImages) return _items;
    return _items.where((v) {
      if (_thumbnailCache.containsKey(v.articleId)) {
        final imageData = _thumbnailCache[v.articleId];
        if (imageData == null) return false;
        final url = imageData['url'];
        final remoteUrl = imageData['remoteUrl'];
        return (url != null && url.isNotEmpty) || (remoteUrl != null && remoteUrl.isNotEmpty);
      }
      return false;
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200 &&
        !_loading &&
        _hasMore) {
      _page++;
      _load();
    }
  }

  /// Son uygulanan `?region=&mint=&search=` sorgusu.
  ///
  /// Keşfet sekmesi `StatefulShellRoute` dalında canlı tutulur: sayfa yeniden
  /// kurulmaz, yalnız `didChangeDependencies` tetiklenir. Bu yüzden parametreler
  /// "ilk yüklemede bir kez" değil, sorgu her DEĞİŞTİĞİNDE uygulanır; aksi hâlde
  /// Bölgeler'den ikinci kez gelindiğinde eski filtre ekranda kalırdı.
  String? _appliedQuery;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final uri = GoRouterState.of(context).uri;
    if (uri.query.isEmpty || uri.query == _appliedQuery) return;
    _appliedQuery = uri.query;

    String? param(String key) {
      final v = uri.queryParameters[key]?.trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    final regionParam = param('region');
    final mintParam = param('mint');
    final searchParam = param('search');
    if (regionParam == null && mintParam == null && searchParam == null) return;

    // Bağlantı tam bir filtre tanımlar: önceki seçimler taşınmaz.
    _searchCtrl.text = searchParam ?? '';
    _selectedRegion = regionParam;
    _selectedMint = mintParam;
    _selectedMaterial = null;
    setState(() {});
    _load(reset: true);
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Sunucu geniş sorguları reddeder (filtresiz → 422, yalnız materyal → 400;
  /// ADR-005 kopyalama koruması). Bölge, darphane ya da arama metni olmadan
  /// istek atılmaz; kullanıcıya ne seçmesi gerektiği gösterilir.
  bool get _hasNarrowingFilter =>
      _selectedRegion != null ||
      (_selectedMint?.isNotEmpty ?? false) ||
      _searchCtrl.text.trim().isNotEmpty;

  void _showNeedsFilter() {
    setState(() {
      _items.clear();
      _thumbnailCache.clear();
      _page = 1;
      _hasMore = false;
      _errorMessage = null;
      _initialLoad = false;
    });
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (!_hasNarrowingFilter) {
      _showNeedsFilter();
      return;
    }

    setState(() {
      _loading = true;
      if (!_initialLoad) _initialLoad = true;
    });

    if (reset) {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _thumbnailCache.clear();
      _errorMessage = null;
    }

    final api = ref.read(variantsApiProvider);
    try {
      final mintParam = _searchCtrl.text.trim().isNotEmpty
          ? _searchCtrl.text.trim()
          : _selectedMint;

      final (list, meta) = await api.list(
        region: _selectedRegion,
        mint: mintParam,
        material: _selectedMaterial,
        hasImages: false,
        page: _page,
        perPage: 20,
        sort: _sort,
      );

      if (mounted) {
        setState(() {
          _items.addAll(list);
          final total = (meta['total'] ?? 0) as int;
          _hasMore = _items.length < total;
        });
        _loadThumbnails(list);
      }
    } catch (e) {
      final status = e is DioException ? e.response?.statusCode : null;
      if (mounted && (status == 400 || status == 422)) {
        // Sunucu sorguyu fazla geniş buldu: hata değil, yönlendirme.
        _showNeedsFilter();
        return;
      }
      if (mounted) {
        final l10n = AppLocalizations.of(context);
        final String errorMsg;
        if (e.toString().contains('timeout') || e.toString().contains('SocketException')) {
          errorMsg = l10n.translate('error_network');
        } else if (e.toString().contains('404')) {
          errorMsg = l10n.translate('no_results');
        } else {
          errorMsg = l10n.translate('error_generic');
        }
        setState(() => _errorMessage = errorMsg);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadThumbnails(List<Variant> variants) async {
    final api = ref.read(variantsApiProvider);
    for (final variant in variants) {
      if (_thumbnailCache.containsKey(variant.articleId)) continue;
      try {
        final imgs = await api.images(variant.articleId, wm: true, abs: true);
        if (imgs.isNotEmpty && mounted) {
          final firstImage = imgs.first;
          setState(() {
            _thumbnailCache[variant.articleId] = {
              'url': firstImage.url,
              'remoteUrl': firstImage.remoteUrl,
            };
          });
        } else if (mounted) {
          setState(() {
            _thumbnailCache[variant.articleId] = {'url': null, 'remoteUrl': null};
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _thumbnailCache[variant.articleId] = {'url': null, 'remoteUrl': null};
          });
        }
      }
    }
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true, // alt çubuğun üstünde, daha çok yer
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _FilterBottomSheet(
        selectedRegion: _selectedRegion,
        selectedMaterial: _selectedMaterial,
        onlyImages: _onlyImages,
        sort: _sort,
        onApply: (region, material, onlyImages, sort) {
          setState(() {
            _selectedRegion = region;
            _selectedMaterial = material;
            _onlyImages = onlyImages;
            _sort = sort;
          });
          _load(reset: true);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: _buildAppBar(l10n),
      body: Column(
        children: [
          // Region header image when region is selected
          if (_selectedRegion != null) _buildRegionHeader(),
          // Ticker for region facts
          // Kısa bant: başlık bölümü sonuçlara yer bırakmalı (2026-09-26 cihaz
          // incelemesi: görsel + bant + arama + çipler ekranın ~%65'iydi).
          // 66: üç satır (14 pt başlık + 12 pt metin) + 2x4 dolgu. 60'ta üçüncü
          // satır kutudan taşıyor, altındaki arama bloğunun altında kalıyordu.
          if (_selectedRegion != null) RegionTicker(region: _selectedRegion!, height: 66, maxLines: 3),
          _buildSearchBar(l10n),
          _buildFilterChips(l10n),
          Expanded(child: _buildContent(l10n)),
        ],
      ),
      // Alt çubuk kabukta (NumShellScaffold); ekran kendi çubuğunu koymaz.
    );
  }
  
  Widget _buildRegionHeader() {
    // Get region banner path
    final baseName = _selectedRegion!.replaceAll('-coins', '').replaceAll('-', '_');
    String bannerPath;
    if (baseName.contains('other')) {
      bannerPath = 'assets/images/regions/other_ancient_regions_banner.jpg';
    } else {
      bannerPath = 'assets/images/regions/${baseName}_banner.jpg';
    }
    
    final regionName = RegionData.getRegionName(_selectedRegion, AppLocalizations.of(context));
    
    return Container(
      width: double.infinity,
      height: 96,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Banner image background
          Image.asset(
            bannerPath,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              decoration: const BoxDecoration(
                gradient: numGradientPrimary,
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -30,
                    top: -30,
                    child: Icon(
                      Icons.location_on,
                      size: 180,
                      color: Colors.white.withValues(alpha: 0.1),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Gradient overlay for text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.2),
                  Colors.black.withValues(alpha: 0.6),
                ],
              ),
            ),
          ),
          // Region name at bottom
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  regionName,
                  style: boldTextStyle(size: 18, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                4.height,
                Text(
                  AppLocalizations.of(context).translate('ancient_anatolia'),
                  style: secondaryTextStyle(size: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(AppLocalizations l10n) {
    return AppBar(
      leading: context.returnLeading,
      title: Text(
        l10n.translate('browse_coins'),
        style: boldTextStyle(size: 18, color: Colors.white),
      ),
      backgroundColor: numPrimary,
      iconTheme: const IconThemeData(color: Colors.white),
      actions: [
        IconButton(
          icon: const Icon(Icons.filter_list),
          onPressed: _showFilterBottomSheet,
        ),
        IconButton(
          icon: Icon(_isGridView ? Icons.view_list : Icons.grid_view),
          onPressed: () => setState(() => _isGridView = !_isGridView),
        ),
      ],
    );
  }

  /// Arama bloğu: alçak (dikey 10) ve alan %80 genişlikte, ortalı
  /// (kullanıcı kararı 2026-09-26: bant metnine yer açmak için).
  Widget _buildSearchBar(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: numPrimary,
        boxShadow: [
          BoxShadow(
            color: numPrimary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: FractionallySizedBox(
        widthFactor: 0.8,
        child: Container(
        decoration: BoxDecoration(
          color: context.numColors.card,
          borderRadius: BorderRadius.circular(12),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: primaryTextStyle(size: 14, color: context.numColors.text),
          decoration: InputDecoration(
            hintText: l10n.translate('search_hint'),
            hintStyle: secondaryTextStyle(size: 14, color: context.numColors.textMuted),
            prefixIcon: Icon(Icons.search, color: context.numColors.textMuted),
            suffixIcon: _searchCtrl.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.clear, color: context.numColors.textMuted),
                    onPressed: () {
                      _searchCtrl.clear();
                      _load(reset: true);
                    },
                  )
                : null,
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          ),
          onSubmitted: (_) => _load(reset: true),
        ),
      ),
      ),
    );
  }

  Widget _buildFilterChips(AppLocalizations l10n) {
    final chips = <Widget>[];

    if (_selectedRegion != null) {
      chips.add(_FilterChipIcon(
        icon: Icons.location_on,
        label: RegionData.getRegionName(_selectedRegion, l10n),
        onRemove: () {
          setState(() => _selectedRegion = null);
          _load(reset: true);
        },
      ));
    }

    if (_selectedMaterial != null) {
      chips.add(_FilterChipIcon(
        icon: Icons.circle,
        label: CoinFormat.material(_selectedMaterial, l10n) ?? _selectedMaterial!,
        color: _getMaterialColorStatic(_selectedMaterial!),
        onRemove: () {
          setState(() => _selectedMaterial = null);
          _load(reset: true);
        },
      ));
    }

    if (_onlyImages) {
      chips.add(_FilterChipIcon(
        icon: Icons.image,
        label: l10n.translate('filter_images_only'),
        onRemove: () {
          setState(() => _onlyImages = false);
        },
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    // Wrap: çipler taşarsa alt satıra iner (yatay kaydırma gizli kalıyordu).
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Wrap(spacing: 8, runSpacing: 4, children: chips),
    );
  }

  Color _getMaterialColorStatic(String material) {
    switch (material.toUpperCase()) {
      case 'AU':
      case 'GOLD':
        return const Color(0xFFD4AF37);
      case 'AR':
      case 'SILVER':
        return const Color(0xFF8C8C8C);
      case 'AE':
      case 'BRONZE':
        return const Color(0xFFCD7F32);
      default:
        return numTextSecondary;
    }
  }

  Widget _buildContent(AppLocalizations l10n) {
    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator(color: numPrimary));
    }

    if (_errorMessage != null) {
      return _buildErrorState(l10n);
    }

    if (_filteredItems.isEmpty) {
      return _buildEmptyState(l10n);
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      color: numPrimary,
      // Kalıcı scrollbar: listenin uzunluğu/konumu görünür olsun
      child: Scrollbar(
        controller: _scroll,
        thumbVisibility: true,
        interactive: true,
        radius: const Radius.circular(8),
        child: _isGridView ? _buildGridView() : _buildListView(),
      ),
    );
  }

  Widget _buildErrorState(AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
          16.height,
          Text(
            _errorMessage!,
            style: boldTextStyle(size: 16, color: Colors.red[600]),
            textAlign: TextAlign.center,
          ),
          16.height,
          ElevatedButton.icon(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.translate('retry')),
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n) {
    if (_onlyImages && _items.isNotEmpty &&
        _items.any((v) => !_thumbnailCache.containsKey(v.articleId))) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: numPrimary),
            16.height,
            Text(
              l10n.translate('loading'),
              style: secondaryTextStyle(size: 14, color: context.numColors.textMuted),
            ),
          ],
        ),
      );
    }

    if (!_initialLoad) return _buildRegionPicker(l10n);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: context.numColors.textMuted),
          16.height,
          Text(
            l10n.translate('no_results'),
            style: boldTextStyle(size: 16, color: context.numColors.text),
          ),
          8.height,
          Text(
            l10n.translate('try_different_filters'),
            textAlign: TextAlign.center,
            style: secondaryTextStyle(size: 14, color: context.numColors.textMuted),
          ),
        ],
      ),
    );
  }

  /// Başlangıç: bölgeler doğrudan seçilebilir. Eskiden "Yukarıdan bölge veya
  /// darphane seçin" yazıyordu ama yukarıda seçici yoktu — seçim yalnız filtre
  /// ikonunun içindeydi (2026-09-26 cihaz incelemesi).
  Widget _buildRegionPicker(AppLocalizations l10n) {
    final c = context.numColors;
    final regions = RegionData.getRegionsByPopularity(l10n);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('start_searching'), style: boldTextStyle(size: 16, color: c.text)),
          6.height,
          Text(
            l10n.translate(_selectedMaterial != null ? 'material_needs_region' : 'choose_region_or_search'),
            style: secondaryTextStyle(size: 13, color: c.textMuted),
          ),
          16.height,
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in regions)
                ActionChip(
                  avatar: Icon(Icons.location_on_outlined, size: 16, color: c.accent),
                  label: Text(r.value, style: TextStyle(fontSize: 13, color: c.text)),
                  backgroundColor: c.card,
                  side: BorderSide(color: c.border),
                  shape: const StadiumBorder(),
                  onPressed: () {
                    setState(() => _selectedRegion = r.key);
                    _load(reset: true);
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildGridView() {
    return GridView.builder(
      controller: _scroll,
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1, // %25 daha küçük görsel (0.9 -> 1.1)
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _filteredItems.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _filteredItems.length) {
          return const Center(
            child: CircularProgressIndicator(color: numPrimary),
          );
        }
        return _CoinGridCard(
          variant: _filteredItems[index],
          thumbnailData: _thumbnailCache[_filteredItems[index].articleId],
          onTap: () => context.push('/variant/${_filteredItems[index].articleId}'),
        );
      },
    );
  }

  Widget _buildListView() {
    return ListView.separated(
      controller: _scroll,
      padding: const EdgeInsets.all(16),
      itemCount: _filteredItems.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => 12.height,
      itemBuilder: (context, index) {
        if (index >= _filteredItems.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: numPrimary),
            ),
          );
        }
        return _CoinListCard(
          variant: _filteredItems[index],
          thumbnailData: _thumbnailCache[_filteredItems[index].articleId],
          onTap: () => context.push('/variant/${_filteredItems[index].articleId}'),
        );
      },
    );
  }
}

// ==================== COIN GRID CARD ====================
class _CoinGridCard extends StatelessWidget {
  final Variant variant;
  final Map<String, String?>? thumbnailData;
  final VoidCallback onTap;

  const _CoinGridCard({
    required this.variant,
    required this.thumbnailData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return GestureDetector(
      onTap: onTap,
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Container(
                decoration: BoxDecoration(
                  // Fotoğraf plakası her temada beyaz: müze fotoğrafları beyaz
                  // fonlu; koyu kartta farklı genişlikte beyaz bloklar oluşuyordu
                  // (cihazda görüldü). Sikke detayındaki slider ile aynı karar.
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                ),
                child: Stack(
                  children: [
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      child: thumbnailData != null
                          ? SizedBox.expand(
                              child: FallbackImage(
                                url: thumbnailData!['url'],
                                remoteUrl: thumbnailData!['remoteUrl'],
                                fit: BoxFit.contain, // Görseli kırpmadan sığdır
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.monetization_on_outlined,
                                size: 48,
                                color: c.textMuted.withValues(alpha: 0.5),
                              ),
                            ),
                    ),
                    // Material badge
                    if (variant.material != null)
                      Positioned(
                        top: 4,
                        left: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getMaterialColor(variant.material!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            CoinFormat.material(variant.material, AppLocalizations.of(context)) ?? variant.material!,
                            style: boldTextStyle(size: 8, color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            // Content
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.title,
                      style: boldTextStyle(size: 10, color: c.text),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined, size: 10, color: c.textMuted),
                        2.width,
                        Expanded(
                          child: Text(
                            RegionData.getRegionName(variant.regionCode, AppLocalizations.of(context)),
                            style: secondaryTextStyle(size: 8, color: c.textMuted),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getMaterialColor(String material) {
    switch (material.toUpperCase()) {
      case 'AU':
      case 'GOLD':
        return const Color(0xFFD4AF37);
      case 'AR':
      case 'SILVER':
        return const Color(0xFF8C8C8C);
      case 'AE':
      case 'BRONZE':
        return const Color(0xFFCD7F32);
      default:
        return numTextSecondary;
    }
  }
}

// ==================== COIN LIST CARD ====================
class _CoinListCard extends StatelessWidget {
  final Variant variant;
  final Map<String, String?>? thumbnailData;
  final VoidCallback onTap;

  const _CoinListCard({
    required this.variant,
    required this.thumbnailData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.white, // fotoğraf plakası (grid kartıyla aynı)
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: thumbnailData != null
                    ? FallbackImage(
                        url: thumbnailData!['url'],
                        remoteUrl: thumbnailData!['remoteUrl'],
                        fit: BoxFit.cover,
                      )
                    : Icon(
                        Icons.monetization_on_outlined,
                        size: 32,
                        color: c.textMuted.withValues(alpha: 0.5),
                      ),
              ),
            ),
            16.width,
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variant.title,
                    style: boldTextStyle(size: 14, color: c.text),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  8.height,
                  Row(
                    children: [
                      if (variant.material != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: numPrimary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            CoinFormat.material(variant.material, AppLocalizations.of(context)) ?? variant.material!,
                            style: boldTextStyle(size: 10, color: c.accent),
                          ),
                        ),
                        8.width,
                      ],
                      Icon(Icons.location_on_outlined, size: 14, color: c.textMuted),
                      4.width,
                      Expanded(
                        child: Text(
                          RegionData.getRegionName(variant.regionCode, AppLocalizations.of(context)),
                          style: secondaryTextStyle(size: 12, color: c.textMuted),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Arrow
            Icon(Icons.chevron_right, color: c.textMuted),
          ],
        ),
      ),
    );
  }
}

// ==================== FILTER CHIP ====================
/// Etkin filtre: ikon + ad + kaldır. InputChip dokunma alanını 48 dp'ye tamamlar;
/// eski ikon-yalnız çipte kaldırma düğmesi ~16 px'ti ve hangi filtrenin seçili
/// olduğu yalnız uzun basınca görünüyordu.
class _FilterChipIcon extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  final VoidCallback onRemove;

  const _FilterChipIcon({
    required this.icon,
    required this.label,
    this.color,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return InputChip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, size: 14, color: color ?? c.accent),
      label: Text(label, style: secondaryTextStyle(size: 12, color: c.text)),
      onDeleted: onRemove,
      deleteIcon: Icon(Icons.close, size: 16, color: c.accent),
      deleteButtonTooltipMessage: MaterialLocalizations.of(context).deleteButtonTooltip,
      backgroundColor: numPrimary.withValues(alpha: 0.1),
      side: BorderSide(color: numPrimary.withValues(alpha: 0.3)),
      shape: const StadiumBorder(),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}

// ==================== FILTER BOTTOM SHEET ====================
class _FilterBottomSheet extends StatefulWidget {
  final String? selectedRegion;
  final String? selectedMaterial;
  final bool onlyImages;
  final String sort;
  final Function(String?, String?, bool, String) onApply;

  const _FilterBottomSheet({
    required this.selectedRegion,
    required this.selectedMaterial,
    required this.onlyImages,
    required this.sort,
    required this.onApply,
  });

  @override
  State<_FilterBottomSheet> createState() => _FilterBottomSheetState();
}

class _FilterBottomSheetState extends State<_FilterBottomSheet> {
  late String? _region;
  late String? _material;
  late bool _onlyImages;
  late String _sort;

  /// API kodları (`/v1/materials`). Eskiden AU/AR/AE kısaltmaları gidiyordu;
  /// sunucu tanımayınca 500 dönüyordu (2026-09-26 cihaz testi, Bitinya + altın).
  final _materials = ['gold', 'silver', 'bronze', 'electrum', 'lead'];

  @override
  void initState() {
    super.initState();
    _region = widget.selectedRegion;
    _material = widget.selectedMaterial;
    _onlyImages = widget.onlyImages;
    _sort = widget.sort;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    final regions = RegionData.getRegionsByPopularity(l10n);

    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: c.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.translate('filter'),
                  style: boldTextStyle(size: 18, color: c.text),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _region = null;
                      _material = null;
                      _onlyImages = true;
                      _sort = 'uid_asc';
                    });
                  },
                  child: Text(
                    l10n.translate('reset_filters'),
                    style: boldTextStyle(size: 14, color: c.accent),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          // Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Regions
                  Text(
                    l10n.translate('select_region'),
                    style: boldTextStyle(size: 14, color: c.text),
                  ),
                  12.height,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChoiceChip(
                        label: l10n.translate('all_regions'),
                        selected: _region == null,
                        onSelected: () => setState(() => _region = null),
                      ),
                      ...regions.map((e) => _buildChoiceChip(
                        label: e.value,
                        selected: _region == e.key,
                        onSelected: () => setState(() => _region = e.key),
                      )),
                    ],
                  ),
                  24.height,

                  // Materials
                  Text(
                    l10n.translate('material'),
                    style: boldTextStyle(size: 14, color: c.text),
                  ),
                  12.height,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChoiceChip(
                        label: l10n.translate('all_materials'),
                        selected: _material == null,
                        onSelected: () => setState(() => _material = null),
                      ),
                      ..._materials.map((m) => _buildChoiceChip(
                        label: _getMaterialLabel(l10n, m),
                        selected: _material == m,
                        onSelected: () => setState(() => _material = m),
                      )),
                    ],
                  ),
                  24.height,

                  // Sort
                  Text(
                    l10n.translate('sorting'),
                    style: boldTextStyle(size: 14, color: c.text),
                  ),
                  12.height,
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildChoiceChip(
                        label: l10n.translate('sort_default'),
                        selected: _sort == 'uid_asc',
                        onSelected: () => setState(() => _sort = 'uid_asc'),
                      ),
                      _buildChoiceChip(
                        label: l10n.translate('sort_reverse'),
                        selected: _sort == 'uid_desc',
                        onSelected: () => setState(() => _sort = 'uid_desc'),
                      ),
                      _buildChoiceChip(
                        label: l10n.translate('sort_recent'),
                        selected: _sort == 'updated_at_desc',
                        onSelected: () => setState(() => _sort = 'updated_at_desc'),
                      ),
                    ],
                  ),
                  24.height,

                  // Only images toggle - x/check işaretli
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.translate('filter_images_only'),
                              style: boldTextStyle(size: 14, color: c.text),
                            ),
                            4.height,
                            Text(
                              l10n.translate('hide_no_images'),
                              style: secondaryTextStyle(size: 12, color: c.textMuted),
                            ),
                          ],
                        ),
                      ),
                      _ToggleWithIcon(
                        value: _onlyImages,
                        onChanged: (v) => setState(() => _onlyImages = v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Bottom buttons - Geri + Uygula
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Geri butonu
                  Expanded(
                    flex: 1,
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: c.textMuted,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: c.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.arrow_back, size: 18),
                          6.width,
                          Text(
                            l10n.translate('cancel'),
                            style: boldTextStyle(size: 14, color: c.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                  12.width,
                  // Uygula butonu
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onApply(_region, _material, _onlyImages, _sort);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: numPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, size: 18),
                          6.width,
                          Text(
                            l10n.translate('apply_filters'),
                            style: boldTextStyle(size: 14, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getMaterialLabel(AppLocalizations l10n, String material) =>
      CoinFormat.material(material, l10n) ?? material;

  Widget _buildChoiceChip({
    required String label,
    required bool selected,
    required VoidCallback onSelected,
  }) {
    return GestureDetector(
      onTap: onSelected,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? numPrimary : context.numColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? numPrimary : context.numColors.border,
          ),
        ),
        child: Text(
          label,
          style: boldTextStyle(
            size: 12,
            color: selected ? Colors.white : context.numColors.text,
          ),
        ),
      ),
    );
  }
}

// ==================== TOGGLE WITH X/CHECK ICON ====================
class _ToggleWithIcon extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleWithIcon({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 60,
        height: 32,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: value ? numPrimary : context.numColors.border,
          borderRadius: BorderRadius.circular(16),
        ),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: value
                    ? Icon(
                        Icons.check,
                        key: const ValueKey('check'),
                        size: 18,
                        color: numPrimary,
                      )
                    : Icon(
                        Icons.close,
                        key: const ValueKey('close'),
                        size: 18,
                        color: numTextSecondary,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
