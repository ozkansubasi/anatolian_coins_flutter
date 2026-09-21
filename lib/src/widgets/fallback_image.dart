import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/num_colors.dart';

/// Görsel widget'ı - önce url'i dener, hata alırsa remoteUrl'e fallback yapar
class FallbackImage extends StatefulWidget {
  final String? url;
  final String? remoteUrl;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const FallbackImage({
    super.key,
    required this.url,
    this.remoteUrl,
    this.fit = BoxFit.contain,
    this.placeholder,
    this.errorWidget,
  });

  @override
  State<FallbackImage> createState() => _FallbackImageState();
}

class _FallbackImageState extends State<FallbackImage> {
  bool _primaryFailed = false;

  @override
  void didUpdateWidget(FallbackImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // URL değişirse state'i sıfırla
    if (oldWidget.url != widget.url || oldWidget.remoteUrl != widget.remoteUrl) {
      _primaryFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // URL yoksa placeholder göster
    if (widget.url == null || widget.url!.isEmpty) {
      if (widget.remoteUrl != null && widget.remoteUrl!.isNotEmpty) {
        return _buildImage(widget.remoteUrl!);
      }
      return widget.errorWidget ?? _buildDefaultError();
    }

    // Primary URL başarısız olduysa ve remote URL varsa onu göster
    if (_primaryFailed && widget.remoteUrl != null && widget.remoteUrl!.isNotEmpty) {
      return _buildImage(widget.remoteUrl!);
    }

    // Primary URL'i göster
    return _buildImage(widget.url!);
  }

  Widget _buildImage(String imageUrl) {
    debugPrint('🖼️ FallbackImage loading: $imageUrl');
    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: widget.fit,
      placeholder: (context, url) =>
          widget.placeholder ??
          Container(
            color: context.numColors.surface,
            child: const Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      errorWidget: (context, url, error) {
        debugPrint('❌ FallbackImage error for $url: $error');
        // Primary URL hata verdi, remote URL'i dene
        if (!_primaryFailed && widget.remoteUrl != null && widget.remoteUrl!.isNotEmpty) {
          debugPrint('🔄 FallbackImage trying remote URL: ${widget.remoteUrl}');
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _primaryFailed = true;
              });
            }
          });
        }
        return widget.errorWidget ?? _buildDefaultError();
      },
    );
  }

  Widget _buildDefaultError() {
    return Container(
      color: context.numColors.surface,
      child: Icon(
        Icons.broken_image,
        color: context.numColors.textMuted,
        size: 24,
      ),
    );
  }
}
