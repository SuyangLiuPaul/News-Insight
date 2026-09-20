// This app shows the news and nothing else — 2026-09-20, the owner:
// 「这个app里面所有ai评价和经文全部去掉 只看新闻就够了」.
//
// The feed (yswords-data's daily_news.json) still carries an AI-picked
// verse, a reflection and matching bookkeeping on every story. Those are
// the pipeline's business; the app's business is not to read them. The
// widget tests hold the screens to that; this file holds the two places
// scripture could hide without a screen ever being rendered — the
// strings the app owns, and the snapshot it ships.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:news_insight/models/news_article.dart';
import 'package:news_insight/theme/ui_strings.dart';

void main() {
  test('no string this app owns speaks of the Bible', () {
    final scripture =
        RegExp(r'bible|scripture|verse|reflection|圣经|經文|经文|反思', caseSensitive: false);
    final offenders = <String>[
      for (final e in uiStrings.entries)
        for (final l in e.value.entries)
          if (scripture.hasMatch(l.value)) '${e.key}/${l.key}: ${l.value}',
    ];
    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('the bundled snapshot carries stories, not verses', () {
    final raw = jsonDecode(File('assets/daily_news.json').readAsStringSync())
        as Map<String, dynamic>;
    final items = <Map<String, dynamic>>[
      for (final s in (raw['sections'] as Map).values)
        for (final i in (s as Map)['items'] as List) (i as Map).cast(),
    ];
    expect(items, isNotEmpty);
    for (final key in ['verse', 'reflection', 'aiVerseId', 'translationState']) {
      expect(items.where((i) => i.containsKey(key)), isEmpty, reason: key);
    }
    // ...and it still parses into the same stories.
    expect(DailyNewsBundle.fromJson(raw).allArticles, hasLength(items.length));
  });
}
