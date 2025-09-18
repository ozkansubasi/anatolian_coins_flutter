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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final api = ref.read(variantsApiProvider);
    try {
      final v = await api.getVariant(widget.articleId, includeImages: true);
      final imgs = await api.images(widget.articleId, wm: true, abs: false);
      setState(() { _variant = v; _images = imgs; });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Load error: $e')));
      }
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _variant;
    return Scaffold(
      appBar: AppBar(title: Text(v?.title ?? 'Variant ${widget.articleId}')),
      body: _loading ? const Center(child: CircularProgressIndicator())
        : Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (v != null) ...[
                Text(v.title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 4),
                Text('Region: ${v.regionCode ?? '-'} • Material: ${v.material ?? '-'}'),
                const SizedBox(height: 12),
              ],
              Expanded(
                child: _images.isEmpty
                  ? const Center(child: Text('No images'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, mainAxisSpacing: 8, crossAxisSpacing: 8),
                      itemCount: _images.length,
                      itemBuilder: (context, i) {
                        final img = _images[i];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: CachedNetworkImage(imageUrl: img.url, fit: BoxFit.cover),
                        );
                      },
                    ),
              ),
            ],
          ),
        ),
    );
  }
}
