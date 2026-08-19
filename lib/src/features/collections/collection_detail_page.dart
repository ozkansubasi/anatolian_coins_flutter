import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/variant.dart';
import '../../core/region_data.dart';
import '../../l10n/app_localizations.dart';
import '../variants/variants_api.dart';
import 'collections_service.dart';

/// Collection Detail Page - View and manage coins in a collection
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
  final Map<int, String?> _thumbnailCache = {};
  String _collectionName = '';

  @override
  void initState() {
    super.initState();
    _loadCollection();
  }

  Future<void> _loadCollection() async {
    setState(() => _loading = true);

    try {
      final service = ref.read(collectionsServiceProvider);
      final api = ref.read(variantsApiProvider);

      // Get collection details
      final collection = await service.getCollection(widget.collectionId);
      if (collection == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Koleksiyon bulunamadı')),
          );
          context.go('/');
        }
        return;
      }

      _collectionName = collection.name;

      // Get variant IDs in collection
      final variantIds = await service.getCollectionItems(widget.collectionId);

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
          _variants = variants;
          _loading = false;
        });

        // Load thumbnails
        _loadThumbnails(variants);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e')),
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

  Future<void> _removeFromCollection(int variantId, String variantTitle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Koleksiyondan Çıkar?'),
        content: Text('$variantTitle koleksiyondan çıkarılacak.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Çıkar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final service = ref.read(collectionsServiceProvider);
        await service.removeFromCollection(widget.collectionId, variantId);
        await _loadCollection();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Koleksiyondan çıkarıldı')),
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.folder_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _collectionName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _variants.isEmpty
              ? _buildEmptyState(l10n, theme)
              : RefreshIndicator(
                  onRefresh: _loadCollection,
                  child: ListView.separated(
                    itemCount: _variants.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final variant = _variants[index];
                      final thumbnailUrl = _thumbnailCache[variant.articleId];

                      return Dismissible(
                        key: Key('variant_${variant.articleId}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          color: Colors.red,
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 16),
                          child: const Icon(
                            Icons.delete,
                            color: Colors.white,
                          ),
                        ),
                        confirmDismiss: (direction) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Koleksiyondan Çıkar?'),
                              content: Text('${variant.title} koleksiyondan çıkarılacak.'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('İptal'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                                  child: const Text('Çıkar'),
                                ),
                              ],
                            ),
                          );
                        },
                        onDismissed: (direction) async {
                          try {
                            final service = ref.read(collectionsServiceProvider);
                            await service.removeFromCollection(widget.collectionId, variant.articleId);

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text('Koleksiyondan çıkarıldı'),
                                  action: SnackBarAction(
                                    label: 'Geri Al',
                                    onPressed: () async {
                                      await service.addToCollection(widget.collectionId, variant.articleId);
                                      await _loadCollection();
                                    },
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Hata: $e')),
                              );
                            }
                          }
                        },
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          leading: SizedBox(
                            width: 56,
                            height: 56,
                            child: thumbnailUrl == null
                                ? Container(
                                    decoration: BoxDecoration(
                                      color: Colors.grey[200],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.image,
                                      color: Colors.grey,
                                      size: 24,
                                    ),
                                  )
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
                                      errorWidget: (context, url, error) =>
                                          Container(
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
                          trailing: const Icon(
                            Icons.chevron_right,
                            size: 20,
                          ),
                          onTap: () => context.go('/variant/${variant.articleId}'),
                        ),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.folder_open_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Koleksiyon boş',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sikke detay sayfasından koleksiyona ekleyebilirsiniz',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => context.go('/browse'),
            icon: const Icon(Icons.search),
            label: const Text('Sikke Ara'),
          ),
        ],
      ),
    );
  }
}
