import 'package:flutter/material.dart';

import 'package:news_insight/models/news_article.dart';
import 'package:news_insight/theme/ui_strings.dart';
import 'package:news_insight/utils/book_name_localizer.dart';

/// The "Bible Lens" card — this app's actual differentiator: the
/// AI-picked verse plus the reflection connecting it to the story.
/// Deliberately the most visually prominent element on the detail
/// page (accent-tinted container, largest type after the headline).
class VerseLensCard extends StatelessWidget {
  const VerseLensCard({
    super.key,
    required this.article,
    required this.locale,
  });

  final NewsArticle article;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final verse = article.verse;
    if (verse.reference.isEmpty) return const SizedBox.shrink();
    final reflection = article.reflection(locale);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.auto_stories_outlined,
                  size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                uiStrings['bibleLens']?[locale] ?? 'Bible Lens',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 0.4,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '"${verse.text(locale)}"',
            style: const TextStyle(
              fontSize: 17,
              height: 1.5,
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '— ${localizeVerseReference(verse.reference, locale)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (verse.theme(locale).isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              children: [
                Chip(
                  label: Text(verse.theme(locale)),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ],
            ),
          ],
          if (reflection.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(color: scheme.primary.withValues(alpha: 0.2)),
            const SizedBox(height: 12),
            Text(
              uiStrings['reflection']?[locale] ?? 'Reflection',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              reflection,
              style: const TextStyle(fontSize: 14.5, height: 1.5),
            ),
          ],
        ],
      ),
    );
  }
}
