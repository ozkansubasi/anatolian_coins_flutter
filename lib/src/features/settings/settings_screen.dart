import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../core/locale_provider.dart';
import '../../core/subscription_provider.dart';
import '../../core/region_data.dart';
import '../../widgets/custom_toggle_switch.dart';
import 'settings_provider.dart';

/// Settings screen for app configuration
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final currentLocale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('settings_title')),
        centerTitle: true,
      ),
      body: ListView(
        children: [
          // Language Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.translate('language'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildLanguageRadioButtons(context, ref, l10n),
          const Divider(),

          // Recognition Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.translate('recognition_settings'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildConfidenceThresholdTile(context, ref, l10n),
          _buildTopKTile(context, ref, l10n),
          _buildRegionFilterTile(context, ref, l10n),
          _buildMaterialFilterTile(context, ref, l10n),
          const Divider(),

          // About Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.translate('about'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.translate('about_numistr')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAboutDialog(context, l10n),
          ),
          ListTile(
            leading: const Icon(Icons.code),
            title: Text(l10n.translate('version')),
            subtitle: const Text('0.4.0'),
          ),
          const Divider(),

          // Appearance Section
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.translate('appearance'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildThemeModeTile(context, ref, l10n),
          const Divider(),

          // Offline Section (Pro Feature)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.translate('offline'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildAutoSyncTile(context, ref, l10n),
          const Divider(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.translate('notifications'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: Text(l10n.translate('notifications')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showComingSoon(context, l10n),
          ),
          const Divider(),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              l10n.translate('legal'),
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l10n.translate('terms_of_service')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/terms-of-service'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(l10n.translate('privacy_policy')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/privacy-policy'),
          ),
          ListTile(
            leading: const Icon(Icons.security_outlined),
            title: Text(l10n.translate('kvkk')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/kvkk'),
          ),
          ListTile(
            leading: const Icon(Icons.workspace_premium_outlined),
            title: Text(l10n.translate('subscription_agreement')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/subscription-agreement'),
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageRadioButtons(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final currentLocale = ref.watch(localeProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          RadioListTile<String>(
            title: Row(
              children: [
                const Text('🇹🇷', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Text(l10n.translate('language_turkish')),
              ],
            ),
            value: 'tr',
            groupValue: currentLocale.languageCode,
            onChanged: (value) {
              if (value != null) {
                ref.read(localeProvider.notifier).setLocale(Locale(value, ''));
              }
            },
          ),
          RadioListTile<String>(
            title: Row(
              children: [
                const Text('🇬🇧', style: TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Text(l10n.translate('language_english')),
              ],
            ),
            value: 'en',
            groupValue: currentLocale.languageCode,
            onChanged: (value) {
              if (value != null) {
                ref.read(localeProvider.notifier).setLocale(Locale(value, ''));
              }
            },
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('about_numistr')),
        content: Text(l10n.translate('about_numistr_text')),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.translate('ok')),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, AppLocalizations l10n) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.translate('coming_soon')),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildAutoSyncTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final subscription = ref.watch(subscriptionProvider);
    final autoSync = ref.watch(autoSyncFavoritesProvider);
    final isEnabled = subscription.isPro;
    final value = isEnabled && autoSync;

    return ListTile(
      leading: const Icon(Icons.cloud_download_outlined),
      title: Text(l10n.translate('auto_download_favorites')),
      subtitle: Text(
        subscription.isPro
            ? l10n.translate('auto_download_favorites_subtitle_pro')
            : l10n.translate('auto_download_favorites_subtitle_free'),
      ),
      trailing: CustomToggleSwitch(
        value: value,
        onChanged: isEnabled
            ? (newValue) async {
                await ref.read(autoSyncFavoritesProvider.notifier).toggle();
              }
            : (_) {}, // Disabled, do nothing
        width: 56,
        height: 28,
        activeColor: isEnabled ? Colors.green : Colors.grey,
      ),
    );
  }

  Widget _buildConfidenceThresholdTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final threshold = ref.watch(recognitionConfidenceThresholdProvider);

    return ListTile(
      leading: const Icon(Icons.tune),
      title: Text(l10n.translate('confidence_threshold')),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('minimum_similarity', params: {'value': '${(threshold * 100).toInt()}'})),
          Slider(
            value: threshold,
            min: 0.4,
            max: 0.95,
            divisions: 11,
            label: '%${(threshold * 100).toInt()}',
            onChanged: (value) {
              ref.read(recognitionConfidenceThresholdProvider.notifier).set(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTopKTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final topK = ref.watch(recognitionTopKProvider);

    return ListTile(
      leading: const Icon(Icons.format_list_numbered),
      title: Text(l10n.translate('result_count')),
      subtitle: Text(l10n.translate('showing_top_n_results', params: {'count': '$topK'})),
      trailing: DropdownButton<int>(
        value: topK,
        items: const [
          DropdownMenuItem(value: 3, child: Text('3')),
          DropdownMenuItem(value: 5, child: Text('5')),
          DropdownMenuItem(value: 10, child: Text('10')),
        ],
        onChanged: (value) {
          if (value != null) {
            ref.read(recognitionTopKProvider.notifier).set(value);
          }
        },
      ),
    );
  }

  Widget _buildRegionFilterTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final filterRegion = ref.watch(recognitionFilterRegionProvider);

    return ListTile(
      leading: const Icon(Icons.map_outlined),
      title: Text(l10n.translate('region_filter')),
      subtitle: Text(
        filterRegion == null
            ? l10n.translate('all_regions')
            : RegionData.getRegionName(filterRegion) ?? filterRegion,
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showRegionFilterDialog(context, ref, l10n, filterRegion),
    );
  }

  Widget _buildMaterialFilterTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final filterMaterial = ref.watch(recognitionFilterMaterialProvider);

    // Get material name from translations
    String getMaterialName(String? material) {
      if (material == null) return l10n.translate('all_materials');
      final key = 'material_${material.toLowerCase()}';
      return l10n.translate(key);
    }

    return ListTile(
      leading: const Icon(Icons.category_outlined),
      title: Text(l10n.translate('material_filter')),
      subtitle: Text(getMaterialName(filterMaterial)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showMaterialFilterDialog(context, ref, l10n, filterMaterial),
    );
  }

  void _showRegionFilterDialog(BuildContext context, WidgetRef ref, AppLocalizations l10n, String? currentValue) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('region_filter')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              RadioListTile<String?>(
                title: Text(l10n.translate('all_regions')),
                value: null,
                groupValue: currentValue,
                onChanged: (value) {
                  ref.read(recognitionFilterRegionProvider.notifier).clear();
                  Navigator.of(context).pop();
                },
              ),
              ...RegionData.getAllRegions().map(
                (region) => RadioListTile<String>(
                  title: Text(region.value),
                  value: region.key,
                  groupValue: currentValue,
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(recognitionFilterRegionProvider.notifier).set(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.translate('close')),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeTile(BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final themeMode = ref.watch(themeModeProvider);
    final theme = Theme.of(context);

    String getThemeModeLabel(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.light:
          return l10n.translate('theme_light');
        case ThemeMode.dark:
          return l10n.translate('theme_dark');
        case ThemeMode.system:
          return l10n.translate('theme_system');
      }
    }

    IconData getThemeModeIcon(ThemeMode mode) {
      switch (mode) {
        case ThemeMode.light:
          return Icons.light_mode;
        case ThemeMode.dark:
          return Icons.dark_mode;
        case ThemeMode.system:
          return Icons.brightness_auto;
      }
    }

    return ListTile(
      leading: Icon(getThemeModeIcon(themeMode)),
      title: Text(l10n.translate('theme')),
      subtitle: Text(getThemeModeLabel(themeMode)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _showThemeModeDialog(context, ref, l10n, themeMode),
    );
  }

  void _showThemeModeDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    ThemeMode currentValue,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('theme')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  const Icon(Icons.brightness_auto, size: 24),
                  const SizedBox(width: 12),
                  Flexible(child: Text(l10n.translate('theme_system'))),
                ],
              ),
              subtitle: Text(l10n.translate('theme_system_description')),
              value: ThemeMode.system,
              groupValue: currentValue,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).set(value);
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  const Icon(Icons.light_mode, size: 24),
                  const SizedBox(width: 12),
                  Flexible(child: Text(l10n.translate('theme_light'))),
                ],
              ),
              value: ThemeMode.light,
              groupValue: currentValue,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).set(value);
                  Navigator.of(context).pop();
                }
              },
            ),
            RadioListTile<ThemeMode>(
              title: Row(
                children: [
                  const Icon(Icons.dark_mode, size: 24),
                  const SizedBox(width: 12),
                  Flexible(child: Text(l10n.translate('theme_dark'))),
                ],
              ),
              value: ThemeMode.dark,
              groupValue: currentValue,
              onChanged: (value) {
                if (value != null) {
                  ref.read(themeModeProvider.notifier).set(value);
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.translate('close')),
          ),
        ],
      ),
    );
  }

  void _showMaterialFilterDialog(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String? currentValue,
  ) {
    // Material keys for translation
    const materialKeys = [
      'bronze',
      'gold',
      'silver',
      'copper',
      'electrum',
      'brass',
      'iron',
      'lead',
      'potin',
    ];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('material_filter')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              RadioListTile<String?>(
                title: Text(l10n.translate('all_materials')),
                value: null,
                groupValue: currentValue,
                onChanged: (value) {
                  ref.read(recognitionFilterMaterialProvider.notifier).clear();
                  Navigator.of(context).pop();
                },
              ),
              ...materialKeys.map(
                (materialKey) => RadioListTile<String>(
                  title: Text(l10n.translate('material_$materialKey')),
                  value: materialKey,
                  groupValue: currentValue?.toLowerCase(),
                  onChanged: (value) {
                    if (value != null) {
                      ref.read(recognitionFilterMaterialProvider.notifier).set(value);
                      Navigator.of(context).pop();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.translate('close')),
          ),
        ],
      ),
    );
  }
}
