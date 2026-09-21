import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/num_colors.dart';
import '../../core/num_text.dart';
import '../../core/region_data.dart';
import '../../l10n/app_localizations.dart';
import '../../models/article.dart';
import '../../models/variant.dart';
import '../../models/variant_image.dart';
import '../../widgets/fallback_image.dart';
import '../variants/variants_api.dart';
import 'articles_api.dart';

/// Makale sonu modülleri: "İlgili Makaleler" ve "İlgili Sikkeler" (2026-09-21).
///
/// İlgili sikkeler için makale ile sikke arasında hazır bir bağ YOK; sinyal
/// başlıkta geçen bölge/darphane adıdır. Gövde metni bilerek taranmaz (bir
/// bölge makalesi komşu bölgelerin adını da geçirir → yanlış eşleşme). Başlıkta
/// net eşleşme yoksa modül hiç görünmez.

/// Başlıktan çıkarılan hedef: (bölge kodu, darphane kodu, görünen ad).
typedef CoinTarget = ({String region, String? mint, String name});

/// Bölge kodu → başlıkta aranacak ek yazımlar (TR ad ve kodun Latince kökü
/// otomatik eklenir).
const _regionAliases = <String, List<String>>{
  'pisidia-coins': ['pisidya'],
  'ionia-coins': ['iyonya', 'ionya'],
  'aeolis-coins': ['aiolis', 'eolis', 'aeolia'],
  'troas-coins': ['troad', 'troas'],
  'mysia-coins': ['misya'],
  'pamphylia-coins': ['pamfilya'],
  'cilicia-coins': ['kilikia'],
  'paphlagonia-coins': ['paflagonia'],
  'cappadocia-coins': ['kappadokya'],
  'galatia-coins': ['galatia'],
};

final _nonLetter = RegExp(r'[^a-zçğıöşüâîû]+');

Set<String> _words(String s) =>
    s.toLowerCase().split(_nonLetter).where((w) => w.isNotEmpty).toSet();

/// Başlıkta tam kelime olarak geçen ilk bölge; yoksa darphane (kök ≥ 5 harf).
CoinTarget? detectCoinTarget(String title) {
  final words = _words(title);
  for (final entry in RegionData.regionNames.entries) {
    final code = entry.key;
    if (code == 'other-ancient-regions-coins') continue;
    final names = {
      entry.value.toLowerCase(),
      code.replaceAll('-coins', ''),
      ...?_regionAliases[code],
    };
    if (names.any(words.contains)) {
      return (region: code, mint: null, name: entry.value);
    }
  }
  for (final code in RegionData.regionNames.keys) {
    for (final mint in RegionData.getMintsForRegion(code)) {
      final root = mint.split('_').first;
      if (root.length >= 5 && words.contains(root)) {
        final name = root[0].toUpperCase() + root.substring(1);
        return (region: code, mint: mint, name: name);
      }
    }
  }
  return null;
}

final relatedArticlesProvider =
    FutureProvider.autoDispose.family<List<Article>, (int, int)>((ref, key) async {
  final (categoryId, excludeId) = key;
  final list = await ref.read(articlesApiProvider).getArticles(categoryId: categoryId, limit: 8);
  return list.where((a) => a.id != excludeId).take(3).toList();
});

/// Görseli olan ilk 6 sikke (görsel çağrıları paralel).
final relatedCoinsProvider = FutureProvider.autoDispose
    .family<List<(Variant, VariantImage)>, CoinTarget>((ref, target) async {
  final api = ref.read(variantsApiProvider);
  final (list, _) = await api.list(
    region: target.region,
    mint: target.mint,
    hasImages: true,
    perPage: 12,
  );
  final withImages = await Future.wait(list.map((v) async {
    try {
      final imgs = await api.images(v.articleId, wm: true, abs: true);
      return imgs.isEmpty ? null : (v, imgs.first);
    } catch (_) {
      return null;
    }
  }));
  return withImages.whereType<(Variant, VariantImage)>().take(6).toList();
});

/// Makale detayının altına eklenen iki modül. Veri gelmezse ya da boşsa
/// ilgili bölüm hiç çizilmez (boş başlık bırakılmaz).
class ArticleRelatedSection extends ConsumerWidget {
  final Article article;
  const ArticleRelatedSection({super.key, required this.article});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final target = detectCoinTarget(article.title);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (target != null) _RelatedCoins(target: target),
        _RelatedArticles(article: article),
      ],
    );
  }
}

class _RelatedCoins extends ConsumerWidget {
  final CoinTarget target;
  const _RelatedCoins({required this.target});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = context.numText;
    final c = context.numColors;
    final coins = ref.watch(relatedCoinsProvider(target)).valueOrNull;
    if (coins == null || coins.isEmpty) return const SizedBox.shrink();

    final subtitle = l10n.translate(
      target.mint == null ? 'related_coins_region' : 'related_coins_mint',
      params: {'name': target.name},
    );
    final browse = Uri(path: '/browse', queryParameters: {
      'region': target.region,
      if (target.mint != null) 'mint': target.mint!,
    }).toString();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.translate('related_coins'), style: t.section),
                    const SizedBox(height: 2),
                    Text(subtitle, style: t.caption),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.go(browse),
                style: TextButton.styleFrom(foregroundColor: c.accent),
                child: Text(l10n.translate('see_all')),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 196,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: coins.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, i) {
                final (v, img) = coins[i];
                return _CoinCard(variant: v, image: img);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CoinCard extends StatelessWidget {
  final Variant variant;
  final VariantImage image;
  const _CoinCard({required this.variant, required this.image});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final t = context.numText;
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/variant/${variant.articleId}'),
        child: Container(
          width: 148,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fotoğraf plakası her temada beyaz (müze fotoğrafları beyaz fonlu).
              Container(
                height: 118,
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.all(6),
                child: FallbackImage(url: image.url, remoteUrl: image.remoteUrl, fit: BoxFit.contain),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Text(
                  variant.title,
                  style: t.label.copyWith(color: c.text, fontWeight: FontWeight.w600),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RelatedArticles extends ConsumerWidget {
  final Article article;
  const _RelatedArticles({required this.article});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final t = context.numText;
    final c = context.numColors;
    final items =
        ref.watch(relatedArticlesProvider((article.categoryId, article.id))).valueOrNull;
    if (items == null || items.isEmpty) return const SizedBox.shrink();
    final dateFormat = DateFormat.yMMMMd(l10n.locale.languageCode);

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('related_articles'), style: t.section),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: c.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              children: [
                for (var i = 0; i < items.length; i++)
                  InkWell(
                    onTap: () => context.push('/article/${items[i].id}'),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
                      decoration: BoxDecoration(
                        border: i == items.length - 1
                            ? null
                            : Border(bottom: BorderSide(color: c.divider)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(items[i].title,
                                    style: t.value, maxLines: 2, overflow: TextOverflow.ellipsis),
                                const SizedBox(height: 4),
                                Text(dateFormat.format(items[i].created), style: t.caption),
                              ],
                            ),
                          ),
                          Icon(Icons.chevron_right, color: c.hint),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
