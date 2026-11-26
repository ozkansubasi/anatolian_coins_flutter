import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/num_colors.dart';
import '../../core/num_text.dart';
import '../../l10n/app_localizations.dart';
import '../../models/article.dart';

/// "Videoda izleyin" (API 1.30.0, BACKLOG 12b V1): yazının ya da yerleşim sayfasının YouTube videoları.
///
/// Uygulama videoyu gömmez (gömülü oynatıcı yeni yerel bağımlılık + mağaza incelemesi demek):
/// kart sitenin sunduğu küçük resmi gösterir, dokununca video YouTube'da açılır.
/// Künye (CC BY atfı) kartın altındaki "Künye" düğmesiyle tam metin görünür.
class ArticleVideosSection extends StatelessWidget {
  final List<ArticleVideo> videos;

  const ArticleVideosSection({super.key, required this.videos});

  @override
  Widget build(BuildContext context) {
    if (videos.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final t = context.numText;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.translate('article_videos_title'), style: t.section),
          const SizedBox(height: 12),
          for (final v in videos) ...[
            ArticleVideoCard(video: v),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class ArticleVideoCard extends StatelessWidget {
  final ArticleVideo video;

  const ArticleVideoCard({super.key, required this.video});

  Future<void> _open(BuildContext context) async {
    final uri = Uri.parse(video.watchUrl);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).translate('article_video_open_error'))),
      );
    }
  }

  void _showCredit(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.translate('article_video_credit'), style: ctx.numText.section),
              const SizedBox(height: 12),
              SelectableText(video.credit, style: ctx.numText.body),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final c = context.numColors;
    final t = context.numText;
    // Shorts dikey küçük resim (9:16), video yatay (16:9); ikisi de satırın solunda sabit boyda.
    final w = video.isShorts ? 96.0 : 160.0;
    final h = video.isShorts ? 170.0 : 90.0;
    final title = video.title.isNotEmpty ? video.title : l10n.translate('article_video_watch');

    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _open(context),
        child: Semantics(
          button: true,
          label: '${l10n.translate('article_video_watch')}: $title',
          excludeSemantics: true,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: w,
                    height: h,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (video.thumbnailUrl != null)
                          CachedNetworkImage(
                            imageUrl: video.thumbnailUrl!,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => ColoredBox(color: c.surface),
                            placeholder: (_, __) => ColoredBox(color: c.surface),
                          )
                        else
                          ColoredBox(color: c.surface),
                        const Center(
                          child: DecoratedBox(
                            decoration: BoxDecoration(color: Color(0xCC2B2418), shape: BoxShape.circle),
                            child: Padding(
                              padding: EdgeInsets.all(8),
                              child: Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
                            ),
                          ),
                        ),
                        if (video.durationLabel != null)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.72),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                child: Text(video.durationLabel!, style: t.caption.copyWith(color: Colors.white)),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: t.value, maxLines: 4, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 16, color: c.accent),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(l10n.translate('article_video_watch'),
                                style: t.label.copyWith(color: c.accent)),
                          ),
                        ],
                      ),
                      if (video.credit.isNotEmpty)
                        TextButton(
                          onPressed: () => _showCredit(context),
                          style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 36),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: c.textMuted,
                          ),
                          child: Text(l10n.translate('article_video_credit'), style: t.caption),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
