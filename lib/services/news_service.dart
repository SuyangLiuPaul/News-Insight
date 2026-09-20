import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:news_insight/models/news_article.dart';
import 'package:news_insight/services/remote_data_service.dart';

/// Loads the bilingual daily-news bundle that powers this whole app.
///
/// Source: the yswords-data central data repo
/// (`https://yswords-data.netlify.app/data/daily_news.json`) — a
/// CORS-enabled, hourly-refreshed feed of world/china/australia (and
/// more) headlines. The feed also carries an AI-picked Bible verse and
/// a reflection per story; this app reads neither. It is a dedicated
/// reader for that feed and does not run its own scraping/AI pipeline.
///
/// Override at build time:
///   `--dart-define=DAILY_NEWS_URL=https://example/data/daily_news.json`
class _NewsServiceImpl extends RemoteDataService<DailyNewsBundle> {
  static const String _defaultRemote =
      'https://yswords-data.netlify.app/data/daily_news.json';

  static const String _envUrl = String.fromEnvironment(
    'DAILY_NEWS_URL',
    defaultValue: _defaultRemote,
  );

  @override
  String get bundledAssetPath => 'assets/daily_news.json';

  @override
  String get remoteUrl => _envUrl;

  // v1 -> v2 (2026-07-22): a class of already-installed browsers had
  // cached a pre-fix snapshot (raw unmirrored SBS image URLs and/or
  // incomplete verse translations from an earlier pipeline state) and
  // had no way to self-heal — the old cache-then-background-refresh
  // path never told the UI when fresher data arrived (see `updates`
  // below, added the same day). Bumping the key forces every existing
  // cache to be discarded once, on top of that structural fix.
  @override
  String get cachePrefsKey => 'dailyNews.cachedJson.v2';

  @override
  DailyNewsBundle parse(Map<String, dynamic> json) =>
      DailyNewsBundle.fromJson(json);

  @override
  DateTime? generatedAt(DailyNewsBundle bundle) => bundle.generatedAt;
}

/// Base URL for the archive tree (yswords-data's daily-rollover
/// snapshots — see that repo's refresh-news.mjs). No bundled-asset
/// fallback makes sense here (there's nothing to ship for arbitrary
/// historical dates), so this talks to the network directly rather
/// than going through [RemoteDataService]. Every call is best-effort:
/// network failures, a 404 (nothing archived yet), or malformed JSON
/// all just resolve to an empty/null result rather than throwing —
/// callers treat that the same as "no more stories to page into"
/// instead of surfacing a hard error mid-scroll.
const String _archiveBaseUrl =
    'https://yswords-data.netlify.app/data/archive';

/// Public façade — keeps call sites (`NewsService.load()` /
/// `refresh()`) simple and independent of the underlying
/// [RemoteDataService] implementation.
class NewsService {
  static final _NewsServiceImpl _impl = _NewsServiceImpl();

  static Future<DailyNewsBundle> load() => _impl.load();
  static Future<void> refresh({bool force = false}) =>
      _impl.refresh(force: force);
  static Future<void> clearCache() => _impl.clearCache();

  /// Fires whenever a background refresh brings in a fresher bundle
  /// than whatever [load] originally returned — see
  /// [RemoteDataService.updates] for why a screen needs this instead
  /// of just calling [load] once.
  static Stream<DailyNewsBundle> get updates => _impl.updates;

  /// Available archive dates, newest first (matches the pipeline's own
  /// sort). Empty list on any failure — including the expected
  /// "nothing archived yet" case on a brand-new deploy, before the
  /// first day-rollover has happened upstream.
  static Future<List<String>> loadArchiveIndex() async {
    try {
      final resp = await http
          .get(Uri.parse('$_archiveBaseUrl/index.json'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return const [];
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      final dates = (j['dates'] as List?) ?? const [];
      return dates.whereType<String>().toList();
    } catch (_) {
      return const [];
    }
  }

  /// One archived edition (YYYY-MM-DD, as listed by
  /// [loadArchiveIndex]). Null on any failure so the caller can offer
  /// a retry for *this specific date* rather than silently skipping
  /// it or crashing the scroll interaction.
  static Future<DailyNewsBundle?> loadArchiveEdition(String date) async {
    try {
      final resp = await http
          .get(Uri.parse('$_archiveBaseUrl/$date.json'))
          .timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final j = jsonDecode(resp.body) as Map<String, dynamic>;
      return DailyNewsBundle.fromJson(j);
    } catch (_) {
      return null;
    }
  }
}
