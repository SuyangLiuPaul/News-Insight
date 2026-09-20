// Models for the yswords-data `daily_news.json` bundle.
//
// Ported from yswords (lib/models/news_article.dart, last present at
// commit 1155923^ before the in-app News feature was removed). Kept
// close to the original shape since the pipeline that produces this
// JSON (yswords-data's scripts/refresh-news.mjs) is unchanged.
//
// 2026-09-20, the owner: 「这个app里面所有ai评价和经文全部去掉 只看新闻
// 就够了」. The feed still carries an AI-picked `verse` and a `reflection`
// on every story; this model does not read them, so nothing downstream
// can show them. They used to be `NewsVerse` and `reflectionEn/Zh`.

class NewsArticle {
  /// `world` | `china` | `australia` (kept as String for forward-compat).
  final String section;
  final String id;
  final String source;
  final String sourceUrl;
  final String link;
  final String? image;
  final DateTime? publishedAt;
  final String titleEn;
  final String titleZh;
  final String summaryEn;
  final String summaryZh;

  /// Long-form article text for the in-app detail-page reader. Empty
  /// string when no body was extracted. zh is empty when no
  /// translation was produced (caller falls back to summary.zh).
  final String bodyEn;
  final String bodyZh;

  NewsArticle({
    required this.section,
    required this.id,
    required this.source,
    required this.sourceUrl,
    required this.link,
    required this.image,
    required this.publishedAt,
    required this.titleEn,
    required this.titleZh,
    required this.summaryEn,
    required this.summaryZh,
    required this.bodyEn,
    required this.bodyZh,
  });

  factory NewsArticle.fromJson(Map<String, dynamic> j) {
    final title = (j['title'] as Map?)?.cast<String, dynamic>() ?? const {};
    final summary =
        (j['summary'] as Map?)?.cast<String, dynamic>() ?? const {};
    final body = (j['body'] as Map?)?.cast<String, dynamic>() ?? const {};
    final pub = j['publishedAt'] as String?;
    final en = (title['en'] as String?) ?? '';
    return NewsArticle(
      section: (j['section'] as String?) ?? 'world',
      id: (j['id'] as String?) ?? '',
      source: (j['source'] as String?) ?? '',
      sourceUrl: (j['sourceUrl'] as String?) ?? '',
      link: (j['link'] as String?) ?? '',
      image: j['image'] as String?,
      publishedAt: pub != null ? DateTime.tryParse(pub) : null,
      titleEn: en,
      titleZh: (title['zh'] as String?) ?? en,
      summaryEn: (summary['en'] as String?) ?? '',
      summaryZh:
          (summary['zh'] as String?) ?? (summary['en'] as String?) ?? '',
      bodyEn: (body['en'] as String?) ?? '',
      bodyZh: (body['zh'] as String?) ?? '',
    );
  }

  String title(String locale) =>
      locale.startsWith('zh') && titleZh.isNotEmpty ? titleZh : titleEn;

  String summary(String locale) =>
      locale.startsWith('zh') && summaryZh.isNotEmpty ? summaryZh : summaryEn;

  /// Long-form body in the requested locale. Falls back to whichever
  /// side is populated; returns empty string when nothing exists so
  /// the detail page can hide the section cleanly.
  String body(String locale) {
    final wantZh = locale.startsWith('zh');
    if (wantZh && bodyZh.isNotEmpty) return bodyZh;
    if (!wantZh && bodyEn.isNotEmpty) return bodyEn;
    if (bodyZh.isNotEmpty) return bodyZh;
    return bodyEn;
  }
}

class NewsSection {
  final String id;
  final String titleEn;
  final String titleZh;
  final String labelEn;
  final String labelZh;
  final String strapEn;
  final String strapZh;
  final List<String> sourceNotes;
  final List<NewsArticle> items;

  NewsSection({
    required this.id,
    required this.titleEn,
    required this.titleZh,
    required this.labelEn,
    required this.labelZh,
    required this.strapEn,
    required this.strapZh,
    required this.sourceNotes,
    required this.items,
  });

