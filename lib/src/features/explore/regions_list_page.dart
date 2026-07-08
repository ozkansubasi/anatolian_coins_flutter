import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../core/region_data.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../l10n/app_localizations.dart';

/// Tüm bölgeleri listeleyen sayfa
class RegionsListPage extends StatelessWidget {
  const RegionsListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final regions = RegionData.getRegionsByPopularity();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? numScaffoldDark : numScaffoldLight,
      appBar: AppBar(
        title: Text(
          l10n.translate('regions'),
          style: boldTextStyle(size: 18, color: Colors.white),
        ),
        backgroundColor: numPrimary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: GridView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 1.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemCount: regions.length,
        itemBuilder: (context, index) {
          final region = regions[index];
          return _RegionCard(
            regionCode: region.key,
            regionName: region.value,
            onTap: () => context.go('/browse?region=${region.key}'),
          );
        },
      ),
    );
  }
}

class _RegionCard extends StatelessWidget {
  final String regionCode;
  final String regionName;
  final VoidCallback onTap;

  const _RegionCard({
    required this.regionCode,
    required this.regionName,
    required this.onTap,
  });

  String _getRegionBannerPath() {
    final baseName = regionCode.replaceAll('-coins', '').replaceAll('-', '_');
    if (baseName.contains('other')) {
      return 'assets/images/regions/other_ancient_regions_banner.jpg';
    }
    return 'assets/images/regions/${baseName}_banner.jpg';
  }

  String _getRegionIconPath() {
    final baseName = regionCode.replaceAll('-coins', '').replaceAll('-', '_');
    if (baseName.contains('other')) {
      return 'assets/images/regions/other_ancient_regions_ikon.png';
    }
    return 'assets/images/regions/${baseName}_ikon.png';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Banner image
              Image.asset(
                _getRegionBannerPath(),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        getRegionColor(regionCode.replaceAll('-coins', '')),
                        getRegionColor(regionCode.replaceAll('-coins', '')).withValues(alpha: 0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
              // Gradient overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              // Content
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Row(
                  children: [
                    // Region icon
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          _getRegionIconPath(),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                    8.width,
                    Expanded(
                      child: Text(
                        regionName,
                        style: boldTextStyle(size: 14, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
