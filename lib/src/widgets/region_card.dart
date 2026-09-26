import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

import '../prokit_ui/numistr_colors.dart';

/// Bölge kartı: bölge banner görseli + koyu geçiş + ikon ve ad.
///
/// Bölgeler sayfası (ızgara) ve ana sayfa (yatay şerit) aynı kartı kullanır;
/// ana sayfadaki eski yuvarlak ikonlar sayfalar arası bütünlüğü bozuyordu
/// (kullanıcı kararı 2026-09-26). [compact] ana sayfanın dar kartı içindir.
class RegionCard extends StatelessWidget {
  final String regionCode;
  final String regionName;
  final VoidCallback onTap;
  final bool compact;

  const RegionCard({
    super.key,
    required this.regionCode,
    required this.regionName,
    required this.onTap,
    this.compact = false,
  });

  String get _baseName =>
      regionCode.replaceAll('-coins', '').replaceAll('-', '_');

  String _assetPath(String suffix) => _baseName.contains('other')
      ? 'assets/images/regions/other_ancient_regions_$suffix'
      : 'assets/images/regions/${_baseName}_$suffix';

  @override
  Widget build(BuildContext context) {
    final color = getRegionColor(regionCode.replaceAll('-coins', ''));
    final radius = BorderRadius.circular(compact ? 12 : 16);
    final iconSize = compact ? 26.0 : 36.0;
    final inset = compact ? 8.0 : 12.0;

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
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.location_on,
                            color: Colors.white,
                            size: iconSize * 0.55,
                          ),
                        ),
                      ),
                    ),
                    (compact ? 6 : 8).width,
                    Expanded(
                      child: Text(
                        regionName,
                        style: boldTextStyle(
                            size: compact ? 12 : 14, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!compact)
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
