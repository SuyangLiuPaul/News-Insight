// Widget smoke tests for the article rendering widgets, using fixture
// data (not a real network fetch — see news_article_test.dart for the
// JSON-parsing tests, and the manual browser-preview verification for
// the live-data feed page).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:news_insight/models/news_article.dart';
import 'package:news_insight/pages/article_detail_page.dart';
import 'package:news_insight/theme/app_theme.dart';
import 'package:news_insight/widgets/article_card.dart';
import 'package:news_insight/widgets/verse_lens_card.dart';

NewsArticle _fixtureArticle() => NewsArticle.fromJson({
      'id': 'fixture-1',
      'section': 'world',
      'source': 'The Guardian',
      'sourceUrl': 'https://www.theguardian.com',
      'link': 'https://www.theguardian.com/world/example',
      'image': null,
      'publishedAt': DateTime.now().toUtc().toIso8601String(),
      'title': {'en': 'A test headline', 'zh': '测试标题'},
      'summary': {'en': 'A test summary.', 'zh': '测试摘要。'},
      'body': {'en': 'The full test article body.', 'zh': '完整的测试正文。'},
      'reflection': {
        'en': 'This story reminds us to be discerning.',
        'zh': '这则新闻提醒我们要有辨识力。',
      },
      'verse': {
        'reference': 'Philippians 4:8',
        'textEn': 'Whatever is true, whatever is honorable…',
        'textZh': '凡是真实的、凡是可敬的……',
        'themeEn': 'Discernment',
        'themeZh': '辨识',
      },
    });

Widget _wrap(Widget child) => MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(body: child),
    );

void main() {
  testWidgets('ArticleCard shows title, source and verse chip',
      (tester) async {
    final article = _fixtureArticle();
    await tester.pumpWidget(_wrap(
      ArticleCard(
        article: article,
        locale: 'en',
        selected: false,
        onTap: () {},
      ),
    ));

    expect(find.text('A test headline'), findsOneWidget);
    expect(find.textContaining('The Guardian'), findsOneWidget);
    expect(find.text('Philippians 4:8'), findsOneWidget);
  });

  testWidgets('ArticleCard switches to zh title when locale is zh',
      (tester) async {
    final article = _fixtureArticle();
    await tester.pumpWidget(_wrap(
      ArticleCard(
        article: article,
        locale: 'zh',
        selected: false,
        onTap: () {},
      ),
    ));

    expect(find.text('测试标题'), findsOneWidget);
  });

  testWidgets('VerseLensCard shows verse text, reference and reflection',
      (tester) async {
    final article = _fixtureArticle();
    await tester.pumpWidget(
        _wrap(VerseLensCard(article: article, locale: 'en')));

    expect(find.textContaining('Whatever is true'), findsOneWidget);
    expect(find.textContaining('Philippians 4:8'), findsOneWidget);
    expect(find.textContaining('discerning'), findsOneWidget);
  });

  testWidgets('ArticleDetailPage renders headline, body and verse card',
      (tester) async {
    final article = _fixtureArticle();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ArticleDetailPage(article: article, locale: 'en'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A test headline'), findsOneWidget);
    expect(find.textContaining('The full test article body'), findsOneWidget);
    expect(find.textContaining('Philippians 4:8'), findsOneWidget);
  });
}
