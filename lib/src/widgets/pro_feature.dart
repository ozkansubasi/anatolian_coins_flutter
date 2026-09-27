import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/num_colors.dart';
import '../core/num_text.dart';
import '../l10n/app_localizations.dart';
import '../prokit_ui/numistr_colors.dart';

/// Pro'ya özel özellikler için ortak parçalar: kilit penceresi, PRO rozeti ve
/// güncel harita (Google Haritalar) bağlantısı. Sikke sayfası ve tam ekran antik
/// harita aynı görünümü kullanır (2026-09-27).

/// "Pro özelliği" penceresi. [onBuy] abonelik sayfasına gider; tam ekran harita
/// gibi kök navigatördeki bir sayfadan çağrılıyorsa önce o sayfayı kapatmalıdır.
Future<void> showProFeatureDialog(
  BuildContext context, {
  required String featureName,
  required VoidCallback onBuy,
}) {
  final l10n = AppLocalizations.of(context);
  return showDialog<void>(
    context: context,
    builder: (context) {
      final c = context.numColors;
      return AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: numPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.lock, color: c.accent, size: 20),
            ),
            12.width,
            Text(l10n.translate('pro_feature'), style: context.numText.section),
          ],
        ),
        content: Text(
          l10n.translate('feature_locked_message', params: {'featureName': featureName}),
          style: context.numText.body.copyWith(color: c.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('close'), style: context.numText.value.copyWith(color: c.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onBuy();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(l10n.translate('buy_pro')),
          ),
        ],
      );
    },
  );
}

/// Küçük "PRO" rozeti (düğme ve bağlantıların yanında).
class ProBadge extends StatelessWidget {
  const ProBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: numPrimary,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        AppLocalizations.of(context).translate('plan_badge_pro'),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// Noktanın güncel haritadaki adresi (Google Haritalar arama bağlantısı).
Uri modernMapUri(double lat, double lng) =>
    Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');

/// Güncel haritayı dış uygulamada açar (Google Haritalar ya da tarayıcı).
Future<void> openInModernMap(double lat, double lng) async {
  final url = modernMapUri(lat, lng);
  try {
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  } catch (_) {
    // Açılamazsa sessiz: harita uygulaması/tarayıcı yok
  }
}
