# News Insight 新闻洞见

**A bilingual (English / 简体中文) world-news reader.**

[![Live app](https://img.shields.io/badge/live%20app-news--insight.netlify.app-8a6d1a)](https://news-insight.netlify.app)
[![Latest release](https://img.shields.io/github/v/release/SuyangLiuPaul/News-Insight)](https://github.com/SuyangLiuPaul/News-Insight/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

**Live app:** [news-insight.netlify.app](https://news-insight.netlify.app) · **Full documentation:** [SuyangLiuPaul.github.io/News-Insight](https://SuyangLiuPaul.github.io/News-Insight/)

---

## What it is

The news, and only the news: headlines, summaries and article bodies across the World, China, Hong Kong, Australia, Science & Nature, Tech, Creation, and Documentary desks, in English and 简体中文. Tap a headline to read the story; "Read original" goes to the publisher.

There is no AI in this app: no commentary, no Scripture, and nothing it shows is generated while you read it (removed 2026-09-20 at the owner's request: 「所有ai评价和经文全部去掉 只看新闻就够了」).

It's a dedicated reader, not a scraper: all content is pulled from **[yswords-data](https://yswords-data.netlify.app/data/daily_news.json)**, a shared, CORS-enabled data pipeline that already runs hourly for a sister Bible-reading app. This project is the read-only client for that feed.

## Features

- **Bilingual throughout** — every headline, summary and article body ships with both an English and a 简体中文 version; toggle instantly with the EN/中文 button, no reload.
- **Eight desks — World / China / Hong Kong / Australia / Science & Nature / Tech / Creation / Documentary** — from trusted outlets (BBC, The Guardian, SBS, DW, SCMP, HKFP, RTHK, Nature, ScienceDaily, Phys.org, Ars Technica, Mongabay, Yale Environment 360, IndieWire), filterable with a single tap. Creation covers nature, wildlife, and the state of the earth; Documentary surfaces new film/TV documentary coverage. The filter chips are driven by the feed itself, so new desks appear without an app update.
- **Responsive master-detail layout** — single column on phone-width screens, a list-plus-reading-pane layout on anything ≥880px wide.
- **Infinite scroll into history** — once you reach the bottom of today's edition, the feed keeps paging in previous days from a rolling 90-day archive.
- **Offline-first loading** — a three-tier fallback (last successful fetch → bundled snapshot → live network) means the feed renders instantly even on a slow connection, then quietly upgrades itself in the background.
- **Dark mode**, system-driven by default.

## Tech stack

- **Flutter** (web + Android + iOS + macOS from one codebase), Dart ^3.12
- **provider** for the small amount of app-wide state (locale, theme)
- **http** + **shared_preferences** for the data layer — no backend of its own
- Deployed to **Netlify** (web) via the Netlify CLI; native builds distributed as [GitHub Releases](https://github.com/SuyangLiuPaul/News-Insight/releases)

## Getting started

```bash
git clone https://github.com/SuyangLiuPaul/News-Insight.git
cd News-Insight
flutter pub get
flutter run -d chrome   # or -d macos / an attached iOS or Android device
```

Run the test suite:

```bash
flutter test
```

The app talks to the public `yswords-data` feed by default — no API key or backend setup required. To point it at a different feed during development:

```bash
flutter run -d chrome --dart-define=DAILY_NEWS_URL=https://example.com/daily_news.json
```

## Project structure

```
lib/
  models/news_article.dart       NewsArticle, NewsSection, DailyNewsBundle
  services/
    remote_data_service.dart     Generic 3-tier cache → bundled asset → network base class
    news_service.dart            The daily-news + archive façade built on top of it
  pages/
    feed_page.dart                Master list, section filter, infinite scroll, refresh
    article_detail_page.dart      Full story
  widgets/
    article_card.dart             Feed row (thumbnail, title, source)
    retry_network_image.dart      Auto-retrying image loader (see docs for why)
  utils/
    relative_time.dart            "3h ago" / "3小时前" formatting
  theme/                          Material 3 theme + all user-facing strings
assets/
  daily_news.json                 Bundled fallback snapshot (offline-first tier 2)
  icon/                           Source icon + flutter_launcher_icons config
  fonts/                          Noto Sans SC (bundled — see docs for why)
```

## Documentation

The README covers the essentials; the full write-up — architecture, the `yswords-data` schema this app consumes, and the engineering notes behind some non-obvious fixes (a CJK font race on cold load, a CORS quirk that silently broke a third of all images, why the cache layer needed a rethink) — lives on the project's GitHub Pages site:

**→ [SuyangLiuPaul.github.io/News-Insight](https://SuyangLiuPaul.github.io/News-Insight/)**

## Data & attribution

Headlines, summaries, and images originate from their original publishers (The Guardian, BBC News, DW, SBS News) via their public RSS feeds; this app always links back to the original article ("Read original") rather than reproducing it in full. The Chinese is translated by the upstream `yswords-data` pipeline, which also stopped running on 2026-09-20 — the feed this app reads is the last edition it published.

## Related projects

- **[yswords-data](https://yswords-data.netlify.app)** — the data pipeline this app reads from (RSS ingestion, translation, image hosting). Its scheduled refresh was stopped on 2026-09-20.
- **[YsWords](https://yswords.netlify.app)** — the sister Bible-reading app this news feed was originally built for, before being split out into its own dedicated reader.

## License

MIT — see [LICENSE](LICENSE). This covers the app's own code only; news content and images remain the property of their original publishers.
