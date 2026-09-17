import 'dart:async';

import 'package:flutter/material.dart';

import '../constants/app_version.dart';
import 'package:provider/provider.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:yahwehs_world/constants/update_check_frequency.dart';
import 'package:yahwehs_world/models/app_settings.dart';
import 'package:yahwehs_world/models/news_article.dart';
import 'package:yahwehs_world/pages/article_detail_page.dart';
import 'package:yahwehs_world/services/news_service.dart';
import 'package:yahwehs_world/services/update_service.dart';
import 'package:yahwehs_world/theme/ui_strings.dart';
import 'package:yahwehs_world/utils/relative_time.dart';
import 'package:yahwehs_world/widgets/article_card.dart';

/// Wide-layout breakpoint — mirrors the master-detail pattern the
/// original in-app News reader used (list left, detail right) rather
/// than reinventing a new one.
const double kWideBreakpoint = 880;

class FeedPage extends StatefulWidget {
  const FeedPage({super.key});

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  DailyNewsBundle? _bundle;
  NewsArticle? _selected;
  String _sectionFilter = 'all';
  bool _refreshing = false;
  String? _error;

  // Infinite scroll into yswords-data's daily archive (older editions,
  // one per calendar day — see that repo's refresh-news.mjs). The
  // live bundle above is always the current edition; these hold
  // whatever older days have been paged in on top of it.
  final List<NewsArticle> _archiveArticles = [];
  List<String> _archiveQueue = const [];
  bool _archiveIndexLoaded = false;
  bool _loadingMore = false;
  bool _archiveExhausted = false;
  bool _loadMoreFailed = false;
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<DailyNewsBundle>? _updatesSub;

