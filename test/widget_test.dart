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
      // The feed still carries these on every story. The app reads
      // neither — the tests below hold it to that.
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
  testWidgets('ArticleCard shows title and source, and no verse',
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
    expect(find.textContaining('Philippians'), findsNothing);
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

  testWidgets('ArticleDetailPage renders headline and body, and nothing '
      'the AI added', (tester) async {
    final article = _fixtureArticle();
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: ArticleDetailPage(article: article, locale: 'en'),
    ));
    await tester.pumpAndSettle();

    expect(find.text('A test headline'), findsOneWidget);
    expect(find.textContaining('The full test article body'), findsOneWidget);

    // 2026-09-20 「所有ai评价和经文全部去掉 只看新闻就够了」: the story's
    // verse and reflection are in the JSON above and must not reach the
    // screen, in either language.
    for (final locale in ['en', 'zh']) {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: ArticleDetailPage(article: article, locale: locale),
      ));
      await tester.pumpAndSettle();
      for (final gone in [
        'Philippians',
        '腓立比书',
        'Whatever is true',
        '凡是真实的',
        'discerning',
        '辨识力',
        'Bible Lens',
        '圣经视角',
        'Reflection',
        '反思',
      ]) {
        expect(find.textContaining(gone), findsNothing,
            reason: '$gone, $locale');
      }
    }
  });
}
