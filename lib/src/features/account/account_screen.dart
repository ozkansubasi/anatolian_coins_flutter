import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../auth/auth_controller.dart';
import '../../core/free_trial.dart';
import '../../core/navigation.dart';
import '../../core/num_colors.dart';
import '../../core/web_links.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../core/subscription_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/brand_title.dart';
import '../recognition/recognition_service.dart';
import '../favorites/favorites_service.dart';
import '../collections/collections_service.dart';

/// Hesabım: marka başlığı + profil bandı (ad, e-posta, abonelik rozeti),
/// altında bağlantı listeleri (Hesabım / Yardım) ve istatistik kartları.
///
/// 2026-09-26 yeniden tasarım (kullanıcı kararı): eski abonelik kartı ayrıcalık
/// listesini tekrar ediyordu (Abonelik sayfasında zaten var) ve "Ücretsiz Üyelik >"
/// satırı, ücretsiz üyelik için tıklanacakmış gibi okunuyordu. Artık eylem açık:
/// "Abonelik Satın Al" (deneme varsa alt satırda yazar).
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: context.returnLeading,
        centerTitle: false,
        titleSpacing: context.returnLeading == null ? 16 : 0,
        // Profil bandıyla tek parça görünsün: kaydırınca gölge yok
        scrolledUnderElevation: 0,
        title: const BrandTitle(),
      ),
      body: authState.authenticated
          ? _AuthenticatedView(l10n: l10n, theme: theme)
          : _UnauthenticatedView(l10n: l10n, theme: theme),
    );
  }
}

/// Authenticated User View
class _AuthenticatedView extends ConsumerWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _AuthenticatedView({
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final quotaAsync = ref.watch(scanQuotaProvider);
    final authState = ref.watch(authControllerProvider);

    // Pro iki bağımsız kaynaktan gelebilir: mağaza (RevenueCat) VEYA site grubu
    // (yönetici/web aboneliği; /v1/user/scan-quota bildirir). Biri yeter.
    final joomlaIsPro = quotaAsync.maybeWhen(
      data: (quota) => quota.isPro,
      orElse: () => false,
    );
    final isPro = subscription.tier == SubscriptionTier.pro || joomlaIsPro;

    // Deneme etiketi: Google/Apple yalnız uygun olan kullanıcıya deneme teklifi
    // döndürür; etiket görünüyorsa kullanıcı gerçekten uygundur.
    final trialLabel = isPro
        ? null
        : ref.watch(offeringsProvider).maybeWhen(
              data: (offerings) {
                for (final p
                    in offerings?.current?.availablePackages ?? const []) {
                  final label = freeTrialLabel(p.storeProduct, l10n);
                  if (label != null) return label;
                }
                return null;
              },
              orElse: () => null,
            );

    final email = authState.email ?? '—';
    final languageCode = Localizations.localeOf(context).languageCode;

    return RefreshIndicator(
      color: numPrimary,
      onRefresh: () async {
        ref.invalidate(subscriptionProvider);
        ref.invalidate(scanQuotaProvider);
        ref.invalidate(offeringsProvider);
        ref.invalidate(favoritesControllerProvider);
        ref.invalidate(collectionsControllerProvider);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _ProfileHeader(
            name: authState.name,
            email: email,
            badge: l10n.translate(isPro ? 'plan_badge_pro' : 'plan_badge_free'),
            isPro: isPro,
          ),
          _SectionLabel(l10n.translate('account_title')),
          _MenuGroup(children: [
            if (isPro)
              _MenuItem(
                icon: Icons.workspace_premium_rounded,
                title: l10n.translate('manage_subscription'),
                subtitle: l10n.translate('pro_active_subtitle'),
                onTap: () => context.push('/subscription'),
              )
            else
              _MenuItem(
                icon: Icons.workspace_premium_rounded,
                title: l10n.translate('buy_subscription'),
                subtitle: trialLabel != null
                    ? l10n.translate('trial_start_subtitle',
                        params: {'trial': trialLabel})
                    : l10n.translate('buy_subscription_subtitle'),
                emphasize: true,
                onTap: () => context.push('/subscription'),
              ),
            if (!isPro)
              _MenuItem(
                icon: Icons.school_outlined,
                title: l10n.translate('university_pro_title'),
                subtitle: l10n.translate('university_pro_subtitle'),
                onTap: () => context.push('/university-application'),
              ),
            // Google girişli hesabın şifresi yok: satır yalnız şifreli hesapta
            if (authState.isPasswordAccount && authState.email != null)
              _MenuItem(
                icon: Icons.lock_outline_rounded,
                title: l10n.translate('change_password'),
                onTap: () => _changePassword(context, ref, authState.email!),
              ),
            _MenuItem(
              icon: Icons.smart_toy_outlined,
              title: l10n.translate('assistant_title'),
              onTap: () => context.push('/assistant'),
            ),
            _MenuItem(
              icon: Icons.settings_outlined,
              title: l10n.translate('settings'),
              onTap: () => context.push('/settings'),
            ),
          ]),
          _SectionLabel(l10n.translate('help')),
          _MenuGroup(children: [
            _MenuItem(
              icon: Icons.help_outline_rounded,
              title: l10n.translate('faq'),
              trailingIcon: Icons.open_in_new_rounded,
              onTap: () => launchUrl(faqWebUrl(languageCode),
                  mode: LaunchMode.externalApplication),
            ),
            _MenuItem(
              icon: Icons.privacy_tip_outlined,
              title: l10n.translate('privacy_policy'),
              onTap: () => context.push('/privacy-policy'),
            ),
            _MenuItem(
              icon: Icons.description_outlined,
              title: l10n.translate('terms_of_service'),
              onTap: () => context.push('/terms-of-service'),
            ),
          ]),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Kota kartı yalnız ücretsiz kullanıcıda. Kota alınamazsa
                // (ör. 401) kart gösterilmez; kritik değil.
                quotaAsync.when(
                  data: (quota) => isPro || quota.isPro
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _QuotaCard(
                              l10n: l10n, theme: theme, quota: quota),
                        ),
                  loading: () => const Padding(
                    padding: EdgeInsets.only(bottom: 16),
                    child: _LoadingCard(),
                  ),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                _UsageStatsCard(l10n: l10n, theme: theme),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await _showSignOutDialog(context, l10n);
                    if (confirm == true && context.mounted) {
                      // Ekran authState'i izler; çıkıştan sonra kendiliğinden
                      // giriş görünümüne döner (bulunduğu yerde kalır).
                      await ref.read(authControllerProvider.notifier).signOut();
                    }
                  },
                  icon: const Icon(Icons.logout_rounded),
                  label: Text(l10n.translate('sign_out')),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    foregroundColor: Colors.red,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changePassword(
      BuildContext context, WidgetRef ref, String email) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.lock_reset_rounded, color: numPrimary),
        title: Text(l10n.translate('change_password')),
        content: Text(l10n
            .translate('change_password_confirm', params: {'email': email})),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: numPrimary),
            child: Text(l10n.translate('send')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final sent = await ref
        .read(authControllerProvider.notifier)
        .requestPasswordReset(email);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(sent
          ? l10n.translate('change_password_sent', params: {'email': email})
          : l10n.translate('password_reset_failed')),
    ));
  }

  Future<bool?> _showSignOutDialog(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: Text(l10n.translate('sign_out')),
        content: Text(l10n.translate('sign_out_confirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text(l10n.translate('sign_out')),
          ),
        ],
      ),
    );
  }
}

