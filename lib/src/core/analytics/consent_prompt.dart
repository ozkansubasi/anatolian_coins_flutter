import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'app_analytics.dart';

/// İlk açılışta analitik onayını bir kez sorar (yalnız Firebase yapılandırılmış
/// derlemede ve karar henüz verilmemişse). Kabuğu sarar; kabuk her sekme
/// değişiminde yeniden kurulduğu için oturum başına tek gösterim bayrağı tutulur.
class ConsentGate extends ConsumerStatefulWidget {
  final Widget child;
  const ConsentGate({super.key, required this.child});

  @override
  ConsumerState<ConsentGate> createState() => _ConsentGateState();
}

class _ConsentGateState extends ConsumerState<ConsentGate> {
  static bool _shownThisSession = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  Future<void> _maybePrompt() async {
    if (_shownThisSession || !AppAnalytics.instance.isAvailable) return;
    if (ref.read(analyticsConsentProvider) != AnalyticsConsent.unknown) return;
    _shownThisSession = true;
    // Açılış çizimi otursun; pencere ilk karede belirmesin.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final granted = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AnalyticsConsentSheet(),
    );
    // Pencere bir şekilde karar verilmeden kapanırsa (sistem) karar yok sayılır,
    // sonraki açılışta yine sorulur; veri yine gitmez.
    if (granted != null) {
      await ref.read(analyticsConsentProvider.notifier).set(granted);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Onay penceresi. "İzin ver" ve "İzin verme" AYNI biçimde (UK ICO / AB: reddetmek
/// kabul etmek kadar belirgin ve kolay olmalı).
class AnalyticsConsentSheet extends StatelessWidget {
  const AnalyticsConsentSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget bullet(IconData icon, String key) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: numPrimary),
              const SizedBox(width: 10),
              Expanded(child: Text(l10n.translate(key), style: theme.textTheme.bodyMedium)),
            ],
          ),
        );

    return PopScope(
      canPop: false,
      child: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? numCardDark : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights_outlined, color: numPrimary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.translate('analytics_consent_title'),
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(l10n.translate('analytics_consent_body'), style: theme.textTheme.bodyMedium),
                const SizedBox(height: 14),
                bullet(Icons.check_circle_outline, 'analytics_consent_sent'),
                bullet(Icons.block_outlined, 'analytics_consent_not_sent'),
                bullet(Icons.shield_outlined, 'analytics_consent_no_ads'),
                bullet(Icons.settings_outlined, 'analytics_consent_change'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: numPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.translate('analytics_consent_deny')),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: numPrimary,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(48),
                        ),
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.translate('analytics_consent_allow')),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
