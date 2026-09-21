import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../models/article.dart';
import '../../models/article_category.dart';
import '../../core/num_colors.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'articles_api.dart';

/// ProKit styled Blog List Screen
/// Features: Category filter chips, featured article, article cards
class ProkitBlogListScreen extends ConsumerStatefulWidget {
  const ProkitBlogListScreen({super.key});

  @override
  ConsumerState<ProkitBlogListScreen> createState() => _ProkitBlogListScreenState();
}

class _ProkitBlogListScreenState extends ConsumerState<ProkitBlogListScreen> {
  int? _selectedCategoryId;
  List<ArticleCategory> _categories = [];
  List<Article> _articles = [];
  Article? _featuredArticle;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(articlesApiProvider);

      // Load in parallel
      final results = await Future.wait([
        api.getCategories(),
        api.getArticles(categoryId: _selectedCategoryId),
        api.getFeaturedArticle().then<Article?>((a) => a).catchError((_) => null),
      ]);

      setState(() {
        _categories = results[0] as List<ArticleCategory>;
        _articles = results[1] as List<Article>;
        _featuredArticle = results[2] as Article?;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _onCategorySelected(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    _loadArticles();
  }

  Future<void> _loadArticles() async {
    try {
      final api = ref.read(articlesApiProvider);
      final articles = await api.getArticles(categoryId: _selectedCategoryId);
      setState(() => _articles = articles);
    } catch (e) {
      // Keep existing articles on error
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          _buildAppBar(l10n),
        ],
        body: _isLoading
            ? _buildLoadingView()
            : _error != null
                ? _buildErrorView(l10n)
                : _buildContent(l10n),
      ),
    );
  }