  /// The newest release, once asked for and once it turned out to be
  /// newer than this build. Null means "nothing to say" — which covers
  /// web, a build that does not know its own version, a network that did
  /// not answer, and being up to date. See [UpdateService].
  UpdateInfo? _update;
  bool _updateDismissed = false;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    // After the first frame: `context.read` needs a mounted element, and
    // there is no reason for a version check to be in front of the news.
    WidgetsBinding.instance.addPostFrameCallback((_) => _autoCheckUpdate());
    // NewsService.load() only ever hands back its FIRST snapshot — the
    // cache-then-network refresh underneath it keeps running silently
    // after that, so without this subscription a fresher bundle (say,
    // one where a broken image URL or a missing translation has since
    // been fixed upstream) could arrive and never actually reach the
    // screen. This is what lets a same-session background refresh
    // repair itself instead of requiring a manual refresh tap.
    _updatesSub = NewsService.updates.listen((b) {
      if (!mounted) return;
      setState(() {
        _bundle = b;
        _selected = _resolveSelected(b);
      });
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _updatesSub?.cancel();
    super.dispose();
  }

  /// Re-anchors [_selected] to the matching-id article in a freshly
  /// arrived bundle, rather than leaving it pointing at a stale
  /// [NewsArticle] instance whose fields (image, translations, …)
  /// may have since been corrected upstream. Falls back to the first
  /// article, or null if the bundle is empty.
  NewsArticle? _resolveSelected(DailyNewsBundle b) {
    if (_selected != null) {
      for (final a in b.allArticles) {
        if (a.id == _selected!.id) return a;
      }
    }
    return b.allArticles.isNotEmpty ? b.allArticles.first : null;
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    // Trigger a bit before the true end so the next page is usually
    // ready by the time the user actually reaches the bottom.
    if (position.pixels >= position.maxScrollExtent - 600) {
      _loadMore();
    }
  }

  Future<void> _load() async {
    try {
      final b = await NewsService.load();
      if (!mounted) return;
      setState(() {
        _bundle = b;
        _error = null;
        _selected ??= b.allArticles.isNotEmpty ? b.allArticles.first : null;
      });
      await _loadArchiveIndexIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    }
  }

  Future<void> _manualRefresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      await NewsService.refresh(force: true);
      final b = await NewsService.load();
      if (!mounted) return;
      setState(() {
        _bundle = b;
        _error = null;
        // A manual refresh restarts the scroll history from the live
        // edition — otherwise a story that moved between sections/ids
        // across the refresh could linger in the stale archive list.
        _archiveArticles.clear();
        _archiveQueue = const [];
        _archiveIndexLoaded = false;
        _archiveExhausted = false;
        _loadMoreFailed = false;
        _selected = _resolveSelected(b);
      });
      // The archive history above was just cleared back to only the
      // live edition, so any scroll position deeper than that is now
      // stale — jump back to the top of the fresh list.
      _scrollToTop();
      await _loadArchiveIndexIfNeeded();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  Future<void> _loadArchiveIndexIfNeeded() async {
    if (_archiveIndexLoaded) return;
    final dates = await NewsService.loadArchiveIndex();
    if (!mounted) return;
    setState(() {
      _archiveQueue = dates;
      _archiveIndexLoaded = true;
      _archiveExhausted = dates.isEmpty;
    });
    _fillIfNotScrollable();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _archiveExhausted || !_archiveIndexLoaded) return;
    if (_archiveQueue.isEmpty) {
      setState(() => _archiveExhausted = true);
      return;
    }

    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });

    final date = _archiveQueue.first;
    final edition = await NewsService.loadArchiveEdition(date);
    if (!mounted) return;

    if (edition == null) {
      // Leave the date at the front of the queue so retrying (either
      // the explicit button or the next scroll trigger) tries the
      // same day again rather than silently skipping it.
      setState(() {
        _loadingMore = false;
        _loadMoreFailed = true;
      });
      return;
    }

    final known = <NewsArticle>[
      ...(_bundle?.allArticles ?? const <NewsArticle>[]),
      ..._archiveArticles,
    ];
    final added = mergeUniqueArticles(known, edition.allArticles);

    setState(() {
      _archiveQueue = _archiveQueue.sublist(1);
      _archiveArticles.addAll(added);
      _loadingMore = false;
      _archiveExhausted = _archiveQueue.isEmpty;
    });
    _fillIfNotScrollable();
  }

  void _retryLoadMore() {
    setState(() => _loadMoreFailed = false);
    _loadMore();
  }

  /// Scrolling target 0 is always valid regardless of the (possibly
  /// still stale, pre-rebuild) scroll extent, so this is safe to call
  /// right after a setState that changes the list's content — no need
  /// to wait a frame for the new extent to be measured.
  void _scrollToTop() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _onSectionFilterChanged(String value) {
    setState(() => _sectionFilter = value);
    _scrollToTop();
  }

  /// If the current (possibly filtered) list is short enough that the
  /// list isn't scrollable at all, the user can never perform the
  /// "scroll near the bottom" gesture that normally triggers the next
  /// page — so proactively keep paging in older editions until either
  /// the viewport is filled or the archive genuinely runs out.
  void _fillIfNotScrollable() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      final position = _scrollController.position;
      if (position.maxScrollExtent <= 0 &&
          !_loadingMore &&
          !_archiveExhausted &&
          _archiveIndexLoaded) {
        _loadMore();
      }
    });
  }

  List<NewsArticle> get _filtered {
    final all = <NewsArticle>[
      ...(_bundle?.allArticles ?? const <NewsArticle>[]),
      ..._archiveArticles,
    ];
    if (_sectionFilter == 'all') return all;
    return all.where((a) => a.section == _sectionFilter).toList();
  }

  /// The automatic check, which only runs when the reader's own chosen
  /// interval has elapsed — and records that it ran WHATEVER the answer,
  /// so "daily" means daily rather than "daily until you are behind".
  Future<void> _autoCheckUpdate() async {
    if (!mounted) return;
    final settings = context.read<AppSettings>();
    if (!settings.updateCheckIsDue) return;
    final info = await UpdateService.checkForUpdate();
    await settings.noteUpdateChecked();
    if (!mounted || info == null || !info.updateAvailable) return;
    setState(() => _update = info);
  }

  /// The menu item. Unlike the automatic check this ALWAYS answers —
  /// "you have the newest version" is the useful reply to someone who
  /// asked, and saying nothing would read as a broken button.
  Future<void> _checkUpdateNow(String locale) async {
    final settings = context.read<AppSettings>();
    final info = await UpdateService.checkForUpdate();
    await settings.noteUpdateChecked();
    if (!mounted) return;
    if (info == null) {
      _say(uiStrings['checkFailed']?[locale] ?? "Couldn't check right now");
      return;
    }
    if (!info.updateAvailable) {
      _say(uiStrings['upToDate']?[locale] ?? 'You have the newest version');
      return;
    }
    setState(() {
      _update = info;
      _updateDismissed = false;
    });
  }

  void _say(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openUpdate() async {
    final info = _update;
    if (info == null) return;
    final uri = Uri.tryParse(info.downloadUrl);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<AppSettings>();
    final locale = settings.locale;
    final wide = MediaQuery.of(context).size.width >= kWideBreakpoint;

    return Scaffold(
      appBar: AppBar(
        title: Text(uiStrings['appName']?[locale] ?? 'News Insight'),
        actions: [
          TextButton(
            onPressed: settings.toggleLocale,
            child: Text(
              locale == 'en' ? '中文' : 'EN',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: uiStrings['refresh']?[locale] ?? 'Refresh',
            icon: _refreshing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh_outlined),
            onPressed: _refreshing ? null : _manualRefresh,
          ),
          // The app's ONLY menu. It exists for the update check, which
          // has nowhere else to live — this app has two pages and no
          // settings screen, and adding one to hold a single control
          // would be a worse trade than a three-dot button.
          PopupMenuButton<Object>(
            key: const ValueKey('feedOverflowMenu'),
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'check') {
                _checkUpdateNow(locale);
              } else if (value is UpdateCheckFrequency) {
                settings.setUpdateCheckFrequency(value);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<Object>(
                value: 'check',
                child: Text(
                    uiStrings['checkForUpdates']?[locale] ?? 'Check for updates'),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<Object>(
                enabled: false,
                child: Text(
                  uiStrings['autoCheck']?[locale] ?? 'Check automatically',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
              for (final f in UpdateCheckFrequency.values)
                CheckedPopupMenuItem<Object>(
                  value: f,
                  checked: settings.updateCheckFrequency == f,
                  child: Text(
                      updateFrequencyLabels[f.prefValue]?[locale] ?? f.name),
                ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(context, locale, wide),
    );
  }

  Widget _buildBody(BuildContext context, String locale, bool wide) {
    if (_bundle == null) {
      return Center(
        child: _error != null
            ? _ErrorState(error: _error!, locale: locale, onRetry: _load)
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(uiStrings['loading']?[locale] ?? 'Loading…'),
                ],
              ),
      );
    }

    final articles = _filtered;

    return Column(
      children: [
        if (_update case final info? when !_updateDismissed)
          _UpdateBar(
            info: info,
            locale: locale,
            onDownload: _openUpdate,
            onDismiss: () => setState(() => _updateDismissed = true),
          ),
        _Masthead(bundle: _bundle!, locale: locale),
        _SectionFilterBar(
          value: _sectionFilter,
          locale: locale,
          sections: _bundle!.sections,
          onChanged: _onSectionFilterChanged,
        ),
        const Divider(height: 1),
        Expanded(
          child: articles.isEmpty
              ? Center(
                  child: Text(uiStrings['emptyTitle']?[locale] ?? 'No stories'),
                )
              : (wide
                  ? _buildTwoColumn(context, articles, locale)
                  : _buildSingleColumn(context, articles, locale)),
        ),
      ],
    );
  }

  Widget _buildSingleColumn(
      BuildContext context, List<NewsArticle> articles, String locale) {
    return RefreshIndicator(
      onRefresh: _manualRefresh,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: articles.length + 1,
        itemBuilder: (context, i) {
          if (i == articles.length) {
            return _buildListFooter(context, locale);
          }
          final a = articles[i];
          return ArticleCard(
            article: a,
            locale: locale,
            selected: false,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) =>
                      ArticleDetailPage(article: a, locale: locale),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTwoColumn(
      BuildContext context, List<NewsArticle> articles, String locale) {
    final selected = _selected != null &&
            articles.any((a) => a.id == _selected!.id)
        ? _selected
        : (articles.isNotEmpty ? articles.first : null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 420,
          child: RefreshIndicator(
            onRefresh: _manualRefresh,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: articles.length + 1,
              itemBuilder: (context, i) {
                if (i == articles.length) {
                  return _buildListFooter(context, locale);
                }
                final a = articles[i];
                return ArticleCard(
                  article: a,
                  locale: locale,
                  selected: selected?.id == a.id,
                  onTap: () => setState(() => _selected = a),
                );
              },
            ),
          ),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: selected == null
              ? Center(
                  child: Text(
                      uiStrings['selectAStory']?[locale] ?? 'Select a story'),
                )
              : ArticleDetailPage(
                  key: ValueKey<String>(selected.id),
                  article: selected,
                  locale: locale,
                  embedded: true,
                ),
        ),
      ],
    );
  }

  /// End-of-list state for the infinite scroll: loading spinner while
  /// the next archived day is being fetched, a retry affordance if
  /// that fetch failed, "no more stories" once the archive is
  /// genuinely exhausted (including day one, before any day has ever
  /// been archived upstream), or nothing while the archive index
  /// itself is still being probed.
  Widget _buildListFooter(BuildContext context, String locale) {
    if (!_archiveIndexLoaded) {
      return const SizedBox(height: 24);
    }

    final scheme = Theme.of(context).colorScheme;

    if (_loadingMore) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(height: 8),
              Text(
                uiStrings['loadingMore']?[locale] ?? 'Loading more…',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    if (_loadMoreFailed) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: TextButton.icon(
            onPressed: _retryLoadMore,
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              uiStrings['retryLoadMore']?[locale] ?? 'Tap to retry',
            ),
          ),
        ),
      );
    }

    if (_archiveExhausted) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text(
            uiStrings['noMoreStories']?[locale] ?? 'No more stories',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      );
    }

    return const SizedBox(height: 24);
  }
}

class _Masthead extends StatelessWidget {
  const _Masthead({required this.bundle, required this.locale});
  final DailyNewsBundle bundle;
  final String locale;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final updated = relativeTime(bundle.generatedAt, locale);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              uiStrings['tagline']?[locale] ?? '',
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
          // Two facts, stacked, not run together: the top line is when
          // the FEED refreshed, the bottom is which BUILD is running.
          // These were briefly siblings in this Row, which printed
          // "更新于 2小时前v1.1.6 · …" as one unbroken string.
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (updated.isNotEmpty)
                Text(
                  (uiStrings['lastUpdated']?[locale] ?? 'Updated {time}')
                      .replaceFirst('{time}', updated),
                  style: TextStyle(
                      fontSize: 12, color: scheme.onSurfaceVariant),
                ),
              Text(
                formatReleaseTimeShort().isEmpty
                    ? 'v$kAppVersion'
                    : 'v$kAppVersion · ${formatReleaseTimeShort()}',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.4,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionFilterBar extends StatelessWidget {
  const _SectionFilterBar({
    required this.value,
    required this.locale,
    required this.sections,
    required this.onChanged,
  });
  final String value;
  final String locale;
  final List<NewsSection> sections;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    // Chips come from whatever sections the feed actually shipped, so a
    // new desk added upstream appears here without an app release.
    final options = <(String, String)>[
      ('all', uiStrings['sectionAll']?[locale] ?? 'All'),
      for (final s in sections)
        if (s.items.isNotEmpty) (s.id, s.label(locale)),
    ];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final (id, label) = options[i];
          final selected = value == id;
          return ChoiceChip(
            label: Text(label, overflow: TextOverflow.visible, softWrap: false),
            selected: selected,
            onSelected: (_) => onChanged(id),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.locale,
    required this.onRetry,
  });
  final String error;
  final String locale;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined,
              size: 48, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(
            uiStrings['errorTitle']?[locale] ?? "Couldn't load news",
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 6),
          Text(
            uiStrings['errorBody']?[locale] ?? '',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: Text(uiStrings['retry']?[locale] ?? 'Retry'),
          ),
        ],
      ),
    );
  }
}

/// "Version 1.2.8 is available", with a way to get it and a way to stop
/// being told. Dismissal is for this session only: the reader said "not
/// now", not "never", and the next launch is a new now.
class _UpdateBar extends StatelessWidget {
  const _UpdateBar({
    required this.info,
    required this.locale,
    required this.onDownload,
    required this.onDismiss,
  });

  final UpdateInfo info;
  final String locale;
  final VoidCallback onDownload;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = (uiStrings['updateAvailable']?[locale] ??
            'Version {v} is available')
        .replaceAll('{v}', info.latestVersion);
    return Material(
      color: scheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(children: [
          Icon(Icons.system_update_alt,
              size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: scheme.onSecondaryContainer)),
          ),
          TextButton(
            onPressed: onDownload,
            child: Text(uiStrings['download']?[locale] ?? 'Download'),
          ),
          IconButton(
            tooltip: uiStrings['dismiss']?[locale] ?? 'Not now',
            icon: const Icon(Icons.close, size: 18),
            color: scheme.onSecondaryContainer,
            onPressed: onDismiss,
          ),
        ]),
      ),
    );
  }
}
