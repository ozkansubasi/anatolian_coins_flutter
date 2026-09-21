import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/variant.dart';
import '../../core/num_colors.dart';
import '../../core/num_text.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/coin_list.dart';
import '../variants/variants_api.dart';
import '../offline/offline_service.dart'; // offlineDatabaseProvider burada tanımlı
import 'scan_history_service.dart';

/// Geçmiş sayfası — iki sekme:
/// 1) Taramalar: AI tanıma sonuçları (scan_history)
/// 2) Görüntülenenler: detayına bakılan sikkeler (view_history)
///
/// 2026-09-21: ortak CoinRow dili, l10n (metinlerin çoğu sabit Türkçeydi),
/// yerele göre tarih, paralel yükleme, tek satır silme de onaylı (eskiden
/// satır silme onaysız, "tümünü temizle" onaylıydı).
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  bool _scansLoading = true;
  List<ScanRecord> _scans = [];

  bool _viewsLoading = true;
  List<Variant> _viewHistory = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    // İlk kareden sonra: yükleyiciler hata mesajında AppLocalizations kullanıyor.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadScans();
      _loadViewHistory();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _snack(String key) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(AppLocalizations.of(context).translate(key))));
  }

  // ---------- Veri ----------

  Future<void> _loadScans() async {
    setState(() => _scansLoading = true);
    try {
      final scans = await ref.read(scanHistoryServiceProvider).getScans();
      if (mounted) {
        setState(() {
          _scans = scans;
          _scansLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Scan history load error: $e');
      if (mounted) {
        setState(() => _scansLoading = false);
        _snack('error_generic');
      }
    }
  }

  Future<void> _deleteScan(ScanRecord record) async {
    final l10n = AppLocalizations.of(context);
    final ok = await confirmDestructive(
      context,
      title: l10n.translate('delete'),
      message: l10n.translate('delete_scan_confirm'),
      confirmLabel: l10n.translate('delete'),
    );
    if (!ok) return;
    await ref.read(scanHistoryServiceProvider).deleteScan(record);
    await _loadScans();
  }

  Future<void> _loadViewHistory() async {
    setState(() => _viewsLoading = true);
    try {
      final ids = await ref.read(offlineDatabaseProvider).getRecentlyViewed(limit: 50);
      final variants = await loadVariantsInOrder(ref.read(variantsApiProvider), ids);
      if (mounted) {
        setState(() {
          _viewHistory = variants;
          _viewsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('View history load error: $e');
      if (mounted) {
        setState(() => _viewsLoading = false);
        _snack('error_generic');
      }
    }
  }

  Future<void> _clearActiveTab() async {
    final l10n = AppLocalizations.of(context);
    final isScansTab = _tabController.index == 0;
    final ok = await confirmDestructive(
      context,
      title: l10n.translate('clear_history'),
      message: l10n.translate(isScansTab ? 'clear_scans_confirm' : 'clear_views_confirm'),
      confirmLabel: l10n.translate('clear'),
    );
    if (!ok) return;

    try {
      if (isScansTab) {
        await ref.read(scanHistoryServiceProvider).clearAll();
        await _loadScans();
      } else {
        await ref.read(offlineDatabaseProvider).cleanOldViewHistory(keepRecent: 0);
        await _loadViewHistory();
      }
      if (mounted) _snack('history_cleared');
    } catch (e) {
      debugPrint('Clear history error: $e');
      if (mounted) _snack('error_generic');
    }
  }

  bool get _activeTabHasItems =>
      _tabController.index == 0 ? _scans.isNotEmpty : _viewHistory.isNotEmpty;

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.translate('history_title')),
        actions: [
          if (_activeTabHasItems)
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: l10n.translate('clear_history'),
              onPressed: _clearActiveTab,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: c.accent,
          unselectedLabelColor: c.textMuted,
          indicatorColor: c.accent,
          labelStyle: context.numText.tab.copyWith(fontSize: 14),
          tabs: [
            Tab(text: l10n.translate('scans_tab')),
            Tab(text: l10n.translate('views_tab')),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScansTab(l10n),
          _buildViewsTab(l10n),
        ],
      ),
    );
  }

  Widget _loader() => Center(child: CircularProgressIndicator(color: context.numColors.accent));

  Widget _buildScansTab(AppLocalizations l10n) {
    if (_scansLoading) return _loader();
    if (_scans.isEmpty) {
      return EmptyStateView(
        icon: Icons.photo_camera_outlined,
        title: l10n.translate('no_scan_history'),
        message: l10n.translate('no_scan_history_hint'),
        actionLabel: l10n.translate('coin_recognition'),
        actionIcon: Icons.photo_camera_outlined,
        onAction: () => context.go('/recognition'),
      );
    }

    final c = context.numColors;
    // Yerele göre tarih (eskiden sabit dd.MM.yyyy HH:mm).
    final dateFormat = DateFormat.yMMMd(l10n.locale.languageCode).add_Hm();

    return RefreshIndicator(
      color: c.accent,
      onRefresh: _loadScans,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          CoinRowCard(
            children: [
              for (var i = 0; i < _scans.length; i++)
                _scanRow(_scans[i], l10n, dateFormat, last: i == _scans.length - 1),
            ],
          ),
        ],
      ),
    );
  }

  Widget _scanRow(ScanRecord scan, AppLocalizations l10n, DateFormat dateFormat, {required bool last}) {
    final c = context.numColors;
    final hasMatch = scan.topArticleId != null && scan.topArticleId != 0;
    final confidence = scan.topConfidence;
    return CoinRow(
      leading: CoinPhotoThumb(path: scan.imagePath),
      title: hasMatch ? (scan.topTitle ?? '-') : l10n.translate('no_match_found'),
      // Eşleşmesi olmayan satır tıklanamaz: soluk başlıkla belli edilir.
      dim: !hasMatch,
      meta: [
        if (confidence != null && hasMatch)
          l10n.translate('similarity_pct', params: {'n': '${(confidence * 100).round()}'}),
        dateFormat.format(scan.scannedAt),
      ].join(' · '),
      last: last,
      onTap: hasMatch ? () => context.push('/variant/${scan.topArticleId}') : null,
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: c.hint, size: 22),
        tooltip: l10n.translate('delete'),
        onPressed: () => _deleteScan(scan),
      ),
    );
  }

  Widget _buildViewsTab(AppLocalizations l10n) {
    if (_viewsLoading) return _loader();
    if (_viewHistory.isEmpty) {
      return EmptyStateView(
        icon: Icons.visibility_outlined,
        title: l10n.translate('no_view_history'),
        message: l10n.translate('no_view_history_hint'),
        actionLabel: l10n.translate('browse_coins'),
        actionIcon: Icons.search,
        onAction: () => context.go('/browse'),
      );
    }
    final c = context.numColors;

    return RefreshIndicator(
      color: c.accent,
      onRefresh: _loadViewHistory,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          CoinRowCard(
            children: [
              for (var i = 0; i < _viewHistory.length; i++)
                CoinRow(
                  leading: CoinThumb(articleId: _viewHistory[i].articleId),
                  title: _viewHistory[i].title,
                  meta: coinMetaLine(_viewHistory[i], l10n),
                  last: i == _viewHistory.length - 1,
                  trailing: Icon(Icons.chevron_right, color: c.hint),
                  onTap: () => context.push('/variant/${_viewHistory[i].articleId}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
