import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../l10n/app_localizations.dart';
import '../../models/article.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'articles_api.dart';

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
      backgroundColor: numScaffoldLight,
      body: FutureBuilder<Article>(
        future: ref.read(articlesApiProvider).getArticle(articleId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingView();
          }

          if (snapshot.hasError) {
            return _buildErrorView(l10n, snapshot.error.toString());
          }

          if (!snapshot.hasData) {
            return _buildErrorView(l10n, l10n.translate('error_loading_article'));
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

  Widget _buildErrorView(AppLocalizations l10n, String error) {
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
              Icon(Icons.error_outline, size: 64, color: Colors.grey.shade400),
              16.height,
              Text(l10n.translate('error'), style: boldTextStyle(size: 18)),
              8.height,
              Text(error, style: secondaryTextStyle(), textAlign: TextAlign.center),
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

    return CustomScrollView(
      slivers: [
        // Hero App Bar
        SliverAppBar(
          expandedHeight: 220,
          floating: false,
          pinned: true,
          backgroundColor: numPrimary,
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              icon: const Icon(Icons.share_rounded),
              onPressed: () => _shareArticle(context),
            ),
          ],
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeroBackground(),
          ),
        ),

        // Content
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -24),
            child: Container(
              decoration: const BoxDecoration(
                color: numScaffoldLight,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: numPrimary.withValues(alpha: 0.1),
                        borderRadius: radius(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_outlined, size: 14, color: numPrimary),
                          6.width,
                          Text(
                            article.category,
                            style: boldTextStyle(size: 12, color: numPrimary),
                          ),
                        ],
                      ),
                    ),
                    16.height,

                    // Title
                    Text(
                      article.title,
                      style: boldTextStyle(size: 18),
                    ),
                    16.height,

                    // Meta info
                    Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.calendar_today_outlined, size: 16, color: Colors.grey.shade500),
                            8.width,
                            Text(
                              dateFormat.format(article.created),
                              style: secondaryTextStyle(size: 14),
                            ),
                          ],
                        ),
                        // Removed update date as per user request
                      ],
                    ),
                    24.height,

                    // Divider
                    Container(
                      height: 3,
                      width: 60,
                      decoration: BoxDecoration(
                        gradient: numGoldGradient,
                        borderRadius: radius(2),
                      ),
                    ),
                    24.height,

                    // Intro (if available)
                    if (article.intro != null && article.intro!.isNotEmpty) ...[
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: boxDecorationWithRoundedCorners(
                          backgroundColor: numPrimary.withValues(alpha: 0.05),
                          borderRadius: radius(12),
                          border: Border(
                            left: BorderSide(color: numPrimary, width: 4),
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
                              color: numTextSecondary,
                              lineHeight: const LineHeight(1.6),
                              textAlign: TextAlign.justify,
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
                            fontSize: FontSize(15),
                            color: numTextPrimary,
                            lineHeight: const LineHeight(1.8),
                            textAlign: TextAlign.justify,
                          ),
                          'h1': Style(
                            fontSize: FontSize(24),
                            fontWeight: FontWeight.bold,
                            color: numTextPrimary,
                            margin: Margins.only(top: 24, bottom: 12),
                          ),
                          'h2': Style(
                            fontSize: FontSize(20),
                            fontWeight: FontWeight.bold,
                            color: numTextPrimary,
                            margin: Margins.only(top: 20, bottom: 10),
                          ),
                          'h3': Style(
                            fontSize: FontSize(18),
                            fontWeight: FontWeight.bold,
                            color: numTextPrimary,
                            margin: Margins.only(top: 16, bottom: 8),
                          ),
                          'p': Style(
                            margin: Margins.only(bottom: 16),
                          ),
                          'a': Style(
                            color: numPrimary,
                            textDecoration: TextDecoration.underline,
                          ),
                          'blockquote': Style(
                            backgroundColor: numBackgroundGrey,
                            padding: HtmlPaddings.all(16),
                            margin: Margins.symmetric(vertical: 16),
                            border: Border(
                              left: BorderSide(color: numPrimary, width: 4),
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
                            backgroundColor: Colors.white,
                            border: Border.all(color: numDividerColor),
                          ),
                          'th': Style(
                            backgroundColor: numBackgroundGrey,
                            padding: HtmlPaddings.all(12),
                            fontWeight: FontWeight.bold,
                          ),
                          'td': Style(
                            padding: HtmlPaddings.all(12),
                            border: Border.all(color: numDividerColor, width: 0.5),
                          ),
                        },
                      ),

                    40.height,

                    // Bottom action buttons
                    _buildBottomActions(context),

                    40.height,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: numGradientPrimary,
      ),
      child: Stack(
        children: [
          // Pattern
          Positioned(
            right: -40,
            top: -40,
            child: Icon(
              Icons.auto_stories,
              size: 200,
              color: Colors.white.withValues(alpha: 0.1),
            ),
          ),
          Positioned(
            left: -30,
            bottom: 40,
            child: Icon(
              Icons.article_outlined,
              size: 100,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          // Content area indicator
          Positioned(
            left: 20,
            right: 20,
            bottom: 40,
            child: Text(
              article.title,
              style: boldTextStyle(size: 18, color: Colors.white),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _shareArticle(context),
            icon: const Icon(Icons.share_rounded),
            label: Text(l10n.translate('share')),
            style: OutlinedButton.styleFrom(
              foregroundColor: numPrimary,
              side: BorderSide(color: numPrimary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: radius(12)),
            ),
          ),
        ),
        16.width,
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(l10n.translate('back')),
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: radius(12)),
            ),
          ),
        ),
      ],
    );
  }

  void _shareArticle(BuildContext context) {
    final shareText = '${article.title}\n\nhttps://numistr.org/blog/${article.id}';
    Share.share(shareText, subject: article.title);
  }
}