  factory NewsSection.fromJson(Map<String, dynamic> j) {
    final title = (j['title'] as Map?)?.cast<String, dynamic>() ?? const {};
    final strap = (j['strap'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Short chip label (e.g. "World" / 全球). Added to the feed 2026-08-23;
    // older cached snapshots lack it, so fall back to the desk title.
    final label = (j['categoryLabel'] as Map?)?.cast<String, dynamic>() ?? const {};
    final items = (j['items'] as List?) ?? const [];
    return NewsSection(
      id: (j['id'] as String?) ?? '',
      titleEn: (title['en'] as String?) ?? '',
      titleZh: (title['zh'] as String?) ?? (title['en'] as String?) ?? '',
      labelEn: (label['en'] as String?) ?? '',
      labelZh: (label['zh'] as String?) ?? (label['en'] as String?) ?? '',
      strapEn: (strap['en'] as String?) ?? '',
      strapZh: (strap['zh'] as String?) ?? (strap['en'] as String?) ?? '',
      sourceNotes: ((j['sourceNotes'] as List?) ?? const []).cast<String>(),
      items: items
          .whereType<Map<String, dynamic>>()
          .map(NewsArticle.fromJson)
          .toList(),
    );
  }

  String title(String locale) =>
      locale.startsWith('zh') && titleZh.isNotEmpty ? titleZh : titleEn;

  /// Chip label for the section filter bar. Falls back to the desk
  /// title for pre-categoryLabel snapshots (this file stays import-free,
  /// so no ui_strings lookup here — the title is always present anyway).
  String label(String locale) {
    final fromFeed =
        locale.startsWith('zh') && labelZh.isNotEmpty ? labelZh : labelEn;
    return fromFeed.isNotEmpty ? fromFeed : title(locale);
  }
}

class DailyNewsBundle {
  final DateTime? generatedAt;
  final String editionDate;
  final List<NewsSection> sections;

  DailyNewsBundle({
    required this.generatedAt,
    required this.editionDate,
    required this.sections,
  });

  factory DailyNewsBundle.fromJson(Map<String, dynamic> j) {
    final gen = j['generatedAt'] as String?;
    final secs = (j['sections'] as Map?)?.cast<String, dynamic>() ?? const {};
    // Stable order matching the source pipeline's editorial priority.
    const order = [
      'world',
      'china',
      'hongkong',
      'australia',
      'science',
      'technology',
      'creation',
      'documentary',
    ];
    final list = <NewsSection>[];
    for (final id in order) {
      final raw = secs[id];
      if (raw is Map<String, dynamic>) {
        list.add(NewsSection.fromJson(raw));
      } else if (raw is Map) {
        list.add(NewsSection.fromJson(raw.cast<String, dynamic>()));
      }
    }
    // Append any unknown sections at the end.
    for (final entry in secs.entries) {
      if (order.contains(entry.key)) continue;
      final raw = entry.value;
      if (raw is Map) {
        list.add(NewsSection.fromJson(raw.cast<String, dynamic>()));
      }
    }
    return DailyNewsBundle(
      generatedAt: gen != null ? DateTime.tryParse(gen) : null,
      editionDate: (j['editionDate'] as String?) ?? '',
      sections: list,
    );
  }

  /// Flat list of every story across sections, preserving section
  /// order then per-section order.
  List<NewsArticle> get allArticles => [for (final s in sections) ...s.items];
}

/// Pure helper for infinite-scroll paging: given the articles already
/// on screen (live edition + any previously-appended archive pages)
/// and a freshly-fetched archive edition's articles, returns only the
/// ones not already present (by [NewsArticle.id]), in their original
/// order. Guards against the same story surviving into an older
/// day's cached top-up (RemoteDataService's cache/topUp logic can
/// carry a story across editions) showing up twice in the feed.
/// Exposed for testing.
List<NewsArticle> mergeUniqueArticles(
  List<NewsArticle> existing,
  List<NewsArticle> incoming,
) {
  final knownIds = existing.map((a) => a.id).toSet();
  final added = <NewsArticle>[];
  for (final article in incoming) {
    if (knownIds.add(article.id)) {
      added.add(article);
    }
  }
  return added;
}
