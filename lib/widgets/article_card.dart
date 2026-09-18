import 'package:flutter/material.dart';

import 'package:news_insight/models/news_article.dart';
import 'package:news_insight/utils/book_name_localizer.dart';
import 'package:news_insight/utils/relative_time.dart';
import 'package:news_insight/widgets/retry_network_image.dart';

/// A single headline row in the feed list. Shows a thumbnail (or a
/// section-tinted gradient placeholder when no image is available —
/// same fallback the original in-app reader used, since RSS feeds
/// don't reliably carry photos), title, source + time-ago, and a
/// small chip teasing the paired Bible verse reference.
class ArticleCard extends StatelessWidget {
  const ArticleCard({
    super.key,
    required this.article,
    required this.locale,
    required this.selected,
    required this.onTap,
  });

  final NewsArticle article;
  final String locale;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      color: selected ? scheme.secondaryContainer.withValues(alpha: 0.5) : null,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Thumbnail(article: article),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      article.title(locale),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            article.source,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          ' · ${relativeTime(article.publishedAt, locale)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    if (article.verse.reference.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      _VerseChip(
                        reference: localizeVerseReference(
                            article.verse.reference, locale),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.article});
  final NewsArticle article;

  @override
  Widget build(BuildContext context) {
    const size = 72.0;
    final scheme = Theme.of(context).colorScheme;
    final image = article.image;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: size,
        height: size,
        child: image != null && image.isNotEmpty
            ? RetryNetworkImage(
                url: image,
                fit: BoxFit.cover,
                placeholderBuilder: (context) =>
                    _placeholder(article.section, scheme),
              )
            : _placeholder(article.section, scheme),
      ),
    );
  }

  Widget _placeholder(String section, ColorScheme scheme) {
    final hue = switch (section) {
      'china' => scheme.tertiary,
      'australia' => scheme.primary,
      _ => scheme.secondary,
    };
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [hue.withValues(alpha: 0.55), hue.withValues(alpha: 0.25)],
        ),
      ),
      child: Icon(Icons.public, color: scheme.surface, size: 26),
    );
  }
}

class _VerseChip extends StatelessWidget {
  const _VerseChip({required this.reference});
  final String reference;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories_outlined,
              size: 12, color: scheme.onPrimaryContainer),
          const SizedBox(width: 4),
          Text(
            reference,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}
