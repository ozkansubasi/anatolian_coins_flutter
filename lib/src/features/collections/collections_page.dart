import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../models/collection.dart';
import 'collections_service.dart';
import '../../prokit_ui/widgets/num_bottom_nav.dart';

/// Collections List Page - Manage user collections
class CollectionsPage extends ConsumerWidget {
  const CollectionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final collectionsAsync = ref.watch(collectionsControllerProvider);

    return Scaffold(
      bottomNavigationBar: const NumBottomNav(currentTab: NavTab.favorites),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.collections_rounded, size: 20),
            const SizedBox(width: 8),
            Text(l10n.translate('my_collections')),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            tooltip: 'Yeni Koleksiyon',
            onPressed: () => _showCreateDialog(context, ref),
          ),
        ],
      ),
      body: collectionsAsync.when(
        data: (collections) {
          if (collections.isEmpty) {
            return _buildEmptyState(l10n, theme);
          }
          return RefreshIndicator(
            onRefresh: () async {
              ref.read(collectionsControllerProvider.notifier).loadCollections();
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
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text('Hata: $error'),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () {
                  ref.read(collectionsControllerProvider.notifier).loadCollections();
                },
                child: const Text('Tekrar Dene'),
              ),
            ],
          ),
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
            Icons.collections_rounded,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Henüz koleksiyon yok',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sikkelerinizi organize etmek için koleksiyon oluşturun',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  void _showCreateDialog(BuildContext context, WidgetRef ref) {
    final nameController = TextEditingController();
    final descController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Koleksiyon'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Koleksiyon Adı',
                hintText: 'Örn: Roma İmparatorluğu',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Açıklama (Opsiyonel)',
                hintText: 'Koleksiyon hakkında notlar...',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen bir ad girin')),
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
                    SnackBar(content: Text('$name oluşturuldu')),
                  );
                  // Navigate to the new collection
                  context.go('/collection/$collectionId');
                }
              }
            },
            child: const Text('Oluştur'),
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
                color: Colors.grey[600],
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
        context.go('/collection/${collection.id}');
      },
    );
  }

  void _showOptionsMenu(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Düzenle'),
              onTap: () {
                Navigator.pop(context);
                _showEditDialog(context, ref);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Sil', style: TextStyle(color: Colors.red)),
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
    final nameController = TextEditingController(text: collection.name);
    final descController = TextEditingController(text: collection.description);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Koleksiyonu Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Koleksiyon Adı',
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.words,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: 'Açıklama',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Lütfen bir ad girin')),
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
                    const SnackBar(content: Text('Koleksiyon güncellendi')),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
        title: const Text('Koleksiyonu Sil?'),
        content: Text(
          '${collection.name} koleksiyonu ve içindeki ${collection.itemCount} sikke silinecek. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
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
                    const SnackBar(content: Text('Koleksiyon silindi')),
                  );
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }
}
