import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/app_localizations.dart';
import '../../models/article_category.dart';
import 'articles_api.dart';

/// Blog Categories List Widget - Shows blog categories as chips
class BlogCategoriesList extends ConsumerWidget {
  const BlogCategoriesList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context);

    return FutureBuilder<List<ArticleCategory>>(
      future: ref.read(articlesApiProvider).getCategories(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _LoadingView(l10n: l10n, theme: theme);
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink(); // Hide if error or empty
        }

        final categories = snapshot.data!;
        return _CategoriesWidget(
          categories: categories,
          l10n: l10n,
          theme: theme,
        );
      },
    );
  }
}

/// Categories Widget
class _CategoriesWidget extends StatelessWidget {
  final List<ArticleCategory> categories;
  final AppLocalizations l10n;
  final ThemeData theme;

  const _CategoriesWidget({
    required this.categories,
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header
        Row(
          children: [
            Icon(
              Icons.folder_outlined,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              l10n.translate('blog_categories'),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Categories Chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            return _CategoryChip(
              category: category,
              theme: theme,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Category Chip Widget
class _CategoryChip extends StatelessWidget {
  final ArticleCategory category;
  final ThemeData theme;

  const _CategoryChip({
    required this.category,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(
        Icons.article_outlined,
        size: 18,
        color: theme.colorScheme.primary,
      ),
      label: Text(category.name),
      backgroundColor: theme.colorScheme.primaryContainer.withOpacity(0.5),
      labelStyle: TextStyle(
        color: theme.colorScheme.onPrimaryContainer,
        fontWeight: FontWeight.w500,
      ),
      side: BorderSide(
        color: theme.colorScheme.primary.withOpacity(0.3),
        width: 1,
      ),
      onPressed: () {
        // TODO: Navigate to category articles list
        // This can be implemented in a future version
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${category.name} - Coming Soon'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      },
    );
  }
}

/// Loading View
class _LoadingView extends StatelessWidget {
  final AppLocalizations l10n;
  final ThemeData theme;

  const _LoadingView({
    required this.l10n,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 120,
              height: 20,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(4, (index) {
            return Container(
              width: 80 + (index * 10.0),
              height: 32,
              decoration: BoxDecoration(
                color: theme.colorScheme.outline.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
            );
          }),
        ),
      ],
    );
  }
}
