import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';

import '../../core/image_cache.dart';
import '../../core/num_colors.dart';

/// Görseli çizen işlev; testlerde ağ yerine yer tutucu verilir.
typedef ArticleImageBuilder = Widget Function(String url, double width, String? alt);

/// Yazı içeriğindeki `<img>` öğelerini çizen flutter_html eklentisi (2026-11-24).
///
/// NEDEN: Sitedeki `{numistr_gorsel}` figürü (API `/v1/articles/{id}`) ön ve arka yüzü yan yana
/// `style="width:45%;max-width:230px"` ile verir. flutter_html 3.0.0 yüzdeyi paragraf
/// genişliğine göre çözmüyor, birimsiz değeri (45) olduğu gibi Image'e geçiriyor. Bu yüzden
/// uygulamada figür görselleri hiç görünmüyor, yalnız altyazı kalıyordu (TestFlight 0.6.4+32).
/// Yerleşik eklenti göreli `src`'leri de eşleştirmiyordu.
///
/// Genişlik ekran genişliğinden hesaplanır:
/// - figür sırasındaki (`.numistr-figur-sira`) görseller satırı eşit paylaşır, en fazla
///   [maxRowImageWidth];
/// - tek görsel içerik genişliğini kullanır.
/// Yükseklik görselin oranından gelir.
class ArticleImageExtension extends HtmlExtension {
  /// İçeriğin ekran kenarlarından toplam yatay boşluğu (sol + sağ).
  final double horizontalInset;
  final ArticleImageBuilder? imageBuilder;

  /// Site CSS'indeki `max-width:230px` ile aynı.
  static const double maxRowImageWidth = 230;
  static const double rowGap = 12;

  /// Görseller arasındaki HTML boşluğu (`</img> <img>`) satırda boşluk karakteri olarak kalır;
  /// hesaba katılmazsa ikinci görsel alt satıra düşer.
  static const double inlineSlack = 8;
  static const String rowClass = 'numistr-figur-sira';
  static final Uri siteBase = Uri.parse('https://www.numistr.org/');

  const ArticleImageExtension({required this.horizontalInset, this.imageBuilder});

  @override
  Set<String> get supportedTags => const {'img'};

  @override
  bool matches(ExtensionContext context) =>
      context.elementName == 'img' && resolveSrc(context.attributes['src']) != null;

  /// Göreli adres siteye göre çözülür; yalnız http(s) kabul edilir, SVG çizilemez.
  static String? resolveSrc(String? src) {
    final raw = src?.trim();
    if (raw == null || raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null) return null;
    final abs = uri.hasScheme ? uri : siteBase.resolveUri(uri);
    if (abs.scheme != 'http' && abs.scheme != 'https') return null;
    if (abs.path.toLowerCase().endsWith('.svg')) return null;
    return abs.toString();
  }

  /// Aynı satırdaki görsel sayısı ve içerik genişliğine göre bir görselin genişliği.
  static double imageWidth({required double contentWidth, required int perRow}) {
    final available = math.max(contentWidth, 80.0);
    if (perRow <= 1) return available;
    final share = (available - (rowGap + inlineSlack) * perRow) / perRow;
    return math.max(math.min(share, maxRowImageWidth), 40.0);
  }

  @override
  InlineSpan build(ExtensionContext context) {
    final src = resolveSrc(context.attributes['src'])!;
    final alt = context.attributes['alt'];
    final node = context.node;
    final parent = node.parent;
    final inRow = parent != null && parent.classes.contains(rowClass);
    final perRow = inRow ? parent.children.where((e) => e.localName == 'img').length : 1;

    final buildContext = context.buildContext;
    final screenWidth = buildContext != null ? MediaQuery.sizeOf(buildContext).width : 360.0;
    final width = imageWidth(contentWidth: screenWidth - horizontalInset, perRow: perRow);

    final image = (imageBuilder ?? _networkImage)(src, width, alt);
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Padding(
        padding: inRow
            ? const EdgeInsets.symmetric(horizontal: rowGap / 2, vertical: 4)
            : const EdgeInsets.symmetric(vertical: 12),
        child: Semantics(
          image: true,
          label: alt,
          child: SizedBox(width: width, child: image),
        ),
      ),
    );
  }

  static Widget _networkImage(String url, double width, String? alt) {
    return Builder(builder: (context) {
      final c = context.numColors;
      return CachedNetworkImage(
        cacheManager: NumistrImageCache.instance,
        imageUrl: url,
        width: width,
        fit: BoxFit.contain,
        placeholder: (_, __) => Container(
          width: width,
          height: width,
          color: c.surface,
          alignment: Alignment.center,
          child: const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          width: width,
          padding: const EdgeInsets.all(12),
          color: c.surface,
          child: Text(
            alt ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMuted, fontSize: 12),
          ),
        ),
      );
    });
  }
}
