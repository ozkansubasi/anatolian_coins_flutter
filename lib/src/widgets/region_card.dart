import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import '../prokit_ui/numistr_colors.dart';

/// Bölge kartı: bölge banner görseli + koyu geçiş + ikon ve ad.
///
/// Bölgeler sayfasının ızgara kartı.
class RegionCard extends StatelessWidget {
  final String regionCode;
  final String regionName;
  final VoidCallback onTap;

  const RegionCard({
    super.key,
    required this.regionCode,
    required this.regionName,
    required this.onTap,
  });

  String get _baseName =>
      regionCode.replaceAll('-coins', '').replaceAll('-', '_');

  String _assetPath(String suffix) => _baseName.contains('other')
      ? 'assets/images/regions/other_ancient_regions_$suffix'
      : 'assets/images/regions/${_baseName}_$suffix';

  @override
  Widget build(BuildContext context) {
    final color = getRegionColor(regionCode.replaceAll('-coins', ''));
    final radius = BorderRadius.circular(16);
    const iconSize = 36.0;
    const inset = 12.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                _assetPath('banner.jpg'),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
              ),
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
              Positioned(
                left: inset,
                right: inset,
                bottom: inset,
                child: Row(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          _assetPath('ikon.png'),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: iconSize * 0.55,
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
