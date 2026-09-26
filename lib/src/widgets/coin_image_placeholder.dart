import 'package:flutter/material.dart';

import '../core/num_colors.dart';
import '../l10n/app_localizations.dart';

/// Görseli olmayan ya da yüklenemeyen sikke için yer tutucu: sikke ikonu +
/// "Görsel bulunamadı". Eskiden geniş beyaz alanda 24 px'lik kırık-görsel
/// ikonu kalıyordu, boş sayfa gibi görünüyordu (2026-09-26 cihaz testi).
class CoinImagePlaceholder extends StatelessWidget {
  /// Küçük kutularda (ızgara) yazı gizlenir.
  final bool compact;

  const CoinImagePlaceholder({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return Container(
      color: c.surface,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monetization_on_outlined, size: compact ? 32 : 64, color: c.textMuted.withValues(alpha: 0.6)),
          if (!compact) ...[
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context).translate('image_not_found'),
              style: TextStyle(color: c.textMuted, fontSize: 13),
            ),
          ],
        ],
      ),
    );
  }
}
