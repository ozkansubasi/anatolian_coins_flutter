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

  /// Görselin üstüne binerken okunaklılık için zemin (null = zeminsiz).
  final Color? background;

  const ImageCredit({
    super.key,
    required this.image,
    this.color = Colors.white,
    this.fontSize = 11,
    this.textAlign = TextAlign.center,
    this.background,
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
    final caption = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: textAlign,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        shadows: background == null ? const [Shadow(blurRadius: 3, color: Colors.black54)] : null,
      ),
    );
    if (background == null) return caption;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(10)),
      child: caption,
    );
  }
}
