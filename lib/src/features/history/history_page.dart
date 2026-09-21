import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../models/variant.dart';
import '../../core/region_data.dart';
import '../../l10n/app_localizations.dart';
import '../variants/variants_api.dart';
import '../offline/offline_service.dart'; // offlineDatabaseProvider burada tanımlı
import 'scan_history_service.dart';

/// Geçmiş sayfası — iki sekme:
/// 1) Taramalar: AI tanıma sonuçları (scan_history)
/// 2) Görüntülenenler: detayına bakılan sikkeler (view_history)
class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  // Taramalar sekmesi
  bool _scansLoading = true;
  List<ScanRecord> _scans = [];

  // Görüntülenenler sekmesi
  bool _viewsLoading = true;
  List<Variant> _viewHistory = [];
  final Map<int, String?> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) setState(() {});
    });
    _loadScans();
    _loadViewHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ---------- Taramalar ----------

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
      if (mounted) {
        setState(() => _scansLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tarama geçmişi yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _deleteScan(ScanRecord record) async {
    await ref.read(scanHistoryServiceProvider).deleteScan(record);
    await _loadScans();
  }

  // ---------- Görüntülenenler ----------

  Future<void> _loadViewHistory() async {
    setState(() => _viewsLoading = true);

    try {
      final db = ref.read(offlineDatabaseProvider);
      final api = ref.read(variantsApiProvider);

      // Get recently viewed IDs (last 50)
      final variantIds = await db.getRecentlyViewed(limit: 50);

      // Fetch variant details
      final variants = <Variant>[];
      for (final id in variantIds) {
        try {
          final variant = await api.getVariant(id);
          variants.add(variant);
        } catch (e) {
          debugPrint('Failed to load variant $id: $e');
        }
      }

      if (mounted) {
        setState(() {
          _viewHistory = variants;
          _viewsLoading = false;
        });

        // Load thumbnails
        _loadThumbnails(variants);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _viewsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Geçmiş yüklenemedi: $e')),
        );
      }
    }
  }

  Future<void> _loadThumbnails(List<Variant> variants) async {
    final api = ref.read(variantsApiProvider);

    for (final variant in variants) {
      if (_thumbnailCache.containsKey(variant.articleId)) continue;

      try {
        final url = await api.getFirstImageUrl(variant.articleId, wm: true);
        if (mounted) {
          setState(() {
            _thumbnailCache[variant.articleId] = url;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _thumbnailCache[variant.articleId] = null;
          });
        }
      }
    }
  }

  // ---------- Temizleme (aktif sekmeye göre) ----------

  Future<void> _clearActiveTab() async {
    final isScansTab = _tabController.index == 0;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Geçmişi Temizle'),
        content: Text(isScansTab
            ? 'Tüm tarama geçmişi ve kayıtlı görselleri silinecek. Devam edilsin mi?'
            : 'Tüm görüntüleme geçmişi silinecek. Devam edilsin mi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Temizle'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      if (isScansTab) {
        await ref.read(scanHistoryServiceProvider).clearAll();
        await _loadScans();
      } else {
        final db = ref.read(offlineDatabaseProvider);
        await db.cleanOldViewHistory(keepRecent: 0);
        await _loadViewHistory();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçmiş temizlendi')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  bool get _activeTabHasItems => _tabController.index == 0
      ? _scans.isNotEmpty
      : _viewHistory.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.history, size: 20),
            const SizedBox(width: 8),
            Text(l10n.translate('history_title')),
          ],
        ),
        actions: [
          if (_activeTabHasItems)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Geçmişi Temizle',
              onPressed: _clearActiveTab,
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.camera_alt_outlined, size: 18),
              text: l10n.translate('scans_tab'),
            ),
            Tab(
              icon: const Icon(Icons.visibility_outlined, size: 18),
              text: l10n.translate('views_tab'),
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildScansTab(l10n, theme),
          _buildViewsTab(l10n, theme),
        ],
      ),
    );
  }

  // ---------- Taramalar sekmesi UI ----------

  Widget _buildScansTab(AppLocalizations l10n, ThemeData theme) {
    if (_scansLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_scans.isEmpty) {
      return _buildEmptyState(
        icon: Icons.camera_alt_outlined,
        title: l10n.translate('no_scan_history'),
        subtitle: l10n.translate('no_scan_history_hint'),
        buttonLabel: l10n.translate('coin_recognition'),
        buttonIcon: Icons.camera_alt,
        onPressed: () => context.go('/recognition'),
      );
    }

    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');

    return RefreshIndicator(
      onRefresh: _loadScans,
      child: ListView.separated(
        itemCount: _scans.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final scan = _scans[index];
          final hasMatch = scan.topArticleId != null && scan.topArticleId != 0;
          final confidence = scan.topConfidence;

          return ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            leading: SizedBox(
              width: 56,
              height: 56,
              child: _buildScanThumbnail(scan),
            ),
            title: Text(
              hasMatch
                  ? (scan.topTitle ?? '-')
                  : l10n.translate('no_match_found'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                [
                  if (confidence != null && hasMatch)
                    '%${(confidence * 100).toStringAsFixed(0)}',
                  dateFormat.format(scan.scannedAt),
                ].join(' • '),
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              tooltip: l10n.translate('delete'),
              onPressed: () => _deleteScan(scan),
            ),
            onTap: hasMatch
                ? () => context.push('/variant/${scan.topArticleId}')
                : null,
          );
        },
      ),
    );
  }

  Widget _buildScanThumbnail(ScanRecord scan) {
    final path = scan.imagePath;
    if (path != null && File(path).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(path),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _thumbPlaceholder(),
        ),
      );
    }
    return _thumbPlaceholder();
  }

  Widget _thumbPlaceholder() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Icon(Icons.image, color: Colors.grey, size: 24),
    );
  }

  // ---------- Görüntülenenler sekmesi UI ----------

  Widget _buildViewsTab(AppLocalizations l10n, ThemeData theme) {
    if (_viewsLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_viewHistory.isEmpty) {
      return _buildEmptyState(
        icon: Icons.visibility_outlined,
        title: 'Henüz görüntüleme geçmişi yok',
        subtitle: 'Görüntülediğiniz sikkeler burada görünecek',
        buttonLabel: 'Sikke Ara',
        buttonIcon: Icons.search,
        onPressed: () => context.go('/browse'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadViewHistory,
      child: ListView.separated(
        itemCount: _viewHistory.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final variant = _viewHistory[index];
          final thumbnailUrl = _thumbnailCache[variant.articleId];

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            leading: SizedBox(
              width: 56,
              height: 56,
              child: thumbnailUrl == null
                  ? _thumbPlaceholder()
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          color: Colors.grey[200],
                          child: const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                              ),
                            ),
                          ),
                        ),
                        errorWidget: (context, url, error) => Container(
                          color: Colors.grey[200],
                          child: const Icon(
                            Icons.broken_image,
                            color: Colors.grey,
                            size: 24,
                          ),
                        ),
                      ),
                    ),
            ),
            title: Text(
              variant.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '${RegionData.getRegionName(variant.regionCode)} • ${variant.material ?? '-'}',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ),
            trailing: const Icon(Icons.chevron_right, size: 20),
            onTap: () => context.push('/variant/${variant.articleId}'),
          );
        },
      ),
    );
  }

  // ---------- Ortak boş durum ----------

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
    required String buttonLabel,
    required IconData buttonIcon,
    required VoidCallback onPressed,
  }) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(buttonIcon),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
