import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/subscription_provider.dart';
import '../../core/navigation.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../models/collection.dart';
import 'collections_service.dart';
import '../../widgets/coin_list.dart';

/// Collections List Page - Manage user collections
class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final collectionsAsync = ref.watch(collectionsControllerProvider);
    final c = context.numColors;

    return Scaffold(
      appBar: AppBar(
        leading: context.returnLeading,
        title: Text(l10n.translate('my_collections')),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: l10n.translate('new_collection'),
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return _buildEmptyState(context, ref, l10n);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref
                  .read(collectionsControllerProvider.notifier)
                  .loadCollections();
            },
            child: ListView.separated(
              itemCount: collections.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final collection = collections[index];
                return _CollectionListItem(collection: collection);
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: c.hint),
              const SizedBox(height: 16),
              Text(l10n.translate('error_prefix', params: {'error': '$error'})),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref
                      .read(collectionsControllerProvider.notifier)
                      .loadCollections();
                },
                child: Text(l10n.translate('retry')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Boş durum: Geçmiş sayfasındaki gibi doğrudan eylem düğmesi taşır; tek
  /// giriş sağ üstteki küçük + idi ve boş sayfada gözden kaçıyordu.
  Widget _buildEmptyState(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    return EmptyStateView(
      icon: Icons.collections_rounded,
      title: l10n.translate('no_collections_yet'),
      message: l10n.translate('no_collections_hint'),
      actionLabel: l10n.translate('new_collection'),
      actionIcon: Icons.add,
      onAction: () => _showCreateDialog(context, ref),
    );
  }

  void _showCollectionLimitDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.lock_outline, size: 20),
            const SizedBox(width: 12),
            Expanded(child: Text(l10n.translate('pro_feature'))),
          ],
        ),
        content: Text(
          l10n.translate(
            'feature_locked_message',
            params: {
              'featureName': l10n.translate('feature_unlimited_collections')
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('close')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              context.push('/subscription');
            },
            child: Text(l10n.translate('buy_pro')),
          ),
        ],
      ),
    );
  }

  /// ADR-006: ücretsiz kademe 1 koleksiyonla sınırlı, Pro sınırsız.
  /// Geçiş kuralı bilinçli olarak korumacı: mevcut koleksiyonlar silinmez veya
  /// gizlenmez, kapı yalnızca YENİ oluşturmayı engeller. Koleksiyonlar cihaz-yerel
  /// olduğu için etkilenen kullanıcı sayısı sunucudan ölçülemiyor.
  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final subscription = ref.read(subscriptionProvider);

    if (!subscription.isPro) {
      final existing =
          ref.read(collectionsControllerProvider).value ?? const [];
      if (existing.length >= FeatureLimits.freeMaxCollections) {
        _showCollectionLimitDialog(context, l10n);
        return;
      }
    }

    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('new_collection')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.translate('collection_name'),
                hintText: l10n.translate('collection_name_hint'),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: l10n.translate('collection_description_optional'),
                hintText: l10n.translate('collection_description_hint'),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.translate('enter_name'))),
                );
                return;
              }

              final description = descController.text.trim();
              final collectionId = await ref
                  .read(collectionsControllerProvider.notifier)
                  .createCollection(
                    name,
                    description: description.isEmpty ? null : description,
                  );

              if (context.mounted) {
                Navigator.pop(context);
                if (collectionId != null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l10n.translate('collection_created',
                            params: {'name': name}))),
                  );
                  // Navigate to the new collection
                  context.push('/collection/$collectionId');
                }
              }
            },
            child: Text(l10n.translate('create')),
          ),
        ],
      ),
    );
  }
}

/// Collection List Item Widget
class _CollectionListItem extends ConsumerWidget {
  final Collection collection;

  const _CollectionListItem({required this.collection});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final c = context.numColors;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          Icons.folder_rounded,
          color: theme.colorScheme.primary,
          size: 28,
        ),
      ),
      title: Text(
        collection.name,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (collection.description != null) ...[
            const SizedBox(height: 4),
            Text(
              collection.description!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                color: c.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            '${collection.itemCount} sikke',
            style: TextStyle(
              fontSize: 12,
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.more_vert),
        onPressed: () => _showOptionsMenu(context, ref),
      ),
      onTap: () {
        context.push('/collection/${collection.id}');
      },
    );
  }

  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(l10n.translate('edit')),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: Text(l10n.translate('delete'),
                  style: const TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(context);
                _showDeleteDialog(context, ref);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final nameController = TextEditingController(text: collection.name);
    final descController = TextEditingController(text: collection.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.translate('edit_collection')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: l10n.translate('collection_name'),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: InputDecoration(
                labelText: l10n.translate('collection_description'),
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(l10n.translate('enter_name'))),
                );
                return;
              }

              final description = descController.text.trim();
              final success = await ref
                  .read(collectionsControllerProvider.notifier)
                  .updateCollection(
                    collection.id,
                    name: name,
                    description: description.isEmpty ? null : description,
                  );

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l10n.translate('collection_updated'))),
                  );
                }
              }
            },
            child: Text(l10n.translate('save')),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded,
            size: 48, color: Colors.orange),
        title: Text(l10n.translate('delete_collection_title')),
        content: Text(
          l10n.translate('delete_collection_body', params: {
            'name': collection.name,
            'count': '${collection.itemCount}'
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () async {
              final success = await ref
                  .read(collectionsControllerProvider.notifier)
                  .deleteCollection(collection.id);

              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(l10n.translate('collection_deleted'))),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: Text(l10n.translate('delete')),
          ),
        ],
      ),
    );
  }
}
