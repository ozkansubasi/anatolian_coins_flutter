import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../numistr_colors.dart';
import '../../l10n/app_localizations.dart';
import 'num_bottom_nav.dart';

/// Uygulamanin "Menu" sayfasi (alt sayfa olarak acilir).
///
/// NEDEN BURADA: 2026-09-20 oncesinde bu sheet `prokit_home_screen.dart` icinde
/// private widget olarak duruyordu ve yalniz iki madde iceriyordu (Bolgeler,
/// Darphaneler). Alt cubuk 7 hedefden 5'e indirilirken Profil, Ayarlar ve AI
/// Asistan buraya tasindi; sheet paylasilir olmasi icin disari cikarildi.
///
/// Alt cubuk kurali: 3-5 hedef (Material 3) / en fazla 5 (Apple HIG). Sik
/// kullanilmayan her sey bu sayfada toplanir.
void showNumMenuSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) => const NumMenuSheet(),
  );
}

class NumMenuSheet extends StatelessWidget {
  const NumMenuSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? numCardDark : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tutma cubugu
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('menu'),
                      style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),

                    // --- Kesif ---
                    _MenuTile(
                      icon: Icons.public,
                      title: l10n.translate('regions'),
                      subtitle: l10n.translate('explore_by_region'),
                      route: '/regions',
                    ),
                    _MenuTile(
                      icon: Icons.location_city,
                      title: l10n.translate('mints'),
                      subtitle: l10n.translate('explore_by_mint'),
                      route: '/mints',
                    ),
                    _MenuTile(
                      icon: Icons.menu_book_outlined,
                      title: l10n.translate('blog'),
                      route: '/blog',
                    ),

                    const _MenuDivider(),

                    // --- Kisisel ---
                    _MenuTile(
                      icon: Icons.collections_bookmark_outlined,
                      title: l10n.translate('my_collections'),
                      route: '/collections',
                    ),
                    _MenuTile(
                      icon: Icons.history,
                      title: l10n.translate('scan_history'),
                      route: '/history',
                    ),

                    const _MenuDivider(),

                    // --- Asistan ---
                    // 2026-09-20: asistanin tek gorunur girisi sikke detayindaki
                    // ETIKETSIZ robot ikonuydu; kullanici bulamadi. Artik burada
                    // acik etiketle duruyor.
                    _MenuTile(
                      icon: Icons.chat_bubble_outline,
                      title: l10n.translate('assistant_title'),
                      route: '/assistant',
                    ),

                    const _MenuDivider(),

                    // --- Hesap ---
                    _MenuTile(
                      icon: Icons.person_outline,
                      title: l10n.translate('profile'),
                      route: '/account',
                    ),
                    _MenuTile(
                      icon: Icons.workspace_premium_outlined,
                      title: l10n.translate('subscription'),
                      route: '/subscription',
                    ),
                    _MenuTile(
                      icon: Icons.settings_outlined,
                      title: l10n.translate('settings'),
                      route: '/settings',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MenuDivider extends StatelessWidget {
  const _MenuDivider();

  @override
  Widget build(BuildContext context) =>
      const Divider(height: 24, indent: 8, endIndent: 8);
}

/// Tek menu maddesi. `ListTile` kullaniliyor cunku dokunma hedefini kendisi
/// >=48dp tutuyor ve ripple geri bildirimi veriyor.
class _MenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String route;

  const _MenuTile({
    required this.icon,
    required this.title,
    required this.route,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      minVerticalPadding: 12,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          // Tek vurgu rengi: her maddeye ayri pastel renk vermek (eski hizli
          // erisim deseni) altin-fildisi paletle cakisiyordu.
          color: numPrimary.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: numPrimary, size: 20),
      ),
      title: Text(title, style: theme.textTheme.titleSmall),
      subtitle: subtitle == null
          ? null
          : Text(subtitle!, style: theme.textTheme.bodySmall),
      trailing: Icon(
        Icons.chevron_right,
        color: theme.colorScheme.outline,
      ),
      onTap: () {
        Navigator.pop(context);
        context.openRoute(route);
      },
    );
  }
}
