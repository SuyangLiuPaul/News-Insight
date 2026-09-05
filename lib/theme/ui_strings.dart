/// This app's own UI strings — English + Simplified Chinese only,
/// matching exactly what the yswords-data feed provides.
const Map<String, Map<String, String>> uiStrings = {
  'appName': {
    'en': "Yahweh's World",
    'zh': '雅伟之界',
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
};
