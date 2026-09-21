import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/article.dart';
import '../../core/num_colors.dart';
import '../../core/num_text.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'articles_api.dart';
import 'article_related.dart';

/// ProKit styled Article Detail Screen
/// Features: Hero header, elegant typography, share functionality
class ProkitArticleDetailScreen extends ConsumerWidget {
  final int articleId;

  const ProkitArticleDetailScreen({
    super.key,
    required this.articleId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: FutureBuilder<Article>(
        future: ref.read(articlesApiProvider).getArticle(articleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingView();
          }

          if (snapshot.hasError) {
            return _buildErrorView(context, l10n, snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _buildErrorView(context, l10n, l10n.translate('error_loading_article'));
          }

          return _ArticleContent(
            article: snapshot.data!,
            l10n: l10n,
          );
        },
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(color: numPrimary),
    );
  }

  Widget _buildErrorView(BuildContext context, AppLocalizations l10n, String error) {
    final c = context.numColors;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: numPrimary,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: c.hint),
              16.height,
              Text(l10n.translate('error'), style: context.numText.section),
              8.height,
              Text(error, style: context.numText.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

/// Article Content Widget
class _ArticleContent extends StatelessWidget {
  final Article article;
  final AppLocalizations l10n;

  const _ArticleContent({
    required this.article,
    required this.l10n,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMMd(l10n.locale.languageCode);
    final c = context.numColors;

    final t = context.numText;
    return CustomScrollView(
      slivers: [
        // Kompakt üst çubuk: eski 220 px "hero" alanında yalnız dekoratif ikonlar
        // ve aşağıda zaten yazan başlığın kopyası vardı (gereksiz ekran kullanımı).
        SliverAppBar(
          pinned: true,
          backgroundColor: numPrimary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              tooltip: l10n.translate('share'),
              onPressed: () => _shareArticle(context),
            ),
          ],
        ),

        // Content
        SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Meta: solda tarih, sağa yaslı kategori (tek satır —
                    // kategori eskiden kendi satırını kaplıyordu).
                    Row(
                      children: [
                        Icon(Icons.calendar_today_outlined, size: 14, color: c.hint),
                        6.width,
                        Text(dateFormat.format(article.created), style: t.caption),
                        const Spacer(),
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: c.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.folder_outlined, size: 13, color: c.accent),
                                5.width,
                                Flexible(
                                  child: Text(
                                    article.category,
                                    style: t.tag.copyWith(letterSpacing: 0.2),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    14.height,

                    // Title
                    Text(article.title, style: t.display),
                    16.height,

                    // Divider
                    Container(
                      height: 3,
                      width: 48,
                      decoration: BoxDecoration(
                        gradient: numGoldGradient,
                        borderRadius: radius(2),
                      ),
                    ),
                    20.height,

                    // Intro (if available)
                    if (article.intro != null && article.intro!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: boxDecorationWithRoundedCorners(
                          backgroundColor: c.accent.withValues(alpha: 0.06),
                          borderRadius: radius(12),
                          border: Border(
                            left: BorderSide(color: c.accent, width: 3),
                          ),
                        ),
                        child: Html(
                          data: article.intro!,
                          style: {
                            'body': Style(
                              margin: Margins.zero,
                              padding: HtmlPaddings.zero,
                              fontSize: FontSize(15),
                              fontStyle: FontStyle.italic,
                              color: c.textMuted,
                              lineHeight: const LineHeight(1.6),
                              textAlign: TextAlign.start,
                            ),
                            'p': Style(
                              margin: Margins.zero,
                            ),
                          },
                        ),
                      ),
                      24.height,
                    ],

                    // Content
                    if (article.content != null && article.content!.isNotEmpty)
                      Html(
                        data: article.content!,
                        style: {
                          'body': Style(
                            margin: Margins.zero,
                            padding: HtmlPaddings.zero,
                            fontSize: FontSize(16),
                            color: c.text,
                            lineHeight: const LineHeight(1.7),
                            textAlign: TextAlign.start,
                          ),
                          'h1': Style(
                            fontSize: FontSize(24),
                            fontWeight: FontWeight.bold,
                            color: c.text,
                            margin: Margins.only(top: 24, bottom: 12),
                          ),
                          'h2': Style(
                            fontSize: FontSize(20),
                            fontWeight: FontWeight.bold,
                            color: c.text,
                            margin: Margins.only(top: 20, bottom: 10),
                          ),
                          'h3': Style(
                            fontSize: FontSize(16),
                            fontWeight: FontWeight.bold,
                            color: c.text,
                            margin: Margins.only(top: 16, bottom: 8),
                          ),
                          'p': Style(
                            margin: Margins.only(bottom: 16),
                          ),
                          'a': Style(
                            color: c.accent,
                            textDecoration: TextDecoration.underline,
                          ),
                          'blockquote': Style(
                            backgroundColor: c.surface,
                            padding: HtmlPaddings.all(16),
                            margin: Margins.symmetric(vertical: 16),
                            border: Border(
                              left: BorderSide(color: c.accent, width: 3),
                            ),
                            fontStyle: FontStyle.italic,
                          ),
                          'ul': Style(
                            padding: HtmlPaddings.only(left: 20),
                          ),
                          'ol': Style(
                            padding: HtmlPaddings.only(left: 20),
                          ),
                          'li': Style(
                            margin: Margins.only(bottom: 8),
                          ),
                          'img': Style(
                            margin: Margins.symmetric(vertical: 16),
                          ),
                          'table': Style(
                            backgroundColor: c.card,
                            border: Border.all(color: c.divider),
                          ),
                          'th': Style(
                            backgroundColor: c.surface,
                            padding: HtmlPaddings.all(12),
                            fontWeight: FontWeight.bold,
                          ),
                          'td': Style(
                            padding: HtmlPaddings.all(12),
                            border: Border.all(color: c.divider, width: 0.5),
                          ),
                        },
                      ),

                    32.height,

                    // İlgili sikkeler (başlıkta bölge/darphane varsa) + ilgili makaleler
                    ArticleRelatedSection(article: article),

                    // Bottom action buttons
                    _buildBottomActions(context),

                    40.height,
                  ],
                ),
              ),
        ),
      ],
    );
  }

  /// Tek eylem: paylaş. Eski "Geri" düğmesi üst çubuktaki geri okunu tekrar ediyordu.
  Widget _buildBottomActions(BuildContext context) {
    final c = context.numColors;
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () => _shareArticle(context),
        icon: const Icon(Icons.share_rounded),
        label: Text(l10n.translate('share')),
        style: OutlinedButton.styleFrom(
          foregroundColor: c.accent,
          side: BorderSide(color: c.accent),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: radius(12)),
        ),
      ),
    );
  }

  void _shareArticle(BuildContext context) {
    final shareText = '${article.title}\n\nhttps://numistr.org/blog/${article.id}';
    Share.share(shareText, subject: article.title);
  }
}
