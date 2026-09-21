import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../numistr_colors.dart';
import '../../l10n/app_localizations.dart';
import 'num_menu_sheet.dart';

/// Alt çubuktaki hedefler. İlk dördü `ShellBranch` dallarıyla aynı sırada.
enum NavTab { home, browse, scan, favorites, menu }

/// Yalnız Menü sayfasından ulaşılan ekranlar. Bunlardan biri açıkken hangi
/// sekmenin üstüne açılmış olursa olsun "Menü" hedefi seçili görünür; kullanıcı
/// nerede olduğunu kaybetmesin (Profil ve Ayarlar 2026-09-20'de Menü'ye taşındı).
const _menuOnlyPaths = <String>[
  '/account',
  '/settings',
  '/assistant',
  '/login',
  '/register',
  '/subscription',
  '/university-application',
  '/terms-of-service',
  '/privacy-policy',
  '/kvkk',
  '/subscription-agreement',
];

/// Seçili sekme: Menü sayfasına ait bir ekran açıksa Menü, değilse içinde
/// bulunulan dal. `/variant/1` gibi paylaşılan detaylar hangi sekmeden
/// açıldıysa o sekme seçili kalır (push sayfayı o sekmenin üstüne koyar).
NavTab navTabFor(String path, int branchIndex) {
  final menuOnly = _menuOnlyPaths.any((p) => path == p || path.startsWith('$p/'));
  if (menuOnly || branchIndex >= NavTab.menu.index) return NavTab.menu;
  return NavTab.values[branchIndex];
}

/// Kabuk: tüm sekme ekranlarının ortak iskeleti; alt çubuk yalnız burada çizilir.
///
/// Klavye açıkken alt çubuk gizlenir ve dış Scaffold klavyeye göre küçülmez
/// (`resizeToAvoidBottomInset: false`). İç ekranların kendi Scaffold'ları
/// klavye boşluğunu zaten bırakır; dış da küçülseydi asistan ve arama
/// kutularında klavyenin üstünde çift boşluk oluşurdu.
class NumShellScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NumShellScaffold({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: navigationShell,
      bottomNavigationBar:
          keyboardOpen ? null : NumBottomNav(navigationShell: navigationShell),
    );
  }
}

/// Uygulamanın tek alt çubuğu (5 hedef). Yalnız [NumShellScaffold] kullanır;
/// ekranlar artık kendi `bottomNavigationBar`'ını KOYMAZ.
class NumBottomNav extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const NumBottomNav({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final router = GoRouter.of(context);

    // push'lanan sayfalar kabuğu yeniden kurmayabilir; konumu dinle.
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        final current = navTabFor(
          router.state.uri.path,
          navigationShell.currentIndex,
        );
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
                      isSelected: current == NavTab.home,
                      onTap: () => _goTab(NavTab.home, current),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.search,
                      selectedIcon: Icons.search,
                      label: l10n.translate('browse'),
                      isSelected: current == NavTab.browse,
                      onTap: () => _goTab(NavTab.browse, current),
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
                      isSelected: current == NavTab.scan,
                      isPrimary: true,
                      onTap: () => _goTab(NavTab.scan, current),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.favorite_border,
                      selectedIcon: Icons.favorite,
                      label: l10n.translate('favorites'),
                      isSelected: current == NavTab.favorites,
                      onTap: () => _goTab(NavTab.favorites, current),
                    ),
                  ),
                  Expanded(
                    child: _NavItem(
                      icon: Icons.menu,
                      selectedIcon: Icons.menu,
                      label: l10n.translate('menu'),
                      isSelected: current == NavTab.menu,
                      onTap: () => showNumMenuSheet(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Sekmeye geçiş sekmenin kaldığı yeri korur (kaydırma, filtre, açık detay).
  /// Zaten seçili sekmeye dokunmak o sekmenin köküne döner (platform alışkanlığı).
  /// Tara her zaman kameradan başlar: eski sonuç ekranına dönmek yanıltıcı olur,
  /// sonuçlar zaten Geçmiş'e kaydediliyor.
  void _goTab(NavTab tab, NavTab current) {
    navigationShell.goBranch(
      tab.index,
      initialLocation: tab == current || tab == NavTab.scan,
    );
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