/// Profil bandı: altın zemin, solda ad ve e-posta, sağda avatar + abonelik rozeti.
class _ProfileHeader extends StatelessWidget {
  final String? name;
  final String email;
  final String badge;
  final bool isPro;

  const _ProfileHeader({
    required this.name,
    required this.email,
    required this.badge,
    required this.isPro,
  });

  @override
  Widget build(BuildContext context) {
    final hasName = name != null && name!.isNotEmpty;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
      decoration: const BoxDecoration(
        color: numPrimary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hasName ? name! : email,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: hasName ? 22 : 17,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                if (hasName) ...[
                  const SizedBox(height: 4),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          _AvatarWithBadge(badge: badge, isPro: isPro),
        ],
      ),
    );
  }
}

class _AvatarWithBadge extends StatelessWidget {
  final String badge;
  final bool isPro;

  const _AvatarWithBadge({required this.badge, required this.isPro});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(Icons.person_rounded,
              size: 44, color: numPrimary.withValues(alpha: 0.55)),
        ),
        // Rozet avatarın alt kenarına biner (Pro: koyu altın; Ücretsiz: beyaz)
        Positioned(
          bottom: -10,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPro ? numPrimaryDark : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: isPro ? Colors.white : numPrimary, width: 1.2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPro) ...[
                  const Icon(Icons.star_rounded, size: 12, color: Colors.white),
                  const SizedBox(width: 3),
                ],
                Text(
                  badge,
                  style: TextStyle(
                    color: isPro ? Colors.white : numPrimary,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        text,
        style: TextStyle(
          color: context.numColors.textMuted,
          fontSize: 13,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

/// Bağlantı grubu: ana sayfa kartlarıyla aynı kabuk (ince altın çerçeve),
/// satırlar arasında girintili ayraç.
class _MenuGroup extends StatelessWidget {
  final List<Widget> children;
  const _MenuGroup({required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final rows = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(Divider(height: 1, indent: 56, color: c.divider));
      }
      rows.add(children[i]);
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: c.card,
        shape: _cardShape,
        clipBehavior: Clip.antiAlias,
        child: Column(children: rows),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool emphasize;
  final IconData trailingIcon;

  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.emphasize = false,
    this.trailingIcon = Icons.chevron_right_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: numPrimary, size: 24),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: emphasize ? c.accent : c.text,
                      fontSize: 15.5,
                      fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: TextStyle(color: c.textMuted, fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(trailingIcon, color: c.hint, size: 22),
          ],
        ),
      ),
    );
  }
}

