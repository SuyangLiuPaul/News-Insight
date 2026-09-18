// Smoke tests for the daily-news JSON deserializer. Catches schema
// drift between the upstream pipeline (yswords-data) and this app's
// model. Ported from yswords (test/news_article_test.dart, last
// present at commit 1155923^).
//
// Run with: `flutter test test/news_article_test.dart`

import 'package:flutter_test/flutter_test.dart';
import 'package:news_insight/models/news_article.dart';

void main() {
  group('NewsArticle.fromJson', () {
    test('parses a complete article', () {
      final a = NewsArticle.fromJson({
        'id': 'abc123',
        'section': 'world',
        'source': 'The Guardian',
        'sourceUrl': 'https://www.theguardian.com',
        'link': 'https://www.theguardian.com/world/2026/04/article',
        'image': 'https://example.com/img.jpg',
        'publishedAt': '2026-04-21T06:41:46.986Z',
        'title': {'en': 'English title', 'zh': '中文标题'},
        'summary': {'en': 'English summary', 'zh': '中文摘要'},
        'reflection': {'en': 'Reflection', 'zh': '反思'},
        'verse': {
          'reference': 'Philippians 4:8',
          'textEn': 'Whatever is true...',
          'textZh': '凡是真實的...',
          'themeEn': 'Discernment',
          'themeZh': '辨識',
        },
      });

      expect(a.id, 'abc123');
      expect(a.section, 'world');
      expect(a.title('en'), 'English title');
      expect(a.title('zh'), '中文标题');
      expect(a.summary('zh'), '中文摘要');
      expect(a.verse.reference, 'Philippians 4:8');
      expect(a.verse.theme('zh'), '辨識');
      expect(a.publishedAt!.toUtc().year, 2026);
    });

    test('falls back to English when zh is null', () {
      final a = NewsArticle.fromJson({
        'id': 'x',
        'section': 'world',
        'source': '',
        'sourceUrl': '',
        'link': '',
        'image': null,
        'publishedAt': null,
        'title': {'en': 'Only English', 'zh': null},
        'summary': {'en': 'Only English summary'},
        'reflection': {'en': 'Only English reflection'},
        'verse': {
          'reference': 'Genesis 1:1',
          'textEn': 'In the beginning…',
          'textZh': '',
          'themeEn': 'Creation',
          'themeZh': '',
        },
      });

      expect(a.title('zh'), 'Only English');
      expect(a.summary('zh'), 'Only English summary');
      expect(a.verse.text('zh'), 'In the beginning…');
      expect(a.verse.theme('zh'), 'Creation');
      expect(a.image, isNull);
      expect(a.publishedAt, isNull);
    });

    test('survives a malformed JSON without throwing', () {
      // Defensive: missing top-level fields and wrong types should
      // produce a populated-with-defaults article rather than a
      // crash. The Flutter UI then renders empty strings rather than
      // a red error screen.
      final a = NewsArticle.fromJson({});
      expect(a.id, '');
      expect(a.section, 'world');
      expect(a.titleEn, '');
      expect(a.publishedAt, isNull);
      expect(a.verse.reference, '');
    });

    test('body() falls back to whichever side has content', () {
      final a = NewsArticle.fromJson({
        'id': 'x',
        'section': 'world',
        'body': {'en': 'English body', 'zh': ''},
      });
      expect(a.body('en'), 'English body');
      expect(a.body('zh'), 'English body');
    });
  });

  group('DailyNewsBundle', () {
    test('orders sections world → china → australia regardless of '
        'JSON key order', () {
      final b = DailyNewsBundle.fromJson({
        'generatedAt': '2026-04-21T06:41:46.986Z',
        'editionDate': '2026-04-21',
        'sections': {
          'australia': {
            'id': 'australia',
            'title': {'en': 'AU'},
            'items': [],
          },
          'world': {
            'id': 'world',
            'title': {'en': 'W'},
            'items': [],
          },
          'china': {
            'id': 'china',
            'title': {'en': 'CN'},
            'items': [],
          },
        },
      });
      expect(b.sections.map((s) => s.id).toList(),
          ['world', 'china', 'australia']);
    });

    test('appends unknown sections at the end', () {
      final b = DailyNewsBundle.fromJson({
        'sections': {
          'world': {
            'id': 'world',
            'title': {'en': 'W'},
            'items': [],
          },
          'science': {
            'id': 'science',
            'title': {'en': 'Sci'},
            'items': [],
          },
        },
      });
      expect(b.sections.map((s) => s.id).toList(), ['world', 'science']);
    });

    test('allArticles flattens every section in order', () {
      final b = DailyNewsBundle.fromJson({
        'sections': {
          'world': {
            'id': 'world',
            'title': {'en': 'W'},
            'items': [
              {'id': 'w1', 'section': 'world'},
              {'id': 'w2', 'section': 'world'},
            ],
          },
          'china': {
            'id': 'china',
            'title': {'en': 'CN'},
            'items': [
              {'id': 'c1', 'section': 'china'},
            ],
          },
        },
      });
      expect(b.allArticles.map((a) => a.id).toList(), ['w1', 'w2', 'c1']);
    });
  });

  group('mergeUniqueArticles', () {
    NewsArticle article(String id) => NewsArticle.fromJson({'id': id});

    test('returns only articles not already present', () {
      final existing = [article('a'), article('b')];
      final incoming = [article('b'), article('c'), article('d')];
      final added = mergeUniqueArticles(existing, incoming);
      expect(added.map((a) => a.id).toList(), ['c', 'd']);
    });

    test('returns everything when nothing overlaps', () {
      final added = mergeUniqueArticles([article('a')], [article('b'), article('c')]);
      expect(added.map((a) => a.id).toList(), ['b', 'c']);
    });

    test('returns empty when incoming is a full subset of existing', () {
      final added = mergeUniqueArticles(
        [article('a'), article('b')],
        [article('a'), article('b')],
      );
      expect(added, isEmpty);
    });

    test('dedupes within incoming itself, keeping the first occurrence', () {
      final added = mergeUniqueArticles([], [article('a'), article('a')]);
      expect(added.map((a) => a.id).toList(), ['a']);
    });

    test('empty existing + empty incoming yields empty', () {
      expect(mergeUniqueArticles([], []), isEmpty);
    });
  });
}
