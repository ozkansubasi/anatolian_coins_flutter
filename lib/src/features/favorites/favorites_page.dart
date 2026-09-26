import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/variant.dart';
import '../../core/region_data.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../core/navigation.dart';
import '../variants/variants_api.dart';
import 'favorites_service.dart';

/// Favoriler Sayfası - Pro Özelliği
class FavoritesPage extends ConsumerStatefulWidget {
  const FavoritesPage({super.key});

  @override
  ConsumerState<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends ConsumerState<FavoritesPage> {
  bool _loading = true;
  List<Variant> _favorites = [];
  final Map<int, String?> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    setState(() => _loading = true);

    try {
      final service = ref.read(favoritesServiceProvider);
      final variants = await service.getFavoriteVariants();

      if (mounted) {
        setState(() {
          _favorites = variants;
          _loading = false;
        });

        // Görselleri yükle
        _loadThumbnails(variants);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context).translate(
                  'favorites_load_failed',
                  params: {'error': '$e'}))),
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final favoritesController = ref.watch(favoritesControllerProvider);
    final c = context.numColors;

    return Scaffold(
      appBar: AppBar(
        leading: context.returnLeading,
        title: Text(l10n.translate('my_favorites')),
        actions: [
          if (_favorites.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: l10n.translate('refresh'),
              onPressed: _loadFavorites,
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _favorites.isEmpty
              ? _buildEmptyState(l10n, theme)
              : RefreshIndicator(
                  onRefresh: _loadFavorites,
                  child: ListView.separated(
                    itemCount: _favorites.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final variant = _favorites[index];
                      final thumbnailUrl = _thumbnailCache[variant.articleId];
                      final isFavorite =
                          favoritesController.contains(variant.articleId);

                      return ListTile(
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
                                    color: c.surface,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.image,
                                    color: c.textMuted,
                                    size: 24,
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: CachedNetworkImage(
                                    imageUrl: thumbnailUrl,
                                    fit: BoxFit.cover,
                                    placeholder: (context, url) => Container(
                                      color: c.surface,
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
                                      color: c.surface,
                                      child: Icon(
                                        Icons.broken_image,
                                        color: c.textMuted,
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
                            '${RegionData.getRegionName(variant.regionCode, l10n)} • ${variant.material ?? '-'}',
                            style: TextStyle(
                              color: c.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w300,
                            ),
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            isFavorite ? Icons.favorite : Icons.favorite_border,
                            color: isFavorite ? Colors.red : c.textMuted,
                            size: 24,
                          ),
                          onPressed: () async {
                            await ref
                                .read(favoritesControllerProvider.notifier)
                                .remove(variant.articleId);

                            // Listeyi güncelle
                            await _loadFavorites();

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                      l10n.translate('removed_from_favorites')),
                                  duration: const Duration(seconds: 1),
                                ),
                              );
                            }
                          },
                        ),
                        onTap: () =>
                            context.push('/variant/${variant.articleId}'),
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildEmptyState(AppLocalizations l10n, ThemeData theme) {
    final c = context.numColors;
    return Center(
      child: Padding(
        // Açıklama kenarlara dayanıyordu (2026-09-26 cihaz incelemesi)
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.favorite_border,
              size: 64,
              color: c.hint,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.translate('no_favorites_yet'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.translate('no_favorites_hint'),
              style: TextStyle(
                fontSize: 14,
                color: c.textMuted,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => context.go('/browse'),
              icon: const Icon(Icons.search),
              label: Text(l10n.translate('browse_coins')),
            ),
          ],
        ),
      ),
    );
  }
}
