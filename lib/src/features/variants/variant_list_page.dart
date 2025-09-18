import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/variant.dart';
import 'variants_api.dart';

class VariantListPage extends ConsumerStatefulWidget {
  const VariantListPage({super.key});

  @override
  ConsumerState<VariantListPage> createState() => _VariantListPageState();
}

class _VariantListPageState extends ConsumerState<VariantListPage> {
  final _scroll = ScrollController();
  final _items = <Variant>[];
  final _mintCtrl = TextEditingController(text: 'selge');

  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _onlyImages = false;       // ❗ varsayılan KAPALI
  String _sort = 'uid_asc';       // ❗ güvenli varsayılan

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200 && !_loading && _hasMore) {
        _page++;
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _mintCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    setState(() => _loading = true);
    if (reset) { _items.clear(); _page = 1; _hasMore = true; }
    final api = ref.read(variantsApiProvider);
    try {
      final (list, meta) = await api.list(
        mint: _mintCtrl.text.trim().isEmpty ? null : _mintCtrl.text.trim(),
        hasImages: _onlyImages,
        page: _page,
        perPage: 20,
        sort: _sort,
      );
      setState(() {
        _items.addAll(list);
        final total = (meta['total'] ?? 0) as int;
        _hasMore = _items.length < total;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anatolian Coins'),
        actions: [
          IconButton(
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person),
            tooltip: 'Account',
          )
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 8,
              spacing: 8,
              children: [
                SizedBox(
                  width: 220,
                  child: TextField(
                    controller: _mintCtrl,
                    decoration: const InputDecoration(labelText: 'Mint (ör. selge)'),
                    onSubmitted: (_) => _load(reset: true),
                  ),
                ),
                FilterChip(
                  label: const Text('Has images'),
                  selected: _onlyImages,
                  onSelected: (v) { setState(() => _onlyImages = v); _load(reset: true); },
                ),
                DropdownButton<String>(
                  value: _sort,
                  items: const [
                    DropdownMenuItem(value: 'uid_asc', child: Text('UID ↑')),
                    DropdownMenuItem(value: 'updated_at_desc', child: Text('Updated ↓')),
                  ],
                  onChanged: (v) { setState(() => _sort = v!); _load(reset: true); },
                ),
                FilledButton.icon(
                  onPressed: () => _load(reset: true),
                  icon: const Icon(Icons.search),
                  label: const Text('Search'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _items.isEmpty && _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    controller: _scroll,
                    itemCount: _items.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      if (index >= _items.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final v = _items[index];
                      return ListTile(
                        title: Text(v.title),
                        subtitle: Text('${v.regionCode ?? '-'} • ${v.material ?? '-'}'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.go('/variant/${v.articleId}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
