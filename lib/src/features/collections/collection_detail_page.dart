import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/variant.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/coin_list.dart';
import '../variants/variants_api.dart';
import 'collections_service.dart';

/// Koleksiyon detayı: koleksiyondaki sikkeler (2026-09-21 yeniden: ortak
/// CoinRow dili, l10n, paralel yükleme, görünür "çıkar" düğmesi).
class CollectionDetailPage extends ConsumerStatefulWidget {
  final int collectionId;

  const CollectionDetailPage({
    super.key,
    required this.collectionId,
  });

  @override
  ConsumerState<CollectionDetailPage> createState() => _CollectionDetailPageState();
}

class _CollectionDetailPageState extends ConsumerState<CollectionDetailPage> {
  bool _loading = true;
  List<Variant> _variants = [];
  String _collectionName = '';

  @override
  void initState() {
    super.initState();
    // İlk kareden sonra: _loadCollection AppLocalizations.of(context) kullanıyor
    // (initState içinde inherited widget okumak hata fırlatır).
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCollection());
  }

  void _snack(String text, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), action: action));
  }

  Future<void> _loadCollection() async {
    final l10n = AppLocalizations.of(context);
    setState(() => _loading = true);

    try {
      final service = ref.read(collectionsServiceProvider);
      final collection = await service.getCollection(widget.collectionId);
      if (collection == null) {
        if (mounted) {
          _snack(l10n.translate('collection_not_found'));
          context.go('/collections');
        }
        return;
      }
      _collectionName = collection.name;

      final ids = await service.getCollectionItems(widget.collectionId);
      final variants = await loadVariantsInOrder(ref.read(variantsApiProvider), ids);

      if (mounted) {
        setState(() {
          _variants = variants;
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Collection load error: $e');
      if (mounted) {
        setState(() => _loading = false);
        _snack(l10n.translate('error_generic'));
      }
    }
  }

  Future<bool> _confirmRemove(Variant v) {
    final l10n = AppLocalizations.of(context);
    return confirmDestructive(
      context,
      title: l10n.translate('remove_from_collection_title'),
      message: l10n.translate('remove_from_collection_body', params: {'title': v.title}),
      confirmLabel: l10n.translate('remove'),
    );
  }

  /// Çıkarır ve "Geri Al" sunar. Liste yerelde güncellenir (tam yeniden yükleme yok).
  Future<void> _remove(Variant v) async {
    final l10n = AppLocalizations.of(context);
    final service = ref.read(collectionsServiceProvider);
    final index = _variants.indexOf(v);
    setState(() => _variants.remove(v));
    try {
      await service.removeFromCollection(widget.collectionId, v.articleId);
      if (!mounted) return;
      _snack(
        l10n.translate('removed_from_collection'),
        action: SnackBarAction(
          label: l10n.translate('undo'),
          onPressed: () async {
            await service.addToCollection(widget.collectionId, v.articleId);
            if (mounted) setState(() => _variants.insert(index.clamp(0, _variants.length), v));
          },
        ),
      );
    } catch (e) {
      debugPrint('Remove from collection error: $e');
      if (mounted) {
        setState(() => _variants.insert(index.clamp(0, _variants.length), v));
        _snack(l10n.translate('error_generic'));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;

    return Scaffold(
      appBar: AppBar(
        title: Text(_collectionName, overflow: TextOverflow.ellipsis),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: c.accent))
          : _variants.isEmpty
              ? EmptyStateView(
                  icon: Icons.collections_bookmark_outlined,
                  title: l10n.translate('collection_empty'),
                  message: l10n.translate('collection_empty_hint'),
                  actionLabel: l10n.translate('browse_coins'),
                  actionIcon: Icons.search,
                  onAction: () => context.go('/browse'),
                )
              : RefreshIndicator(
                  color: c.accent,
                  onRefresh: _loadCollection,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                    children: [
                      CoinRowCard(
                        children: [
                          for (var i = 0; i < _variants.length; i++)
                            _dismissible(_variants[i], last: i == _variants.length - 1, l10n: l10n),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _dismissible(Variant v, {required bool last, required AppLocalizations l10n}) {
    final c = context.numColors;
    return Dismissible(
      key: ValueKey('variant_${v.articleId}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.remove_circle_outline, color: Colors.white),
      ),
      confirmDismiss: (_) => _confirmRemove(v),
      onDismissed: (_) => _remove(v),
      child: CoinRow(
        leading: CoinThumb(articleId: v.articleId),
        title: v.title,
        meta: coinMetaLine(v, l10n),
        last: last,
        onTap: () => context.push('/variant/${v.articleId}'),
        // Kaydırma tek başına keşfedilmiyordu: görünür çıkarma düğmesi.
        trailing: IconButton(
          tooltip: l10n.translate('remove'),
          icon: Icon(Icons.remove_circle_outline, color: c.hint),
          onPressed: () async {
            if (await _confirmRemove(v)) _remove(v);
          },
        ),
      ),
    );
  }
}
