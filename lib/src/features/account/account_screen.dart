import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../auth/auth_controller.dart';
import '../../core/subscription_provider.dart';
import '../../l10n/app_localizations.dart';
import '../recognition/recognition_service.dart';
import '../favorites/favorites_service.dart';
import '../collections/collections_service.dart';

/// Account Screen - User profile and subscription management
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('account_title')),
        centerTitle: true,
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

    // Pro status can come from two independent sources: a RevenueCat purchase
    // OR Joomla user-group membership (admin-granted, university, comped),
    // reported by the /v1/user/scan-quota endpoint. Treat either as Pro.
    final joomlaIsPro = quotaAsync.maybeWhen(
      data: (quota) => quota.isPro,
      orElse: () => false,
    );

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(subscriptionProvider);
        ref.invalidate(scanQuotaProvider);
        ref.invalidate(favoritesControllerProvider);
        ref.invalidate(collectionsControllerProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Profile Card
            _ProfileCard(
              l10n: l10n,
              theme: theme,
              email: authState.email ?? '—',
            ),

            const SizedBox(height: 16),

            // Subscription Card
            _SubscriptionCard(
              l10n: l10n,
              theme: theme,
              subscription: subscription,
              joomlaIsPro: joomlaIsPro,
            ),

            const SizedBox(height: 16),

            // ADR-006 Faz 3: AI Numizmatik Asistanı girişi (ikinci ve son giriş noktası; A15)
            Card(
              elevation: 2,
              child: ListTile(
                leading: Icon(Icons.smart_toy_outlined, color: theme.colorScheme.primary),
                title: Text(l10n.translate('assistant_title')),
                subtitle: Text(l10n.translate('assistant_subtitle')),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/assistant'),
              ),
            ),

            const SizedBox(height: 16),

            // Quota Card (only for free users)
            // Note: If quota fetch fails (e.g., 401), show a simplified info instead
            quotaAsync.when(
              data: (quota) {
                // Only show quota card for free users
                if (quota.isPro) {
                  return const SizedBox.shrink();
                }
                return Column(
                  children: [
                    _QuotaCard(
                      l10n: l10n,
                      theme: theme,
                      quota: quota,
                    ),
                    const SizedBox(height: 16),
                  ],
                );
              },
              loading: () => const _LoadingCard(),
              error: (error, stack) {
                // Don't show error card for quota - it's not critical
                // Just show nothing and let user continue
                debugPrint('Quota fetch error (non-critical): $error');
                return const SizedBox.shrink();
              },
            ),

            // Usage Stats Card
            _UsageStatsCard(l10n: l10n, theme: theme),

            const SizedBox(height: 24),

            // Sign Out Button
            OutlinedButton.icon(
              onPressed: () async {
                final confirm = await _showSignOutDialog(context, l10n);
                if (confirm == true && context.mounted) {
                  // Çıkıştan sonra ana sayfaya GİTMİYORUZ: kullanıcı çıkışı bu
                  // ekrandan yaptı, giriş de buradan yapılıyor. Ekran authState'i
                  // izlediği için token temizlenince kendiliğinden
                  // _UnauthenticatedView'e döner; bulunduğu yerde kalmak bağlamı
                  // korur ve tekrar giriş tek dokunuş kalır.
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
    );
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

/// Profile Card
class _ProfileCard extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final String email;

  const _ProfileCard({
    required this.l10n,
    required this.theme,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.primaryContainer,
              child: Icon(
                Icons.person_rounded,
                size: 36,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('profile'),
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    email,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Subscription Card
class _SubscriptionCard extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final SubscriptionState subscription;
  final bool joomlaIsPro;

  const _SubscriptionCard({
    required this.l10n,
    required this.theme,
    required this.subscription,
    this.joomlaIsPro = false,
  });

  @override
  Widget build(BuildContext context) {
    // Pro if a RevenueCat entitlement is active OR the user is Pro via Joomla
    // group membership (admin-granted, university, comped) reported by the
    // scan-quota endpoint.
    final isPro =
        subscription.tier == SubscriptionTier.pro || joomlaIsPro;

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => context.push('/subscription'),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: isPro
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.amber.shade100,
                      Colors.orange.shade50,
                    ],
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    isPro ? Icons.star_rounded : Icons.account_circle_outlined,
                    color: isPro ? Colors.amber.shade700 : theme.colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate('subscription'),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPro
                              ? l10n.translate('pro_tier')
                              : l10n.translate('free_tier'),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isPro ? Colors.amber.shade900 : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              if (!isPro) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text(
                  l10n.translate('upgrade_benefits'),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                _BenefitItem(
                  icon: Icons.camera_alt_rounded,
                  text: l10n.translate('unlimited_scans'),
                  theme: theme,
                ),
                _BenefitItem(
                  icon: Icons.cloud_download_rounded,
                  text: l10n.translate('offline_access'),
                  theme: theme,
                ),
                _BenefitItem(
                  icon: Icons.high_quality_rounded,
                  text: l10n.translate('high_res_images'),
                  theme: theme,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

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
    final Color progressColor = remaining > 5
        ? Colors.green
        : remaining > 2
            ? Colors.orange
            : Colors.red;

    return Card(
      elevation: 2,
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
                  color: Colors.amber.shade50,
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
      elevation: 2,
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
              label: l10n.translate('total_scans'),
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

/// Benefit Item Widget
class _BenefitItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final ThemeData theme;

  const _BenefitItem({
    required this.icon,
    required this.text,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Loading Card
class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(40),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

/// Error Card
class _ErrorCard extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;
  final String error;

  const _ErrorCard({
    required this.l10n,
    required this.theme,
    required this.error,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              l10n.translate('error_loading_data'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