  Widget _buildAppBar(AppLocalizations l10n) {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: numPrimary,
      foregroundColor: Colors.white,
      // Açık temada AppBar teması geri okunu koyu griye çekiyordu; fotoğraf
      // üstünde seçilmiyordu (cihazda görüldü).
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          l10n.translate('blog'),
          style: boldTextStyle(size: 20, color: Colors.white),
        ),
        // Zemin: Sagalassos (Pisidya) — Keşfet'teki bölge başlıklarıyla aynı
        // görsel dili (2026-09-21 kullanıcı isteği). Alttan koyulaşan gradyan
        // beyaz başlığın fotoğraf üstünde okunmasını sağlar.
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset(
              'assets/images/regions/pisidia_banner.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(0.3, 0),
              errorBuilder: (_, __, ___) =>
                  const DecoratedBox(decoration: BoxDecoration(gradient: numGradientPrimary)),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.15),
                    Colors.black.withValues(alpha: 0.55),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: CircularProgressIndicator(color: numPrimary),
    );
  }

  Widget _buildErrorView(AppLocalizations l10n) {
    final c = context.numColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: c.hint),
            16.height,
            Text(
              l10n.translate('error'),
              style: boldTextStyle(size: 18, color: c.text),
            ),
            8.height,
            Text(
              _error ?? '',
              style: secondaryTextStyle(color: c.textMuted),
              textAlign: TextAlign.center,
            ),
            24.height,
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.translate('retry')),
              style: ElevatedButton.styleFrom(
                backgroundColor: numPrimary,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations l10n) {
    final c = context.numColors;
    return RefreshIndicator(
      onRefresh: _loadData,
      color: numPrimary,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Category Filter Chips
            if (_categories.isNotEmpty) ...[
              _buildCategoryChips(l10n),
              20.height,
            ],

            // Featured Article
            if (_featuredArticle != null && _selectedCategoryId == null) ...[
              _buildFeaturedArticle(l10n),
              24.height,
            ],

            // Articles Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategoryId != null
                      ? _categories.firstWhere((c) => c.id == _selectedCategoryId).name
                      : l10n.translate('latest_articles'),
                  style: boldTextStyle(size: 18, color: c.text),
                ),
                Text(
                  '${_articles.length} ${l10n.translate('articles')}',
                  style: secondaryTextStyle(color: c.textMuted),
                ),
              ],
            ),
            16.height,

            // Article Cards
            if (_articles.isEmpty)
              _buildEmptyView(l10n)
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _articles.length,
                separatorBuilder: (_, __) => 16.height,
                itemBuilder: (context, index) => _ArticleCard(
                  article: _articles[index],
                  l10n: l10n,
                  onTap: () => context.push('/article/${_articles[index].id}'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips(AppLocalizations l10n) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          // "All" chip
          _CategoryChip(
            label: l10n.translate('all'),
            isSelected: _selectedCategoryId == null,
            onTap: () => _onCategorySelected(null),
          ),
          8.width,
          // Category chips
          ..._categories.map((cat) => Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CategoryChip(
              label: cat.name,
              isSelected: _selectedCategoryId == cat.id,
              onTap: () => _onCategorySelected(cat.id),
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildFeaturedArticle(AppLocalizations l10n) {
    final article = _featuredArticle!;
    final dateFormat = DateFormat.yMMMd(l10n.locale.languageCode);

    return GestureDetector(
      onTap: () => context.push('/article/${article.id}'),
      child: Container(
        width: double.infinity,
        decoration: boxDecorationWithRoundedCorners(
          borderRadius: radius(16),
          gradient: numGoldGradient,
          boxShadow: [
            BoxShadow(
              color: numPrimary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              right: -20,
              top: -20,
              child: Icon(
                Icons.auto_stories,
                size: 120,
                color: Colors.white.withValues(alpha: 0.15),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: boxDecorationWithRoundedCorners(
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      borderRadius: radius(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star, size: 14, color: Colors.white),
                        4.width,
                        Text(
                          l10n.translate('featured'),
                          style: boldTextStyle(size: 12, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                  16.height,
                  // Title
                  Text(
                    article.title,
                    style: boldTextStyle(size: 20, color: Colors.white),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  8.height,
                  // Intro
                  if (article.intro != null)
                    Text(
                      _stripHtml(article.intro!),
                      style: primaryTextStyle(size: 14, color: Colors.white.withValues(alpha: 0.9)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  12.height,
                  // Footer
                  Row(
                    children: [
                      Icon(Icons.folder_outlined, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                      4.width,
                      Text(
                        article.category,
                        style: secondaryTextStyle(size: 12, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      16.width,
                      Icon(Icons.calendar_today, size: 14, color: Colors.white.withValues(alpha: 0.8)),
                      4.width,
                      Text(
                        dateFormat.format(article.created),
                        style: secondaryTextStyle(size: 12, color: Colors.white.withValues(alpha: 0.8)),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.arrow_forward, size: 16, color: Colors.white),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView(AppLocalizations l10n) {
    final c = context.numColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.article_outlined, size: 64, color: c.hint),
            16.height,
            Text(
              l10n.translate('no_articles'),
              style: secondaryTextStyle(size: 16, color: c.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}

/// Category Filter Chip
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: boxDecorationWithRoundedCorners(
          backgroundColor: isSelected ? numPrimary : c.card,
          borderRadius: radius(20),
          border: Border.all(
            color: isSelected ? numPrimary : c.border,
          ),
          boxShadow: isSelected
              ? [BoxShadow(color: numPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: boldTextStyle(
            size: 14,
            color: isSelected ? Colors.white : c.textMuted,
          ),
        ),
      ),
    );
  }
}

/// Article Card Widget
class _ArticleCard extends StatelessWidget {
  final Article article;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  const _ArticleCard({
    required this.article,
    required this.l10n,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat.yMMMd(l10n.locale.languageCode);
    final c = context.numColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: boxDecorationWithRoundedCorners(
          backgroundColor: c.card,
          borderRadius: radius(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category & Date Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: boxDecorationWithRoundedCorners(
                      backgroundColor: numPrimary.withValues(alpha: 0.1),
                      borderRadius: radius(12),
                    ),
                    child: Text(
                      article.category,
                      style: boldTextStyle(size: 12, color: c.accent),
                    ),
                  ),
                  const Spacer(),
                  Icon(Icons.access_time, size: 14, color: c.hint),
                  4.width,
                  Text(
                    dateFormat.format(article.created),
                    style: secondaryTextStyle(size: 12, color: c.textMuted),
                  ),
                ],
              ),
              12.height,
              // Title
              Text(
                article.title,
                style: boldTextStyle(size: 16, color: c.text),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              // Intro
              if (article.intro != null) ...[
                8.height,
                Text(
                  _stripHtml(article.intro!),
                  style: secondaryTextStyle(size: 14, color: c.textMuted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              12.height,
              // Read more
              Row(
                children: [
                  Text(
                    l10n.translate('read_more'),
                    style: boldTextStyle(size: 14, color: c.accent),
                  ),
                  4.width,
                  Icon(Icons.arrow_forward_ios, size: 12, color: c.accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _stripHtml(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), '').trim();
  }
}
