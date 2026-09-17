/// How often the app may ask GitHub whether there is a newer release.
///
/// 2026-09-17 「this app should have check upgrade as well and frequency
/// too?」. Ported from Yahweh's Words, which has had the same four
/// choices since 2026-06 — same names, same gaps, same default — because
/// a reader who has met this control in one of these apps should not
/// have to learn it again in another.
enum UpdateCheckFrequency {
  /// Every time the app opens. The honest name for "no gap at all".
  everyLaunch(Duration.zero, 'everyLaunch'),

  /// The default. One request a day is nothing, and it is the shortest
  /// gap at which a reader cannot notice the check happening.
  daily(Duration(days: 1), 'daily'),

  weekly(Duration(days: 7), 'weekly'),

  monthly(Duration(days: 30), 'monthly'),

  /// No automatic check at all. The menu item still works, so this is
  /// "ask me only when I ask", not "never tell me".
  never(null, 'never');

  const UpdateCheckFrequency(this.gap, this.prefValue);

  /// The minimum time between two automatic checks; null for [never].
  final Duration? gap;

  /// What goes into SharedPreferences. Written out rather than taken
  /// from `name` or `index`: an index breaks the moment a value is
  /// inserted in the middle, and `name` ties a stored preference to a
  /// Dart identifier nobody thinks of as a wire format.
  final String prefValue;

  static UpdateCheckFrequency fromPref(String? v) =>
      values.firstWhere((f) => f.prefValue == v, orElse: () => daily);
}

/// The label for each choice, in the two languages this app ships.
const Map<String, Map<String, String>> updateFrequencyLabels = {
  'everyLaunch': {'en': 'Every launch', 'zh': '每次启动'},
  'daily': {'en': 'Daily', 'zh': '每天'},
  'weekly': {'en': 'Weekly', 'zh': '每周'},
  'monthly': {'en': 'Monthly', 'zh': '每月'},
  'never': {'en': 'Never', 'zh': '不自动检查'},
};
