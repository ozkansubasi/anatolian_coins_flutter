import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../core/region_data.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../core/num_colors.dart';
import '../../core/num_text.dart';
import '../../l10n/app_localizations.dart';
import '../variants/variants_api.dart';

/// Açılan bölgenin canlı darphane sayıları (bölge başına bir istek, önbellekli).
final _mintCountsProvider = FutureProvider.family<Map<String, int>, String>(
  (ref, region) => ref.read(variantsApiProvider).mintCounts(region),
);

/// Tüm darphaneleri bölgelere göre gruplandırarak listeleyen sayfa
class MintsListPage extends StatefulWidget {
  const MintsListPage({super.key});

  @override
  State<MintsListPage> createState() => _MintsListPageState();
}

class _MintsListPageState extends State<MintsListPage> {
  String? _expandedRegion;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<MapEntry<String, String>> _getFilteredRegions() {
    final regions = RegionData.getRegionsByPopularity(AppLocalizations.of(context));
    if (_searchQuery.isEmpty) return regions;

    // Filter regions that have mints matching the search query
    return regions.where((region) {
      final mints = RegionData.getMintsForRegion(region.key);
      if (mints.isEmpty) return false;
      return mints.any((mint) =>
          _formatMintName(mint).toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();
  }

  List<String> _getFilteredMints(String regionCode) {
    final mints = RegionData.getMintsForRegion(regionCode);
    if (_searchQuery.isEmpty) return mints;
    return mints.where((mint) =>
        _formatMintName(mint).toLowerCase().contains(_searchQuery.toLowerCase())).toList();
  }

  /// Bölge ekini kırpar: "antiocheia_pisidia" → "Antiocheia" (başlık zaten
  /// bölge adını gösteriyor). Kırpınca boş kalırsa tam ad kullanılır.
  String _displayMintName(String mintCode, String regionCode) {
    final suffix = '_${regionCode.replaceAll('-coins', '')}';
    final base = mintCode.endsWith(suffix) && mintCode.length > suffix.length
        ? mintCode.substring(0, mintCode.length - suffix.length)
        : mintCode;
    return _formatMintName(base);
  }

  String _formatMintName(String mintCode) {
    // Convert mint code to readable name
    return mintCode
        .replaceAll('_', ' ')
        .split(' ')
        .map((word) => word.isNotEmpty
            ? word[0].toUpperCase() + word.substring(1).toLowerCase()
            : '')
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    final regions = _getFilteredRegions();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          l10n.translate('mints'),
          style: boldTextStyle(size: 18, color: Colors.white),
        ),
        backgroundColor: numPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          // Search bar
          Container(
            padding: const EdgeInsets.all(16),
            color: c.card,
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.translate('search_mints'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: c.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),
          // Regions list with expandable mints
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 100),
              itemCount: regions.length,
              itemBuilder: (context, index) {
                final region = regions[index];
                final mints = _getFilteredMints(region.key);
                if (mints.isEmpty) return const SizedBox.shrink();

                final isExpanded = _expandedRegion == region.key;

                return _RegionExpansionTile(
                  regionCode: region.key,
                  regionName: region.value,
                  mintCount: mints.length,
                  isExpanded: isExpanded,
                  onTap: () {
                    setState(() {
                      _expandedRegion = isExpanded ? null : region.key;
                    });
                  },
                  mints: mints,
                  searching: _searchQuery.isNotEmpty,
                  onMintTap: (mint) {
                    // Hem bölge hem mint filtresi ile git (daha hızlı sorgu)
                    // Mint adı veritabanındaki gerçek isim (nomisma.org formatında)
                    // push: geri tuşu darphane listesine dönsün (go yığını siliyordu).
                    // Odak bırakılır: yoksa dönüşte arama kutusu klavyeyi yeniden açıyordu.
                    FocusScope.of(context).unfocus();
                    context.push('/browse?region=${region.key}&mint=$mint');
                  },
                  formatMintName: (m) => _displayMintName(m, region.key),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _RegionExpansionTile extends StatelessWidget {
  final String regionCode;
  final String regionName;
  final int mintCount;
  final bool isExpanded;
  final VoidCallback onTap;
  final List<String> mints;
  final bool searching;
  final void Function(String) onMintTap;
  final String Function(String) formatMintName;

  const _RegionExpansionTile({
    required this.regionCode,
    required this.regionName,
    required this.mintCount,
    required this.isExpanded,
    required this.onTap,
    required this.mints,
    required this.searching,
    required this.onMintTap,
    required this.formatMintName,
  });

  String _getRegionIconPath() {
    final baseName = regionCode.replaceAll('-coins', '').replaceAll('-', '_');
    if (baseName.contains('other')) {
      return 'assets/images/regions/other_ancient_regions_ikon.png';
    }
    return 'assets/images/regions/${baseName}_ikon.png';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;

    return Column(
      children: [
        // Region header
        Material(
          color: c.card,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Region icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      // getRegionColor('-coins' eki kırpılınca hiç eşleşmiyordu → hep numPrimary).
                      color: c.accent.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _getRegionIconPath(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.location_on,
                          color: c.accent,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  12.width,
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(regionName, style: context.numText.section),
                        4.height,
                        Text(
                          AppLocalizations.of(context)
                              .translate('mint_count', params: {'n': '$mintCount'}),
                          style: context.numText.caption,
                        ),
                      ],
                    ),
                  ),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down,
                      color: c.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        // Mints list (expandable)
        AnimatedCrossFade(
          firstChild: const SizedBox.shrink(),
          // Açıkken canlı sayılar: sayıya göre sıralı, gömülü listede henüz
          // olmayan yeni darphaneler de eklenir (aramada yalnız eşleşenler).
          secondChild: !isExpanded
              ? const SizedBox.shrink()
              : Consumer(builder: (context, ref, _) {
                  final counts = ref.watch(_mintCountsProvider(regionCode)).valueOrNull;
                  final names = <String>{
                    ...mints,
                    if (counts != null && !searching) ...counts.keys,
                  }.toList();
                  if (counts != null) {
                    names.sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
                  }
                  return Container(
                    color: c.surface,
                    child: Column(
                      children: names
                          .map((mint) => _MintListItem(
                                mintCode: mint,
                                mintName: formatMintName(mint),
                                count: counts?[mint],
                                onTap: () => onMintTap(mint),
                              ))
                          .toList(),
                    ),
                  );
                }),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 200),
        ),
        Divider(height: 1, color: c.divider),
      ],
    );
  }
}

class _MintListItem extends StatelessWidget {
  final String mintCode;
  final String mintName;
  final int? count;
  final VoidCallback onTap;

  const _MintListItem({
    required this.mintCode,
    required this.mintName,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        // ≥ 48 dp dokunma hedefi (eskiden ~40 dp); ad, bölge adıyla hizalı
        // (16 + 40 ikon + 12). Süs noktası kaldırıldı.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(68, 8, 12, 8),
            child: Row(
              children: [
                Expanded(child: Text(mintName, style: context.numText.value)),
                if (count != null)
                  Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text('$count', style: context.numText.caption),
                  ),
                Icon(Icons.chevron_right, color: c.hint),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
