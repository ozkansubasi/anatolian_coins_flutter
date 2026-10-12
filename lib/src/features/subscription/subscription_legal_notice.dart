import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/num_colors.dart';
import '../../core/web_links.dart';
import '../../l10n/app_localizations.dart';

/// Satın alma seçeneklerinin altındaki yasal blok (App Store 3.1.2(a)):
/// otomatik yenileme koşulu (iOS'ta App Store / Apple ID, Android'de Google
/// Play) ve Kullanım Koşulları ile Gizlilik Politikası'na çalışan bağlantılar.
/// Sayfa adresi uygulama diline göre seçilir; site dışarıda açılır.
class SubscriptionLegalNotice extends StatelessWidget {
  const SubscriptionLegalNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    final languageCode = Localizations.localeOf(context).languageCode;
    final isIOS = Theme.of(context).platform == TargetPlatform.iOS;

    Widget link(String key, Uri url) => InkWell(
          onTap: () => launchUrl(url, mode: LaunchMode.externalApplication),
          borderRadius: BorderRadius.circular(4),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Text(
              l10n.translate(key),
              style: primaryTextStyle(size: 12, color: c.accent).copyWith(
                decoration: TextDecoration.underline,
                decorationColor: c.accent,
              ),
            ),
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.translate(isIOS
              ? 'subscription_auto_renew_ios'
              : 'subscription_auto_renew_android'),
          style: secondaryTextStyle(size: 11, color: c.textMuted),
        ),
        4.height,
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            link('terms_of_service', termsOfUseWebUrl(languageCode)),
            Text('·', style: secondaryTextStyle(size: 12, color: c.textMuted)),
            link('privacy_policy', privacyPolicyWebUrl(languageCode)),
          ],
        ),
      ],
    );
  }
}
