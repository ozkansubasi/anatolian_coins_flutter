import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/variant.dart';
import 'variants_api.dart';

// Bölge ve darphane verileri
const regions = {
  'pisidia-coins': 'Pisidia',
  // Diğer bölgeler eklenebilir
};

const regionMints = {
  'pisidia-coins': [
    'adada', 'amblada', 'andeda', 'antiocheia_pisidia', 'apollonia_mordiaion',
    'ariassos', 'baris_pisidia', 'codrula', 'colonia_pisidia', 'comama',
    'conana', 'cremna', 'etenna', 'isinda_pisidia', 'lagbe', 'lysinia',
    'olbasa', 'panemoteichos', 'pednelissos', 'pogla', 'prostanna',
    'sagalassos', 'sandalion', 'selge', 'termessos', 'timbriada', 'verbe'
  ],
};

class VariantListPage extends ConsumerStatefulWidget {
  const VariantListPage({super.key});

  @override
  ConsumerState<VariantListPage> createState() => _VariantListPageState();
}

class _VariantListPageState extends ConsumerState<VariantListPage> {
  final _scroll = ScrollController();
  final _items = <Variant>[];

  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _onlyImages = false;
  String _sort = 'uid_asc';
  bool _isSearchExpanded = false;
  
  String? _selectedRegion = 'pisidia-coins';
  String? _selectedMint;
  List<String> _availableMints = [];

  @override
  void initState() {
    super.initState();
    _updateAvailableMints();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400 && !_loading && _hasMore) {
        _page++;
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _updateAvailableMints() {
    if (_selectedRegion != null && regionMints.containsKey(_selectedRegion)) {
      _availableMints = regionMints[_selectedRegion]!;
      // Eğer seçili mint yeni bölgede yoksa temizle
      if (_selectedMint != null && !_availableMints.contains(_selectedMint)) {
        _selectedMint = null;
      }
    } else {
      _availableMints = [];
      _selectedMint = null;
    }
  }

  Future<void> _load({bool reset = false}) async {
    setState(() => _loading = true);
    if (reset) {
      _items.clear();
      _page = 1;
      _hasMore = true;
    }
    
    final api = ref.read(variantsApiProvider);
    
    // En az bir filtre gerekli
    if (_selectedMint == null && _selectedRegion == null && !_onlyImages) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a region or mint')),
        );
      }
      return;
    }
    
    try {
      final (list, meta) = await api.list(
        region: _selectedRegion,
        mint: _selectedMint,
        hasImages: _onlyImages,
        page: _page,
        perPage: 20,
        sort: _sort,
      );
      
      print('✅ API SUCCESS: ${list.length} items loaded');
      print('✅ Total: ${meta['total']}');
      print('✅ Current page: $_page');
      print('✅ Total pages: ${meta['total_pages']}');
      
      setState(() {
        _items.addAll(list);
        final totalPages = (meta['total_pages'] ?? 1) as int;
        _hasMore = _page < totalPages;
      });
      
      print('✅ State updated: ${_items.length} total items, hasMore: $_hasMore');
    } catch (e, stackTrace) {
      print('❌ ERROR: $e');
      print('❌ STACK: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Load error: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
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
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () => setState(() => _isSearchExpanded = !_isSearchExpanded),
            icon: Icon(_isSearchExpanded ? Icons.close : Icons.tune),
            tooltip: 'Filters',
          ),
          IconButton(
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person_outline),
            tooltip: 'Account',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Section
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isSearchExpanded ? null : 0,
            child: _isSearchExpanded
                ? Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Region Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedRegion,
                          decoration: InputDecoration(
                            labelText: 'Region',
                            prefixIcon: const Icon(Icons.map_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                          items: regions.entries.map((e) {
                            return DropdownMenuItem(value: e.key, child: Text(e.value));
                          }).toList(),
                          onChanged: (v) {
                            setState(() {
                              _selectedRegion = v;
                              _updateAvailableMints();
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        
                        // Mint Dropdown
                        DropdownButtonFormField<String>(
                          value: _selectedMint,
                          decoration: InputDecoration(
                            labelText: 'Mint (Optional)',
                            prefixIcon: const Icon(Icons.place_outlined),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All mints')),
                            ..._availableMints.map((mint) {
                              return DropdownMenuItem(
                                value: mint,
                                child: Text(mint.replaceAll('_', ' ').toUpperCase()),
                              );
                            }),
                          ],
                          onChanged: (v) => setState(() => _selectedMint = v),
                        ),
                        const SizedBox(height: 12),
                        
                        Row(
                          children: [
                            Expanded(
                              child: FilterChip(
                                label: const Text('Has images'),
                                selected: _onlyImages,
                                onSelected: (v) => setState(() => _onlyImages = v),
                                avatar: Icon(_onlyImages ? Icons.check_circle : Icons.image_outlined, size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: DropdownButtonFormField<String>(
                                value: _sort,
                                decoration: InputDecoration(
                                  labelText: 'Sort by',
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                ),
                                items: const [
                                  DropdownMenuItem(value: 'uid_asc', child: Text('UID (A→Z)')),
                                  DropdownMenuItem(value: 'updated_at_desc', child: Text('Recently Updated')),
                                ],
                                onChanged: (v) => setState(() => _sort = v!),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => _load(reset: true),
                            icon: const Icon(Icons.search),
                            label: const Text('Search'),
                          ),
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),

          // Grid View
          Expanded(
            child: _loading && _items.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.search, size: 64, color: Theme.of(context).colorScheme.outline),
                              const SizedBox(height: 16),
                              Text('Search for coins', style: Theme.of(context).textTheme.titleLarge),
                              const SizedBox(height: 8),
                              Text(
                                'Select a region and optionally a mint above',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : GridView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.78,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: _items.length + (_hasMore ? 2 : 0),
                        itemBuilder: (context, index) {
                          if (index >= _items.length) {
                            return const Center(
                              child: Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(),
                              ),
                            );
                          }
                          final v = _items[index];
                          return _CoinCard(
                            variant: v,
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

class _CoinCard extends ConsumerStatefulWidget {
  final Variant variant;
  final VoidCallback onTap;

  const _CoinCard({required this.variant, required this.onTap});

  @override
  ConsumerState<_CoinCard> createState() => _CoinCardState();
}

class _CoinCardState extends ConsumerState<_CoinCard> {
  String? _imageUrl;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    // Geçici olarak görsel yüklemeyi kapat - performans için
    // _loadImage();
  }

  Future<void> _loadImage() async {
    setState(() => _loading = true);
    final api = ref.read(variantsApiProvider);
    final url = await api.getFirstImageUrl(widget.variant.articleId, wm: true);
    if (mounted) {
      setState(() {
        _imageUrl = url;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                child: _loading
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      )
                    : _imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: _imageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) => Icon(
                              Icons.image_not_supported,
                              size: 48,
                              color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                            ),
                          )
                        : Icon(
                            Icons.toll,
                            size: 64,
                            color: Theme.of(context).colorScheme.outline.withOpacity(0.3),
                          ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            widget.variant.title,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.variant.regionCode ?? 'Unknown region',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  fontSize: 11,
                                ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (widget.variant.material != null)
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.secondaryContainer,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                widget.variant.material!,
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                                      fontWeight: FontWeight.w500,
                                    ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}