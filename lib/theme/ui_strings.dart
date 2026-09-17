/// This app's own UI strings — English + Simplified Chinese only,
/// matching exactly what the yswords-data feed provides.
const Map<String, Map<String, String>> uiStrings = {
  // 2026-09-16 「这个app名字也要改一下」. It was 「Yahweh's World / 雅伟之
  // 界」 — the same name as the BIBLICAL GLOBE at world.yahwehword.com,
  // which is a different app by the same author. Two live apps cannot
  // share a name; this one reads the news, so it is named for that.
  'appName': {
    'en': 'News Insight',
    'zh': '新闻洞见',
  },
  'tagline': {
    'en': 'World news, read alongside Scripture',
    'zh': '透过圣经看世界新闻',
  },
  // Only the 'All' chip is named here. Every other chip takes its label
  // from the feed's own `categoryLabel` (see SectionChips in
  // feed_page.dart), which is why a desk added upstream appears with no
  // app release. Per-desk entries for world…documentary used to sit
  // here for symmetry; they were referenced from nowhere, so editing
  // them changed nothing on screen and they were removed rather than
  // left to read like a translation table that works.
  'sectionAll': {'en': 'All', 'zh': '全部'},
  'refresh': {'en': 'Refresh', 'zh': '刷新'},
  'lastUpdated': {'en': 'Updated {time}', 'zh': '更新于 {time}'},
  'readOriginal': {'en': 'Read original article', 'zh': '阅读原文'},
  'bibleLens': {'en': 'Bible Lens', 'zh': '圣经视角'},
  'reflection': {'en': 'Reflection', 'zh': '反思'},
  'loading': {'en': 'Loading…', 'zh': '加载中…'},
  'errorTitle': {'en': "Couldn't load news", 'zh': '无法加载新闻'},
  'errorBody': {
    'en': 'Please check your connection and try again.',
    'zh': '请检查网络连接后重试。',
  },
  'retry': {'en': 'Retry', 'zh': '重试'},
  'emptyTitle': {'en': 'No stories yet', 'zh': '暂无新闻'},
  'selectAStory': {
    'en': 'Select a story to read',
    'zh': '选择一则新闻阅读',
  },
  'source': {'en': 'Source', 'zh': '来源'},
  'loadingMore': {'en': 'Loading more…', 'zh': '正在加载更多…'},
  'noMoreStories': {'en': 'No more stories', 'zh': '没有更多新闻了'},
  'retryLoadMore': {
    'en': 'Failed to load more — tap to retry',
    'zh': '加载失败，点击重试',
  },

  // 2026-09-17 「this app should have check upgrade as well and
  // frequency too?」
  'checkForUpdates': {'en': 'Check for updates', 'zh': '检查更新'},
  'autoCheck': {'en': 'Check automatically', 'zh': '自动检查'},
  'upToDate': {'en': 'You have the newest version', 'zh': '已经是最新版本'},
  'checkFailed': {
    'en': "Couldn't check right now",
    'zh': '暂时无法检查更新',
  },
  'updateAvailable': {
    'en': 'Version {v} is available',
    'zh': '有新版本 {v}',
  },
  'download': {'en': 'Download', 'zh': '下载'},
  'dismiss': {'en': 'Not now', 'zh': '以后再说'},
};