/// Unauthenticated User View
class _UnauthenticatedView extends ConsumerWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _UnauthenticatedView({
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.account_circle_outlined,
              size: 120,
              color: theme.colorScheme.primary.withOpacity(0.5),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.translate('not_signed_in'),
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('sign_in_to_unlock'),
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () {
                // Navigate to new hybrid login screen
                context.push('/login');
              },
              icon: const Icon(Icons.login_rounded),
              label: Text(l10n.translate('sign_in')),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hesap kartlarının ortak kabuğu: ana sayfa kartlarıyla aynı dil (gölge yok,
/// ince altın çerçeve). Eski gölgeli kartlar sayfayı ayrı bir uygulama gibi
/// gösteriyordu (2026-09-26 cihaz incelemesi).
final _cardShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.circular(14),
  side: BorderSide(color: numPrimary.withAlpha(70)),
);

/// Quota Card (Free Users Only)
class _QuotaCard extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final ScanQuota quota;

  const _QuotaCard({
    required this.l10n,
    required this.theme,
    required this.quota,
  });

  @override
  Widget build(BuildContext context) {
    // Protect against division by zero for Pro users (limit = -1)
    final progress = (quota.limit > 0) ? (quota.used / quota.limit) : 0.0;
    final remaining = quota.remaining;
    final c = context.numColors;
    final Color progressColor = remaining > 5
        ? Colors.green
        : remaining > 2
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 0,
      shape: _cardShape,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.camera_alt_rounded,
                  color: progressColor,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate('scan_quota'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.translate('scans_remaining', params: {
                          'remaining': remaining.toString(),
                          'limit': quota.limit.toString(),
                        }),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${quota.used}/${quota.limit} ${l10n.translate('used')}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (quota.resetDate != null)
                  Text(
                    l10n.translate('resets_on', params: {
                      'date': _formatDate(quota.resetDate!),
                    }),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            if (remaining <= 3) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark
                      ? c.surface
                      : Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: Colors.amber.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.amber.shade700,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.translate('quota_low_warning'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}

/// Usage Stats Card
class _UsageStatsCard extends ConsumerWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _UsageStatsCard({
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Favori sayısı (yerel) — controller state'i senkron bir Set<int>
    final favoritesCount = ref.watch(favoritesControllerProvider).length;
    // Koleksiyon sayısı (yerel)
    final collectionsCount = ref.watch(collectionsControllerProvider).maybeWhen(
          data: (list) => list.length,
          orElse: () => 0,
        );
    // Tarama sayısı — backend'de all-time sayaç yok; kotanın bu ayki kullanımı
    final scansUsed = ref.watch(scanQuotaProvider).maybeWhen(
          data: (q) => q.used,
          orElse: () => 0,
        );

    return Card(
      elevation: 0,
      shape: _cardShape,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.translate('usage_stats'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _StatRow(
              icon: Icons.history_rounded,
              label: l10n.translate('scans_this_month'),
              value: scansUsed.toString(),
              theme: theme,
            ),
            const SizedBox(height: 12),
            _StatRow(
              icon: Icons.favorite_rounded,
              label: l10n.translate('favorites'),
              value: favoritesCount.toString(),
              theme: theme,
            ),
            const SizedBox(height: 12),
            _StatRow(
              icon: Icons.collections_rounded,
              label: l10n.translate('collections'),
              value: collectionsCount.toString(),
              theme: theme,
            ),
          ],
        ),
      ),
    );
  }
}

/// Stat Row Widget
class _StatRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;

  const _StatRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          size: 20,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }
}

/// Loading Card
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: _cardShape,
      child: const Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}
