import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../numistr_colors.dart';
import '../../l10n/app_localizations.dart';
import 'num_menu_sheet.dart';

/// Alt çubuktaki hedefler. İlk dördü `ShellBranch` dallarıyla aynı sırada.
enum NavTab { home, browse, scan, favorites, menu }

/// Her ekranın "evi": o ekran açıkken alt çubukta seçili görünen sekme.
/// app_router.dart'taki dal yerleşimiyle aynıdır. Ekranlar çoğu zaman `push`
/// ile bulunulan sekmenin ÜSTÜNE açılır; seçimi bulunulan dal belirleseydi
/// Menü'den açılan Bölgeler'de "Favoriler" seçili görünürdü (cihazda görüldü).
const _homeOf = <String, NavTab>{
  '/browse': NavTab.browse,
  '/recognition': NavTab.scan,
  '/favorites': NavTab.favorites,
  '/collections': NavTab.favorites,
  '/collection': NavTab.favorites,
  '/history': NavTab.favorites,
  '/account': NavTab.menu,
  '/settings': NavTab.menu,
  '/assistant': NavTab.menu,
  '/regions': NavTab.menu,
  '/mints': NavTab.menu,
  '/blog': NavTab.menu,
  '/article': NavTab.menu,
  '/login': NavTab.menu,
  '/register': NavTab.menu,
  '/subscription': NavTab.menu,
  '/university-application': NavTab.menu,
  '/terms-of-service': NavTab.menu,
  '/privacy-policy': NavTab.menu,
  '/kvkk': NavTab.menu,
  '/subscription-agreement': NavTab.menu,
};

/// Seçili sekme: ekranın evi. Tek istisna sikke detayı (`/variant/…`): her
/// sekmeden açılabildiği için açıldığı sekmede kalır.
NavTab navTabFor(String path, int branchIndex) {
  final first = path.split('/').where((s) => s.isNotEmpty).firstOrNull;
  if (first == null) return NavTab.home;
  final home = _homeOf['/$first'];
  if (home != null) return home;
  if (branchIndex >= NavTab.menu.index) return NavTab.menu;
  return NavTab.values[branchIndex];
}

extension NumOpenRoute on BuildContext {
  /// Bir ekranı açmanın tek doğru yolu (sekme dışı ekranlar için).
  ///
  /// Ekranın evi (bkz. [navTabFor]) bulunulan sekmeyse `push` — üstüne biner,
  /// geri tuşu buraya döner. Başka bir sekmeyse `go` — kendi dalında açılır.
  /// NEDEN (cihazda görüldü): Menü'den açılan Blog/makale Ana Sayfa dalının
  /// üstüne yerleşiyordu; sekmeler durum koruduğu için sonradan "Ana Sayfa"ya
  /// basınca makaleye düşülüyordu. Sikke detayı her sekmeye aittir → hep push.
  ///
  /// Etkin dal kabuktan okunur ([NumShellScaffold.activeBranch]); Menü alt
  /// sayfası kök navigatörde açıldığı için `StatefulNavigationShell.maybeOf`
  /// oradan kabuğu göremez.
  void openRoute(String location) {
    final active = NumShellScaffold.activeBranch;
    final home = navTabFor(Uri.parse(location).path, active);
    if (home.index == active) {
      push(location);
    } else {
      // Başka sekmede kök olarak açılır; geri oku için geldiği yer taşınır
      // (bkz. NumNavigation.returnLeading).
      final here = GoRouter.of(this).routerDelegate.currentConfiguration.uri;
      final hereQuery = Map<String, String>.of(here.queryParameters)..remove('from');
      final from = hereQuery.isEmpty ? here.path : '${here.path}?${Uri(queryParameters: hereQuery).query}';
      final target = Uri.parse(location);
      go(Uri(
        path: target.path,
        queryParameters: {...target.queryParameters, 'from': from},
      ).toString());
    }
  }
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

  /// Şu an gösterilen dal. Kabuk her dal değişiminde yeniden kurulur.
  static int activeBranch = 0;

  @override
  Widget build(BuildContext context) {
    activeBranch = navigationShell.currentIndex;
    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    // Sistem geri tuşu: sekmenin içinde geri gidilecek sayfa varsa go_router
    // önce onu kapatır (bu PopScope'a hiç gelmez). Ana Sayfa dışındaki bir
    // sekmenin kökünde uygulamadan ÇIKMAZ, Ana Sayfa'ya döner; çıkış yalnız
    // Ana Sayfa'dan. (Cihazda görüldü: Tara'da geri tuşu uygulamayı kapatıyordu.)
    return PopScope(
      canPop: navigationShell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) navigationShell.goBranch(0);
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        body: navigationShell,
        bottomNavigationBar:
            keyboardOpen ? null : NumBottomNav(navigationShell: navigationShell),
      ),
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
      // Bulunulan dala tekrar basmak her zaman o dalın köküne döner.
      initialLocation: tab.index == navigationShell.currentIndex || tab == NavTab.scan,
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
