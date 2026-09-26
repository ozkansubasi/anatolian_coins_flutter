import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/variant_image.dart';

/// Görsel atfı: "Görsel: <kurum> · <lisans>" (ADR-008).
///
/// Kaynağı bilinmeyen görselde hiçbir şey çizmez. Lisans metni API'den
/// geldiği gibi gösterilir (ör. "CC BY 4.0", "PDM 1.0").
class ImageCredit extends StatelessWidget {
  final VariantImage image;
  final Color color;
  final double fontSize;
  final TextAlign textAlign;

  const ImageCredit({
    super.key,
    required this.image,
    this.color = Colors.white,
    this.fontSize = 11,
    this.textAlign = TextAlign.center,
  });

  static String? text(VariantImage image, AppLocalizations l10n) {
    final credit = image.credit;
    if (credit == null) return null;
    final license = image.license;
    return license == null
        ? l10n.translate('image_credit_no_license', params: {'credit': credit})
        : l10n.translate('image_credit', params: {'credit': credit, 'license': license});
  }

  @override
  Widget build(BuildContext context) {
    final label = text(image, AppLocalizations.of(context));
    if (label == null) return const SizedBox.shrink();
    return Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        shadows: const [Shadow(blurRadius: 3, color: Colors.black54)],
      ),
    );
  }
}
