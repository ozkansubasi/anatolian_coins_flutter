import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/num_colors.dart';
import '../../core/subscription_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/collection.dart';
import '../../widgets/pro_feature.dart';
import 'collections_service.dart';

/// Sikke detayından koleksiyona ekleme / çıkarma (M43b, 2026-11-23).
///
/// Boş koleksiyon metni "sikke detay sayfasından ekleyebilirsiniz" diyordu ama
/// detayda böyle bir düğme yoktu. Koleksiyonlar cihaz-yereldir. Ücretsiz kademede
/// yalnız YENİ koleksiyon oluşturma sınırlıdır ([FeatureLimits.freeMaxCollections]);
/// var olan koleksiyona ekleme serbesttir (koleksiyon sayfasıyla aynı kural).
Future<void> showAddToCollectionSheet(BuildContext context, int articleId) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AddToCollectionSheet(articleId: articleId),
  );
}

class _AddToCollectionSheet extends ConsumerStatefulWidget {
  const _AddToCollectionSheet({required this.articleId});

  final int articleId;

  @override
  ConsumerState<_AddToCollectionSheet> createState() => _AddToCollectionSheetState();
}

class _AddToCollectionSheetState extends ConsumerState<_AddToCollectionSheet> {
  List<Collection> _collections = const [];
  Set<int> _member = {};
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = ref.read(collectionsServiceProvider);
    final collections = await service.getAllCollections();
    final ids = await service.getCollectionsForVariant(widget.articleId);
    if (!mounted) return;
    setState(() {
      _collections = collections;
      _member = ids.toSet();
      _loading = false;
    });
  }

  Future<void> _toggle(Collection collection) async {
    if (_busy) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final service = ref.read(collectionsServiceProvider);
    final wasMember = _member.contains(collection.id);
    setState(() => _busy = true);
    try {
      if (wasMember) {
        await service.removeFromCollection(collection.id, widget.articleId);
      } else {
        await service.addToCollection(collection.id, widget.articleId);
      }
      // Koleksiyonlar sayfasındaki sikke sayıları güncellensin.
      await ref.read(collectionsControllerProvider.notifier).loadCollections();
      if (!mounted) return;
      setState(() => wasMember ? _member.remove(collection.id) : _member.add(collection.id));
      messenger.showSnackBar(SnackBar(
        content: Text(wasMember
            ? l10n.translate('removed_from_collection')
            : l10n.translate('added_to_collection', params: {'name': collection.name})),
        duration: const Duration(seconds: 1),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.translate('error')}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context);
    final isPro = ref.read(subscriptionProvider).isPro;
    if (!isPro && _collections.length >= FeatureLimits.freeMaxCollections) {
      final router = GoRouter.of(context);
      final sheetNavigator = Navigator.of(context);
      await showProFeatureDialog(
        context,
        featureName: l10n.translate('feature_unlimited_collections'),
        onBuy: () {
          sheetNavigator.pop();
          router.push('/subscription');
        },
      );
      return;
    }

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.translate('new_collection')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.translate('collection_name'),
            hintText: l10n.translate('collection_name_hint'),
          ),
          onSubmitted: (v) => Navigator.pop(dialogContext, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.translate('cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text.trim()),
            child: Text(l10n.translate('create')),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final id = await ref.read(collectionsControllerProvider.notifier).createCollection(name);
      if (id == null) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.translate('error'))));
        return;
      }
      await ref.read(collectionsServiceProvider).addToCollection(id, widget.articleId);
      await ref.read(collectionsControllerProvider.notifier).loadCollections();
      await _load();
      messenger.showSnackBar(SnackBar(
        content: Text(l10n.translate('added_to_collection', params: {'name': name})),
        duration: const Duration(seconds: 1),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('${l10n.translate('error')}: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    final media = MediaQuery.of(context);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  l10n.translate('add_to_collection'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final col in _collections)
                        CheckboxListTile(
                          value: _member.contains(col.id),
                          onChanged: _busy ? null : (_) => _toggle(col),
                          title: Text(col.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          activeColor: c.accent,
                        ),
                      ListTile(
                        leading: Icon(Icons.add, color: c.accent),
                        title: Text(l10n.translate('new_collection')),
                        onTap: _busy ? null : _create,
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
