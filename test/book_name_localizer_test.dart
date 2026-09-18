// yswords-data's verse.reference is always an English book name
// regardless of locale (no referenceZh field upstream) — these tests
// lock in the display-time localization that fills that gap.

import 'package:flutter_test/flutter_test.dart';
import 'package:news_insight/utils/book_name_localizer.dart';

void main() {
  group('localizeVerseReference', () {
    test('leaves English locale untouched', () {
      expect(localizeVerseReference('Matthew 5:9', 'en'), 'Matthew 5:9');
    });

    test('translates a simple single-word book name', () {
      expect(localizeVerseReference('Matthew 5:9', 'zh'), '马太福音 5:9');
    });

    test('translates a numbered book name (1/2/3 prefix)', () {
      expect(
        localizeVerseReference('1 Corinthians 13:4-7', 'zh'),
        '哥林多前书 13:4-7',
      );
      expect(
        localizeVerseReference('2 Timothy 1:7', 'zh'),
        '提摩太后书 1:7',
      );
    });

    test('translates a multi-word book name', () {
      expect(
        localizeVerseReference('Song of Solomon 2:16', 'zh'),
        '雅歌 2:16',
      );
    });

    test('accepts the singular "Psalm" the corpus actually uses', () {
      expect(localizeVerseReference('Psalm 23:1', 'zh'), '诗篇 23:1');
    });

    test('preserves verse ranges and chapter-only references', () {
      expect(
        localizeVerseReference('Romans 8:28-30', 'zh'),
        '罗马书 8:28-30',
      );
      expect(localizeVerseReference('Genesis 1', 'zh'), '创世纪 1');
    });

    test('falls back to the original string for an unrecognized book', () {
      expect(
        localizeVerseReference('Not A Real Book 1:1', 'zh'),
        'Not A Real Book 1:1',
      );
    });

    test('passes through an empty reference', () {
      expect(localizeVerseReference('', 'zh'), '');
    });
  });
}
