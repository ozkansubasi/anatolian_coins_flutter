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
      
      print('🔵 API Request: region=$_selectedRegion, mint=$mintParam, page=$_page');
      
      final (list, meta) = await api.list(
        region: _selectedRegion,
        mint: mintParam,
        hasImages: _onlyImages,
        page: _page,
        perPage: 20,
        sort: _sort,
      );
      
      print('✅ API Response: ${list.length} items, total=${meta['total']}');
      
      if (mounted) {
        setState(() {
          _items.addAll(list);
          final total = (meta['total'] ?? 0) as int;
          _hasMore = _items.length < total;
        });
        
        // Görselleri yükle (background'da)
        _loadThumbnails(list);
      }
    } catch (e) {
      print('❌ API Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Yükleme hatası: $e'),
            duration: const Duration(seconds: 2),
          ),
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
        if (mounted) {
          setState(() {
            _thumbnailCache[variant.articleId] = null;
          });
        }
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
        elevation: 0,
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
            padding: const EdgeInsets.all(10),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ✅ BÖLGE DROPDOWN - Siyah text + beyaz arka plan
                DropdownButtonFormField<String>(
                  value: _selectedRegion,
                  decoration: InputDecoration(
                    labelText: 'Bölge',
                    labelStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                      color: Colors.black87, // ✅ Label rengi
                    ),
                    prefixIcon: const Icon(Icons.map, size: 20, color: Colors.black87),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white, // ✅ Arka plan beyaz
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                  dropdownColor: Colors.white, // ✅ Dropdown arka plan beyaz
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w400, // ✅ w300'den w400'e (daha okunur)
                    color: Colors.black, // ✅ Text rengi
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Tüm Bölgeler', style: TextStyle(color: Colors.black)),
                    ),
                    ...allRegions.map((entry) => DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value, style: const TextStyle(color: Colors.black)),
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
                
                const SizedBox(height: 10),
                
                // ✅ DARPHANE DROPDOWN/SEARCH - Siyah text + beyaz arka plan
                Row(
                  children: [
                    Expanded(
                      child: _useSearch
                          ? TextField(
                              controller: _searchCtrl,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400, // ✅ w300'den w400'e
                                color: Colors.black, // ✅ Text rengi
                              ),
                              decoration: InputDecoration(
                                labelText: 'Darphane Ara',
                                labelStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black87, // ✅ Label rengi
                                ),
                                prefixIcon: const Icon(Icons.search, size: 20, color: Colors.black87),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white, // ✅ Arka plan beyaz
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              onSubmitted: (_) => _load(reset: true),
                            )
                          : DropdownButtonFormField<String>(
                              value: _selectedMint,
                              decoration: InputDecoration(
                                labelText: 'Darphane (Opsiyonel)',
                                labelStyle: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black87, // ✅ Label rengi
                                ),
                                prefixIcon: const Icon(Icons.location_city, size: 20, color: Colors.black87),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                filled: true,
                                fillColor: Colors.white, // ✅ Arka plan beyaz
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              dropdownColor: Colors.white, // ✅ Dropdown arka plan beyaz
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w400, // ✅ w300'den w400'e
                                color: Colors.black, // ✅ Text rengi
                              ),
                              items: [
                                const DropdownMenuItem(
                                  value: null,
                                  child: Text('Tüm Darphaneler', style: TextStyle(color: Colors.black)),
                                ),
                                ...availableMints.map((mint) => DropdownMenuItem(
                                  value: mint,
                                  child: Text(
                                    mint.replaceAll('_', ' ').toUpperCase(),
                                    style: const TextStyle(color: Colors.black),
                                  ),
                                )),
                              ],
                              onChanged: availableMints.isEmpty ? null : (value) {
                                setState(() => _selectedMint = value);
                                _load(reset: true);
                              },
                            ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _useSearch ? Icons.list : Icons.search,
                        size: 22,
                      ),
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
                
                const SizedBox(height: 10),
                
                // Sıralama ve filtreler
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sort,
                        decoration: InputDecoration(
                          labelText: 'Sırala',
                          labelStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87, // ✅ Label rengi
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.white, // ✅ Arka plan beyaz
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        dropdownColor: Colors.white, // ✅ Dropdown arka plan beyaz
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400, // ✅ w300'den w400'e
                          color: Colors.black, // ✅ Text rengi
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'uid_asc',
                            child: Text('UID ↑', style: TextStyle(color: Colors.black)),
                          ),
                          DropdownMenuItem(
                            value: 'uid_desc',
                            child: Text('UID ↓', style: TextStyle(color: Colors.black)),
                          ),
                          DropdownMenuItem(
                            value: 'updated_at_desc',
                            child: Text('Güncelleme ↓', style: TextStyle(color: Colors.black)),
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
                      label: const Text(
                        'Görselli',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      selected: _onlyImages,
                      avatar: Icon(
                        _onlyImages ? Icons.image : Icons.image_outlined,
                        size: 18,
                      ),
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
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off,
                              size: 56,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Sonuç bulunamadı',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Farklı filtreler deneyin',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w300,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => _load(reset: true),
                        child: ListView.separated(
                          controller: _scroll,
                          itemCount: _items.length + (_hasMore ? 1 : 0),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index >= _items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(12),
                                child: Center(child: CircularProgressIndicator()),
                              );
                            }
                            
                            final v = _items[index];
                            final thumbnailUrl = _thumbnailCache[v.articleId];
                            
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
                                v.title,
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
                                  '${RegionData.getRegionName(v.regionCode)} • ${v.material ?? '-'}',
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
                              onTap: () => context.go('/variant/${v.articleId}'),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/recognition'),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Scan Coin'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }
}