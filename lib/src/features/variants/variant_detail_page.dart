import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/variant.dart';
import '../../models/variant_image.dart';
import 'variants_api.dart';

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
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    
    final api = ref.read(variantsApiProvider);
    
    try {
      print('🔍 Loading variant ${widget.articleId}...');
      
      final v = await api.getVariant(widget.articleId, includeImages: true);
      print('✅ Variant loaded: ${v.title}');
      print('   Authority: ${v.authority}');
      print('   Mint: ${v.mint}');
      print('   Material: ${v.material}');
      print('   Obverse: ${v.obverseDesc}');
      print('   Reverse: ${v.reverseDesc}');
      
      final imgs = await api.images(widget.articleId, wm: true, abs: true);
      print('✅ Images loaded: ${imgs.length} items');
      
      if (mounted) {
        setState(() {
          _variant = v;
          _images = imgs;
          _loading = false;
        });
      }
    } catch (e, stackTrace) {
      print('❌ Error: $e');
      print('❌ Stack: $stackTrace');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _variant;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(v?.title ?? 'Loading...', style: const TextStyle(fontSize: 16)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                        const SizedBox(height: 12),
                        Text('Failed to load', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Görseller
                      if (_images.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sikke Örnekleri (Ön yüz - Arka yüz)',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              GridView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  mainAxisSpacing: 8,
                                  crossAxisSpacing: 8,
                                  childAspectRatio: 1,
                                ),
                                itemCount: _images.length,
                                itemBuilder: (context, i) {
                                  final img = _images[i];
                                  return GestureDetector(
                                    onTap: () => _showFullImage(context, img.url, i),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Stack(
                                          children: [
                                            CachedNetworkImage(
                                              imageUrl: img.url,
                                              fit: BoxFit.cover,
                                              width: double.infinity,
                                              height: double.infinity,
                                              placeholder: (context, url) => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              errorWidget: (context, url, error) => const Center(child: Icon(Icons.broken_image, size: 32)),
                                            ),
                                            if (img.weight != null)
                                              Positioned(
                                                bottom: 4,
                                                right: 4,
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                  decoration: BoxDecoration(
                                                    color: Colors.black54,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                  child: Text(
                                                    '${img.weight}g',
                                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),

                      // Bilgiler
                      if (v != null)
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Başlık
                              Text(v.title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                              const SizedBox(height: 12),
                              
                              // Sikke Bilgileri
                              _SectionTitle(title: 'Sikke Bilgileri'),
                              const SizedBox(height: 8),
                              
                              _CompactInfoCard(icon: Icons.qr_code, label: 'UID', value: v.uid),
                              _CompactInfoCard(icon: Icons.label, label: 'Sikke Adı', value: v.title),
                              
                              if (v.regionCode != null && v.regionCode!.isNotEmpty)
                                _CompactInfoCard(icon: Icons.map, label: 'Bölge', value: v.regionCode!),
                              
                              if (v.material != null && v.material!.isNotEmpty)
                                _CompactInfoCard(icon: Icons.science, label: 'Materyal', value: v.material!.toUpperCase()),
                              
                              const SizedBox(height: 12),
                              
                              // Meta
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).colorScheme.primaryContainer,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Icon(Icons.info_outline, size: 18, color: Theme.of(context).colorScheme.onPrimaryContainer),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Meta Bilgiler',
                                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                                color: Theme.of(context).colorScheme.onPrimaryContainer,
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    _MetaRow(label: 'UID', value: v.uid),
                                    if (v.updatedAt != null)
                                      _MetaRow(label: 'Güncelleme', value: v.updatedAt!.split(' ')[0]),
                                    _MetaRow(label: 'Görsel', value: '${_images.length}'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  void _showFullImage(BuildContext context, String url, int index) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: CachedNetworkImage(imageUrl: url, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 40,
              right: 12,
              child: IconButton.filledTonal(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
                iconSize: 24,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

class _CompactInfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CompactInfoCard({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DescCard extends StatelessWidget {
  final String title;
  final String desc;

  const _DescCard({required this.title, required this.desc});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
          ),
          const SizedBox(height: 4),
          Text(desc, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  final String label;
  final String value;

  const _MetaRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withOpacity(0.7),
                  fontSize: 11,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}