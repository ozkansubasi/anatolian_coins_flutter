import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/variant.dart';
import '../../core/region_data.dart';
import 'variants_api.dart';

class VariantListPage extends ConsumerStatefulWidget {
  const VariantListPage({super.key});

  @override
  ConsumerState<VariantListPage> createState() => _VariantListPageState();
}

class _VariantListPageState extends ConsumerState<VariantListPage> {
  final _scroll = ScrollController();
  final _items = <Variant>[];
  final _searchCtrl = TextEditingController();
  
  String? _selectedRegion;
  String? _selectedMint;
  
  int _page = 1;
  bool _loading = false;
  bool _hasMore = true;
  bool _onlyImages = false;
  String _sort = 'uid_asc';
  bool _useSearch = false; // TextField kullan/kullanma

  // Görsel cache için map
  final Map<int, String?> _thumbnailCache = {};

  @override
  void initState() {
    super.initState();
    _load();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200 && 
          !_loading && 
          _hasMore) {
        _page++;
        _load();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    
    setState(() => _loading = true);
    if (reset) {
      _items.clear();
      _page = 1;
      _hasMore = true;
      _thumbnailCache.clear();
    }
    
    final api = ref.read(variantsApiProvider);
    try {
      // Arama modu aktifse sadece mint parametresi gönder
      final mintParam = _useSearch && _searchCtrl.text.trim().isNotEmpty
          ? _searchCtrl.text.trim()
          : _selectedMint;
      
      final (list, meta) = await api.list(
        region: _selectedRegion,
        mint: mintParam,
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
      
      // Görselleri yükle (background'da)
      _loadThumbnails(list);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
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
        // Hata sessizce ignore et
        _thumbnailCache[variant.articleId] = null;
      }
    }
  }

  List<String> _getMintsForSelectedRegion() {
    if (_selectedRegion == null) return [];
    return RegionData.getMintsForRegion(_selectedRegion);
  }

  @override
  Widget build(BuildContext context) {
    final allRegions = RegionData.getAllRegions();
    final availableMints = _getMintsForSelectedRegion();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Anatolian Coins'),
        actions: [
          IconButton(
            onPressed: () => context.push('/account'),
            icon: const Icon(Icons.person),
            tooltip: 'Hesap',
          )
        ],
      ),
      body: Column(
        children: [
          // Filtre bölümü
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Bölge seçimi
                DropdownButtonFormField<String>(
                  value: _selectedRegion,
                  decoration: InputDecoration(
                    labelText: 'Bölge',
                    prefixIcon: const Icon(Icons.map),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tüm Bölgeler'),
                    ),
                    ...allRegions.map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedRegion = value;
                      _selectedMint = null; // Darphane sıfırla
                    });
                    _load(reset: true);
                  },
                ),
                
                const SizedBox(height: 12),
                
                // Darphane seçimi veya arama
                Row(
                  children: [
                    Expanded(
                      child: _useSearch
                          ? TextField(
                              controller: _searchCtrl,
                              decoration: InputDecoration(
                                labelText: 'Darphane Ara',
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              onSubmitted: (_) => _load(reset: true),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedMint,
                              decoration: InputDecoration(
                                labelText: 'Darphane (Opsiyonel)',
                                prefixIcon: const Icon(Icons.location_city),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Tüm Darphaneler'),
                                ),
                                ...availableMints.map((mint) => DropdownMenuItem(
                                  value: mint,
                                  child: Text(mint.replaceAll('_', ' ').toUpperCase()),
                                )),
                              ],
                              onChanged: availableMints.isEmpty ? null : (value) {
                                setState(() => _selectedMint = value);
                                _load(reset: true);
                              },
                            ),
                    ),
                    IconButton(
                      icon: Icon(_useSearch ? Icons.list : Icons.search),
                      tooltip: _useSearch ? 'Listeye geç' : 'Aramaya geç',
                      onPressed: () {
                        setState(() {
                          _useSearch = !_useSearch;
                          if (!_useSearch) {
                            _searchCtrl.clear();
                          } else {
                            _selectedMint = null;
                          }
                        });
                      },
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // Sıralama ve filtreler
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sort,
                        decoration: InputDecoration(
                          labelText: 'Sırala',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'uid_asc',
                            child: Text('UID ↑'),
                          ),
                          DropdownMenuItem(
                            value: 'uid_desc',
                            child: Text('UID ↓'),
                          ),
                          DropdownMenuItem(
                            value: 'updated_at_desc',
                            child: Text('Güncelleme ↓'),
                          ),
                        ],
                        onChanged: (v) {
                          setState(() => _sort = v!);
                          _load(reset: true);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Görselli'),
                      selected: _onlyImages,
                      onSelected: (v) {
                        setState(() => _onlyImages = v);
                        _load(reset: true);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Liste
          Expanded(
            child: _items.isEmpty && _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? const Center(child: Text('Sonuç bulunamadı'))
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
                          final thumbnailUrl = _thumbnailCache[v.articleId];
                          
                          return ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            leading: SizedBox(
                              width: 60,
                              height: 60,
                              child: thumbnailUrl == null
                                  ? Container(
                                      decoration: BoxDecoration(
                                        color: Colors.grey[200],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.image,
                                        color: Colors.grey,
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
                                              width: 20,
                                              height: 20,
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
                                          ),
                                        ),
                                      ),
                                    ),
                            ),
                            title: Text(
                              v.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${RegionData.getRegionName(v.regionCode)} • ${v.material ?? '-'}',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 13,
                              ),
                            ),
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