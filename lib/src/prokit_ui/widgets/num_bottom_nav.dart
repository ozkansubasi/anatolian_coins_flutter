import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../numistr_colors.dart';
import '../../l10n/app_localizations.dart';
import 'num_menu_sheet.dart';

/// Navigation tab enumeration for consistent navigation across the app
enum NavTab {
  home,
  browse,
  scan,
  favorites,
  menu,
  // profile ve settings ARTIK alt cubukta hedef degil (2026-09-20, 7 -> 5).
  // Enum degerleri korunuyor cunku ekranlar bunlari geciriyor; ikisi de "Menu"
  // hedefini secili gosterir.
  profile,
  settings,
}

/// Shared Bottom Navigation Bar for all screens
/// Provides consistent navigation across the entire app
class NumBottomNav extends StatelessWidget {
  final NavTab currentTab;

  const NumBottomNav({
    super.key,
    required this.currentTab,
  });

  /// Creates a bottom nav bar with the current route pre-selected
  factory NumBottomNav.fromRoute(String currentRoute) {
    NavTab tab = NavTab.home;

    if (currentRoute == '/' || currentRoute.isEmpty) {
      tab = NavTab.home;
    } else if (currentRoute.startsWith('/browse') || currentRoute.startsWith('/variant')) {
      tab = NavTab.browse;
    } else if (currentRoute.startsWith('/recognition')) {
      tab = NavTab.scan;
    } else if (currentRoute.startsWith('/favorites')) {
      tab = NavTab.favorites;
    } else if (currentRoute.startsWith('/account') || currentRoute.startsWith('/login')) {
      tab = NavTab.profile;
    } else if (currentRoute.startsWith('/settings')) {
      tab = NavTab.settings;
    }

    return NumBottomNav(currentTab: tab);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Profil ve Ayarlar artik Menu sayfasinda; o ekranlardayken "Menu" hedefi
    // secili gosterilir ki kullanici nerede oldugunu kaybetmesin.
    final menuSelected = currentTab == NavTab.menu ||
        currentTab == NavTab.profile ||
        currentTab == NavTab.settings;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? numCardDark : numCardLight,
        boxShadow: [
          BoxShadow(
            color: numShadow,
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          // DIKKAT: burada SingleChildScrollView KULLANILMAZ.
          // 2026-09-20 oncesinde Row yatay bir SingleChildScrollView icindeydi:
          // (1) sinirsiz genislikte `spaceAround` hicbir sey yapmiyordu, ogeler
          // bitisiyordu; (2) scroll gesture arena'da `onTap`'i yutuyordu, parmak
          // 1-2 px kayinca dokunma dusuyordu ("bazen tepki vermiyor").
          // Expanded ile her hedef esit pay alir ve 48dp'nin altina inmez.
          child: Row(
            children: [
              Expanded(
                child: _NavItem(
                  icon: Icons.home_outlined,
                  selectedIcon: Icons.home,
                  label: l10n.translate('home'),
                  isSelected: currentTab == NavTab.home,
                  onTap: () => _navigateTo(context, '/'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.search,
                  selectedIcon: Icons.search,
                  label: l10n.translate('browse'),
                  isSelected: currentTab == NavTab.browse,
                  onTap: () => _navigateTo(context, '/browse'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  // QR ikonu DEGIL: QR/barkod ikonu sektorde gercek kod okuma
                  // icin ayrilmis (PCGS slab barkodu, muze levha QR'i). Burada
                  // goruntu tanima yapiliyor -> kamera dogru metafor.
                  icon: Icons.photo_camera_outlined,
                  selectedIcon: Icons.photo_camera,
                  label: l10n.translate('scan'),
                  isSelected: currentTab == NavTab.scan,
                  isPrimary: true,
                  onTap: () => _navigateTo(context, '/recognition'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.favorite_border,
                  selectedIcon: Icons.favorite,
                  label: l10n.translate('favorites'),
                  isSelected: currentTab == NavTab.favorites,
                  onTap: () => _navigateTo(context, '/favorites'),
                ),
              ),
              Expanded(
                child: _NavItem(
                  icon: Icons.menu,
                  selectedIcon: Icons.menu,
                  label: l10n.translate('menu'),
                  isSelected: menuSelected,
                  onTap: () => showNumMenuSheet(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateTo(BuildContext context, String path) {
    final currentPath = GoRouterState.of(context).uri.toString();
    if (currentPath != path) {
      context.go(path);
    }
  }
}

/// Tek navigasyon hedefi.
///
/// Dokunma hedefi kurallari (Material 48dp / Apple 44pt):
/// - `Expanded` ile genislik esit paylasilir, en dar telefonda bile >=64dp olur
/// - `minHeight: 56` ile yukseklik garanti
/// - `InkWell` ripple verir; oncesinde `GestureDetector` kullanildigi icin
///   dokunma hic geri bildirim uretmiyordu ("tepki vermedi" hissi)
/// - Secili durum yalniz renkle degil, DOLU ikon + etiket agirligiyla da
///   gosterilir (renk tek basina erisilebilir degil)
class _NavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected ? numPrimary : numTextSecondary;

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isPrimary)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: numPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: numPrimary.withAlpha(100),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      isSelected ? selectedIcon : icon,
                      color: Colors.white,
                      size: 22,
                    ),
                  )
                else
                  Icon(isSelected ? selectedIcon : icon, color: color, size: 24),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight:
                        isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isPrimary && !isSelected ? numTextSecondary : color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
