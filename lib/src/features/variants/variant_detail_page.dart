import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/variant.dart';
import '../../models/variant_image.dart';
import 'variants_api.dart';
import 'image_gallery_viewer.dart';
import '../../core/subscription_provider.dart';
import '../favorites/favorites_api.dart';
import '../offline/offline_service.dart';
import '../subscription/subscription_page.dart';

class VariantDetailPage extends ConsumerStatefulWidget {
  final int articleId;
  const VariantDetailPage({super.key, required this.articleId});

  @override
  ConsumerState<VariantDetailPage> createState() => _VariantDetailPageState();
}

class _VariantDetailPageState extends ConsumerState<VariantDetailPage> {
  Variant? _variant;
  List<VariantImage> _images = [];
  bool _loading = true;
  bool _isOfflineAvailable = false;

  // Bölge ismi mapping
  static const Map<String, String> _regionNames = {
    'pisidia-coins': 'Pisidya',
    'lydia-coins': 'Lidya',
    'ionia-coins': 'İonia',
    'caria-coins': 'Karya',
    'lycia-coins': 'Likya',
    'phrygia-coins': 'Frigya',
    'mysia-coins': 'Misia',
    'bithynia-coins': 'Bitinya',
    'pamphylia-coins': 'Pamfilya',
    'clicia-coins': 'Kilikya',
    'cappadocia-coins': 'Kapadokya',
    'galatia-coins': 'Galatya',
  };

  String _getRegionName(String? regionCode) {
    if (regionCode == null || regionCode.isEmpty) return '-';
    return _regionNames[regionCode] ?? regionCode;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    
    // Önce çevrimdışı kontrol et
    final offlineService = ref.read(offlineServiceProvider);
    final isOffline = await offlineService.isOfflineAvailable(widget.articleId);
    
    if (isOffline) {
      final offlineVariant = await offlineService.getOfflineVariant(widget.articleId);
      final offlineImages = await offlineService.getOfflineImages(widget.articleId);
      
      if (offlineVariant != null) {
        setState(() {
          _variant = offlineVariant;
          _images = offlineImages;
          _isOfflineAvailable = true;
          _loading = false;
        });
        return;
      }
    }
    
    // Online'dan çek - Pro üyelik kontrolü ile watermark
    final api = ref.read(variantsApiProvider);
    final subscription = ref.read(subscriptionProvider);
    
    try {
      final v = await api.getVariant(widget.articleId, includeImages: true);
      // Pro üyelik durumuna göre watermark ayarı
      final imgs = await api.images(widget.articleId, wm: !subscription.isPro, abs: false);
      setState(() {
        _variant = v;
        _images = imgs;
        _isOfflineAvailable = isOffline;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e')),
        );
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  void _showFeatureLockedDialog(String featureName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock, color: Colors.orange),
            SizedBox(width: 8),
            Text('Pro Özellik'),
          ],
        ),
        content: Text(
          '$featureName özelliği Pro üyelik ile kullanılabilir.\n\n'
          'Pro üyelik ile:\n'
          '• Sınırsız favori ekleme\n'
          '• Çevrimdışı erişim\n'
          '• Filigransız yüksek çözünürlük görseller\n'
          '• Sikke tanıma (AI)\n'
          '• Uzman desteği\n'
          '• Reklamsız deneyim',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Kapat'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SubscriptionPage()),
              );
            },
            child: const Text('Pro Satın Al'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFavoriteToggle() async {
    final subscription = ref.read(subscriptionProvider);
    
    if (!subscription.isPro) {
      final favorites = ref.read(favoritesControllerProvider);
      if (!favorites.contains(widget.articleId) && 
          favorites.length >= FeatureLimits.freeMaxFavorites) {
        _showFeatureLockedDialog('Sınırsız Favori');
        return;
      }
    }
    
    try {
      await ref.read(favoritesControllerProvider.notifier).toggleFavorite(widget.articleId);
      
      if (mounted) {
        final isFav = ref.read(favoritesControllerProvider).contains(widget.articleId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isFav ? 'Favorilere eklendi' : 'Favorilerden çıkarıldı'),
            duration: const Duration(seconds: 1),
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
  }

  Future<void> _handleOfflineToggle() async {
    final subscription = ref.read(subscriptionProvider);
    
    if (!subscription.isPro) {
      _showFeatureLockedDialog('Çevrimdışı Erişim');
      return;
    }

    if (_isOfflineAvailable) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Çevrimdışı Veriyi Sil'),
          content: const Text('Bu sikkenin çevrimdışı verisi silinecek. Devam edilsin mi?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sil'),
            ),
          ],
        ),
      );

