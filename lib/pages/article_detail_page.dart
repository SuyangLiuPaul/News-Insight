import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:news_insight/models/news_article.dart';
import 'package:news_insight/theme/ui_strings.dart';
import 'package:news_insight/utils/relative_time.dart';
import 'package:news_insight/widgets/retry_network_image.dart';

/// Full article view. Used both as a pushed route (narrow screens)
/// and embedded directly as the right-hand pane of the feed's
/// master-detail layout (wide screens) — [embedded] controls whether
/// it renders its own Scaffold/AppBar or assumes the caller already
/// provides page chrome.
class ArticleDetailPage extends StatelessWidget {
  const ArticleDetailPage({
    super.key,
    required this.article,
    required this.locale,
    this.embedded = false,
  });

  final NewsArticle article;
  final String locale;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final content = _DetailBody(article: article, locale: locale);
    if (embedded) return content;
    return Scaffold(
      appBar: AppBar(title: const SizedBox.shrink()),
      body: content,
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.article, required this.locale});
  final NewsArticle article;
  final String locale;

  Future<void> _openOriginal() async {
    final uri = Uri.tryParse(article.link);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final body = article.body(locale);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (article.image != null && article.image!.isNotEmpty)
          // 2026-08-06: this was a bare AspectRatio(16/9), which on a
          // wide detail pane meant the hero grew with the column — at
          // 1000px it was 560px tall and pushed the headline off the
          // bottom of the window. The photo is
          // context, not the content. 16:9 still holds on narrow
          // screens; past ~570px wide it stops growing and crops
          // instead, which BoxFit.cover already handles.
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: LayoutBuilder(
              builder: (context, c) => SizedBox(
                width: double.infinity,
                height: math.min(c.maxWidth * 9 / 16, 320),
                child: RetryNetworkImage(
                  url: article.image!,
                  fit: BoxFit.cover,
                  placeholderBuilder: (context) => DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          scheme.secondary.withValues(alpha: 0.4),
                          scheme.secondary.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                    child: Icon(Icons.public, color: scheme.surface, size: 40),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          article.title(locale),
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          children: [
            Text(
              article.source,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            Text(
              '· ${relativeTime(article.publishedAt, locale)}',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: _openOriginal,
          icon: const Icon(Icons.open_in_new, size: 16),
          label: Text(uiStrings['readOriginal']?[locale] ?? 'Read original'),
        ),
        if (body.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(body, style: const TextStyle(fontSize: 15.5, height: 1.6)),
        ] else ...[
          const SizedBox(height: 24),
          Text(
            article.summary(locale),
            style: const TextStyle(fontSize: 15.5, height: 1.6),
          ),
        ],
      ],
    );
  }
}
