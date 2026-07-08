import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;
import '../numistr_colors.dart';
import '../../l10n/app_localizations.dart';

/// Navigation tab enumeration for consistent navigation across the app
enum NavTab {
  home,
  browse,
  scan,
  favorites,
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _NavItem(
                  icon: Icons.home,
                  label: l10n.translate('home'),
                  isSelected: currentTab == NavTab.home,
                  onTap: () => _navigateTo(context, '/'),
                ),
                _NavItem(
                  icon: Icons.search,
                  label: l10n.translate('browse'),
                  isSelected: currentTab == NavTab.browse,
                  onTap: () => _navigateTo(context, '/browse'),
                ),
                _NavItem(
                  icon: Icons.qr_code_scanner,
                  label: l10n.translate('scan'),
                  isSelected: currentTab == NavTab.scan,
                  isPrimary: true,
                  onTap: () => _navigateTo(context, '/recognition'),
                ),
                _NavItem(
                  icon: Icons.favorite,
                  label: l10n.translate('favorites'),
                  isSelected: currentTab == NavTab.favorites,
                  onTap: () => _navigateTo(context, '/favorites'),
                ),
                _NavItem(
                  icon: Icons.person,
                  label: l10n.translate('profile'),
                  isSelected: currentTab == NavTab.profile,
                  onTap: () => _navigateTo(context, '/account'),
                ),
                _NavItem(
                  icon: Icons.settings,
                  label: l10n.translate('settings'),
                  isSelected: currentTab == NavTab.settings,
                  onTap: () => _navigateTo(context, '/settings'),
                ),
              ],
            ),
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

/// Individual navigation item widget
class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.isPrimary = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isPrimary) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
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
          child: Icon(icon, color: Colors.white, size: 24),
        ),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: numPrimary.withAlpha(20),
                borderRadius: BorderRadius.circular(12),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? numPrimary : numTextSecondary,
              size: 22,
            ),
            4.height,
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? numPrimary : numTextSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