      if (confirm == true) {
        try {
          await ref.read(offlineServiceProvider).deleteVariant(widget.articleId);
          setState(() => _isOfflineAvailable = false);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Çevrimdışı veri silindi')),
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
    } else {
      _showDownloadDialog();
    }
  }

  void _showDownloadDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => _DownloadProgressDialog(
        variantId: widget.articleId,
        onCompleted: () {
          setState(() => _isOfflineAvailable = true);
        },
      ),
    );
  }

  void _handleShare() {
    if (_variant == null) return;
    
    final text = 'NumisTR - ${_variant!.title}\n'
        'Bölge: ${_variant!.regionCode ?? '-'}\n'
        'Materyal: ${_variant!.material ?? '-'}\n'
        'https://www.numistr.org/sikke/${_variant!.slug}';
    
    Share.share(text, subject: _variant!.title);
  }

  Future<void> _openInMaps() async {
    if (_variant?.coordinates == null) return;
    
    try {
      final coords = _variant!.coordinates!.split(',');
      if (coords.length == 2) {
        final lat = coords[0].trim();
        final lng = coords[1].trim();
        final url = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        );
        
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Harita açılamadı: $e')),
        );
      }
    }
  }

  void _openGallery(int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ImageGalleryViewer(
          images: _images,
          initialIndex: initialIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _variant;
    final favorites = ref.watch(favoritesControllerProvider);
    final isFavorite = favorites.contains(widget.articleId);
    
    return Scaffold(
      appBar: AppBar(
        title: Text(v?.title ?? 'Sikke ${widget.articleId}'),
        actions: [
          IconButton(
            onPressed: _handleOfflineToggle,
            icon: Icon(
              _isOfflineAvailable ? Icons.offline_pin : Icons.offline_pin_outlined,
            ),
            tooltip: _isOfflineAvailable ? 'Çevrimdışı veri var' : 'Çevrimdışı indir (Pro)',
          ),
          IconButton(
            onPressed: _handleFavoriteToggle,
            icon: Icon(
              isFavorite ? Icons.favorite : Icons.favorite_border,
              color: isFavorite ? Colors.red : null,
            ),
            tooltip: isFavorite ? 'Favorilerden çıkar' : 'Favorilere ekle',
          ),
          IconButton(
            onPressed: _handleShare,
            icon: const Icon(Icons.share),
            tooltip: 'Paylaş',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12), // 16'dan 12'ye düşürüldü
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (v != null) ...[
                      Text(
                        v.title,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600, // bold → w600
                            ),
                      ),
                      const SizedBox(height: 12), // 16'dan 12'ye düşürüldü
                      
                      // Sikke Bilgileri (içinde açıklamalar ve darphane de var)
                      _buildInfoCard(v),
                      
                      // Görseller
                      if (_images.isNotEmpty) ...[
                        const SizedBox(height: 12), // 16'dan 12'ye düşürüldü
                        _buildImagesSection(),
                      ],
                      
                      // Koordinat
                      if (v.coordinates != null) ...[
                        const SizedBox(height: 12), // 16'dan 12'ye düşürüldü
                        _buildCoordinatesCard(v),
                      ],
                      
                      // Kaynak
                      if (v.sourceCitation != null) ...[
                        const SizedBox(height: 12), // 16'dan 12'ye düşürüldü
                        _buildSourceCard(v),
                      ],
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildInfoCard(Variant v) {
    final obverseText = v.obverseDescTr ?? v.obverseDesc;
    final reverseText = v.reverseDescTr ?? v.reverseDesc;
    final hasObverse = obverseText != null && obverseText.isNotEmpty;
    final hasReverse = reverseText != null && reverseText.isNotEmpty;
    final hasMeta = v.mintName != null || v.authorityName != null;
    final hasDescriptions = hasObverse || hasReverse;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12), // 16'dan 12'ye düşürüldü
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sikke Bilgileri',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, // bold → w600
                  ),
            ),
            const Divider(),
            const SizedBox(height: 6), // 8'den 6'ya düşürüldü
            
            // Temel bilgiler
            _buildInfoRow('UID', v.uid),
            _buildInfoRow('Bölge', _getRegionName(v.regionCode)),
            _buildInfoRow('Materyal', v.material ?? '-'),
            if (v.dateFrom != null || v.dateTo != null)
              _buildInfoRow(
                'Dönem',
                '${v.dateFrom ?? '?'} - ${v.dateTo ?? '?'}',
              ),
            if (v.denominationName != null && v.denominationName!.isNotEmpty)
              _buildInfoRow('Denominasyon', v.denominationName!),
            
            // Darphane bilgisi
            if (hasMeta) ...[
              const SizedBox(height: 8), // 12'den 8'e düşürüldü
              const Divider(),
              const SizedBox(height: 8), // 12'den 8'e düşürüldü
              if (v.authorityName != null && v.authorityName!.isNotEmpty)
                _buildInfoRow('Otorite', v.authorityName!),
              if (v.mintName != null && v.mintName!.isNotEmpty)
                _buildInfoRow('Darphane', v.mintName!),
            ],
            
            // Açıklamalar - en sonda
            if (hasDescriptions) ...[
              const SizedBox(height: 8), // 12'den 8'e düşürüldü
              const Divider(),
              const SizedBox(height: 8), // 12'den 8'e düşürüldü
              if (hasObverse) ...[
                const Text(
                  'Ön Yüz',
                  style: TextStyle(
                    fontWeight: FontWeight.w500, // w600 → w500
                    fontSize: 13, // 14'ten 13'e düşürüldü
                  ),
                ),
                const SizedBox(height: 4), // 6'dan 4'e düşürüldü
                Text(
                  obverseText!,
                  style: const TextStyle(
                    height: 1.4, // 1.5'ten 1.4'e
                    fontSize: 13, // 14'ten 13'e düşürüldü
                    fontWeight: FontWeight.w300, // ince font
                    color: Colors.black87,
                  ),
                ),
                if (hasReverse) const SizedBox(height: 8), // 12'den 8'e düşürüldü
              ],
              if (hasReverse) ...[
                const Text(
                  'Arka Yüz',
                  style: TextStyle(
                    fontWeight: FontWeight.w500, // w600 → w500
                    fontSize: 13, // 14'ten 13'e düşürüldü
                  ),
                ),
                const SizedBox(height: 4), // 6'dan 4'e düşürüldü
                Text(
                  reverseText!,
                  style: const TextStyle(
                    height: 1.4, // 1.5'ten 1.4'e
                    fontSize: 13, // 14'ten 13'e düşürüldü
                    fontWeight: FontWeight.w300, // ince font
                    color: Colors.black87,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3), // 4'ten 3'e düşürüldü
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110, // 120'den 110'a düşürüldü
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500, // w600 → w500
                fontSize: 13, // eklendi
                color: Colors.black87,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13, // eklendi
                fontWeight: FontWeight.w300, // ince font
                color: Colors.black54,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagesSection() {
    if (_images.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                Icon(Icons.image_not_supported, size: 48, color: Colors.grey),
                SizedBox(height: 8),
                Text('Görsel bulunamadı'),
              ],
            ),
          ),
        ),
      );
    }

    // Pro üyelik kontrolü
    final subscription = ref.watch(subscriptionProvider);
    final showWatermarkInfo = !subscription.isPro;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12), // 16'dan 12'ye düşürüldü
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // "(${_images.length} görsel)" kısmı kaldırıldı
                Text(
                  'Sikke Görselleri',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600, // bold → w600
                      ),
                ),
                // Pro kullanıcı değilse filigran bilgisi
                if (showWatermarkInfo)
                  InkWell(
                    onTap: () => _showFeatureLockedDialog('Filigransız Görseller'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.amber.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_border, size: 14, color: Colors.amber.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'Pro',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.amber.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 6), // 8'den 6'ya düşürüldü
            _buildImageGrid(),
          ],
        ),
      ),
    );
  }

  Widget _buildImageGrid() {
    final rows = <Widget>[];
    int i = 0;
    
    while (i < _images.length) {
      final currentImg = _images[i];
      final isDetailType = currentImg.type?.toLowerCase() == 'detay';
      
      if (isDetailType) {
        // Detay tipi: Tek görsel, tam satır
        rows.add(_buildImageRow([currentImg], showMetrics: true));
        i++;
      } else {
        // Normal tip: İki görsel yan yana (ön-arka)
        final nextImg = (i + 1 < _images.length) ? _images[i + 1] : null;
        if (nextImg != null && nextImg.type?.toLowerCase() != 'detay') {
          rows.add(_buildImageRow([currentImg, nextImg], showMetrics: true));
          i += 2;
        } else {
          rows.add(_buildImageRow([currentImg], showMetrics: true));
          i++;
        }
      }
    }
    
    return Column(
      children: rows.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 12), // 16'dan 12'ye düşürüldü
        child: row,
      )).toList(),
    );
  }

  Widget _buildImageRow(List<VariantImage> images, {required bool showMetrics}) {
    final isDetailType = images.first.type?.toLowerCase() == 'detay';
    final firstImage = images.first;
    final hasMetrics = showMetrics && 
        (firstImage.weight != null && firstImage.weight!.isNotEmpty) ||
        (firstImage.diameter != null && firstImage.diameter!.isNotEmpty);
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...images.map((img) {
          final index = _images.indexOf(img);
          final isFirstInRow = images.indexOf(img) == 0;
          
          return Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              elevation: 2,
              child: InkWell(
                onTap: () => _openGallery(index),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Hero(
                        tag: 'image_${img.imageId}',
                        child: CachedNetworkImage(
                          imageUrl: img.url,
                          fit: BoxFit.contain,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) {
                            // Hata varsa bu görseli listeden çıkar
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              setState(() {
                                _images.removeWhere((i) => i.imageId == img.imageId);
                              });
                            });
                            return const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                    // Metrics alanı - boş bile olsa yer tutsun (yükseklik eşitliği için)
                    Container(
                      padding: const EdgeInsets.all(6), // 8'den 6'ya düşürüldü
                      color: Colors.grey[100],
                      constraints: const BoxConstraints(minHeight: 42), // 48'den 42'ye düşürüldü
                      child: isFirstInRow && hasMetrics
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (firstImage.weight != null && firstImage.weight!.isNotEmpty)
                                  Text(
                                    '⚖️ ${firstImage.weight} g',
                                    style: const TextStyle(
                                      fontSize: 11, // 12'den 11'e düşürüldü
                                      fontWeight: FontWeight.w300, // ince font
                                    ),
                                  ),
                                if (firstImage.diameter != null && firstImage.diameter!.isNotEmpty)
                                  Text(
                                    '📏 ${firstImage.diameter} mm',
                                    style: const TextStyle(
                                      fontSize: 11, // 12'den 11'e düşürüldü
                                      fontWeight: FontWeight.w300, // ince font
                                    ),
                                  ),
                              ],
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (images.length == 1 && !isDetailType)
          const Expanded(child: SizedBox()),
      ],
    );
  }

  Widget _buildDescriptionsCard(Variant v) {
    // Türkçe yoksa İngilizce kullan
    final obverseText = v.obverseDescTr ?? v.obverseDesc;
    final reverseText = v.reverseDescTr ?? v.reverseDesc;
    
    final hasObverse = obverseText != null && obverseText.isNotEmpty;
    final hasReverse = reverseText != null && reverseText.isNotEmpty;
    
    if (!hasObverse && !hasReverse) return const SizedBox.shrink();
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12), // 16'dan 12'ye düşürüldü
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Açıklamalar',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, // bold → w600
                  ),
            ),
            const Divider(),
            const SizedBox(height: 8), // 12'den 8'e düşürüldü
            if (hasObverse) ...[
              const Row(
                children: [
                  Icon(Icons.circle, size: 12, color: Colors.blue),
                  SizedBox(width: 8),
                  Text(
                    'Ön Yüz',
                    style: TextStyle(
                      fontWeight: FontWeight.w500, // w600 → w500
                      color: Colors.blue,
                      fontSize: 15, // 16'dan 15'e düşürüldü
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6), // 8'den 6'ya düşürüldü
              Text(
                obverseText!,
                style: const TextStyle(
                  height: 1.4, // 1.5'ten 1.4'e
                  fontSize: 13, // 14'ten 13'e düşürüldü
                  fontWeight: FontWeight.w300, // ince font
                ),
              ),
              const SizedBox(height: 12), // 16'dan 12'ye düşürüldü
            ],
            if (hasReverse) ...[
              const Row(
                children: [
                  Icon(Icons.circle, size: 12, color: Colors.red),
                  SizedBox(width: 8),
                  Text(
                    'Arka Yüz',
                    style: TextStyle(
                      fontWeight: FontWeight.w500, // w600 → w500
                      color: Colors.red,
                      fontSize: 15, // 16'dan 15'e düşürüldü
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6), // 8'den 6'ya düşürüldü
              Text(
                reverseText!,
                style: const TextStyle(
                  height: 1.4, // 1.5'ten 1.4'e
                  fontSize: 13, // 14'ten 13'e düşürüldü
                  fontWeight: FontWeight.w300, // ince font
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetaCard(Variant v) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12), // 16'dan 12'ye düşürüldü
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Meta Bilgiler',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, // bold → w600
                  ),
            ),
            const Divider(),
            const SizedBox(height: 6), // 8'den 6'ya düşürüldü
            if (v.authorityName != null)
              _buildInfoRow('Otorite', v.authorityName!),
            if (v.mintName != null) _buildInfoRow('Darphane', v.mintName!),
            if (v.findspotName != null)
              _buildInfoRow('Buluntu Yeri', v.findspotName!),
          ],
        ),
      ),
    );
  }

  Widget _buildCoordinatesCard(Variant v) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12), // 16'dan 12'ye düşürüldü
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Konum',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, // bold → w600
                  ),
            ),
            const Divider(),
            const SizedBox(height: 6), // 8'den 6'ya düşürüldü
            Row(
              children: [
                const Icon(Icons.location_on, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    v.coordinates ?? '-',
                    style: const TextStyle(
                      fontSize: 13, // eklendi
                      fontWeight: FontWeight.w300, // ince font
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _openInMaps,
                  icon: const Icon(Icons.map),
                  tooltip: 'Haritada göster',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceCard(Variant v) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12), // 16'dan 12'ye düşürüldü
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Kaynak',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600, // bold → w600
                  ),
            ),
            const Divider(),
            const SizedBox(height: 6), // 8'den 6'ya düşürüldü
            Text(
              v.sourceCitation!,
              style: const TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13, // eklendi
                fontWeight: FontWeight.w300, // ince font
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// İndirme progress dialog'u
class _DownloadProgressDialog extends ConsumerStatefulWidget {
  final int variantId;
  final VoidCallback onCompleted;

  const _DownloadProgressDialog({
    required this.variantId,
    required this.onCompleted,
  });

  @override
  ConsumerState<_DownloadProgressDialog> createState() =>
      _DownloadProgressDialogState();
}

class _DownloadProgressDialogState
    extends ConsumerState<_DownloadProgressDialog> {
  @override
  void initState() {
    super.initState();
    _startDownload();
  }

  Future<void> _startDownload() async {
    try {
      await ref
          .read(offlineDownloadControllerProvider.notifier)
          .downloadVariant(widget.variantId);

      if (mounted) {
        widget.onCompleted();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İndirme tamamlandı!')),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('İndirme hatası: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final downloadState = ref.watch(offlineDownloadControllerProvider);
    final progress = downloadState[widget.variantId];

    return AlertDialog(
      title: const Text('Çevrimdışı İndiriliyor'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: progress?.progress ?? 0.0,
          ),
          const SizedBox(height: 16),
          if (progress != null) ...[
            Text(
              progress.status == DownloadStatus.downloading
                  ? 'Görsel ${progress.currentImage} / ${progress.totalImages}'
                  : progress.status.name,
            ),
            const SizedBox(height: 8),
            Text(
              '${(progress.progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ],
        ],
      ),
    );
  }
}