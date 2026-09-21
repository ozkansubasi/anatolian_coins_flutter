import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../core/region_data.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';

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
    final regions = RegionData.getRegionsByPopularity();
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
                  onMintTap: (mint) {
                    // Hem bölge hem mint filtresi ile git (daha hızlı sorgu)
                    // Mint adı veritabanındaki gerçek isim (nomisma.org formatında)
                    context.go('/browse?region=${region.key}&mint=$mint');
                  },
                  formatMintName: _formatMintName,
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
  final void Function(String) onMintTap;
  final String Function(String) formatMintName;

  const _RegionExpansionTile({
    required this.regionCode,
    required this.regionName,
    required this.mintCount,
    required this.isExpanded,
    required this.onTap,
    required this.mints,
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
                      color: getRegionColor(regionCode.replaceAll('-coins', '')).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        _getRegionIconPath(),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          Icons.location_on,
                          color: getRegionColor(regionCode.replaceAll('-coins', '')),
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
                        Text(
                          regionName,
                          style: boldTextStyle(size: 16, color: c.text),
                        ),
                        4.height,
                        Text(
                          '$mintCount darphane',
                          style: secondaryTextStyle(size: 12, color: c.textMuted),
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
          secondChild: Container(
            color: c.surface,
            child: Column(
              children: mints.map((mint) => _MintListItem(
                mintCode: mint,
                mintName: formatMintName(mint),
                onTap: () => onMintTap(mint),
                regionColor: getRegionColor(regionCode.replaceAll('-coins', '')),
              )).toList(),
            ),
          ),
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
  final VoidCallback onTap;
  final Color regionColor;

  const _MintListItem({
    required this.mintCode,
    required this.mintName,
    required this.onTap,
    required this.regionColor,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              48.width, // Indent for alignment with region icon
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: regionColor,
                  shape: BoxShape.circle,
                ),
              ),
              12.width,
              Expanded(
                child: Text(
                  mintName,
                  style: primaryTextStyle(size: 14, color: c.text),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                size: 14,
                color: c.hint,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
