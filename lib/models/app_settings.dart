import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:news_insight/constants/update_check_frequency.dart';

/// App-wide settings: locale (en / zh — matches exactly what the
/// yswords-data feed provides; not attempting Traditional Chinese for
/// v1) and theme mode. Deliberately small — this app has far fewer
/// settings than a full Bible-reading app.
class AppSettings extends ChangeNotifier {
  static const _localeKey = 'newsInsights.locale';
  static const _themeModeKey = 'newsInsights.themeMode';
  static const _updateFreqKey = 'newsInsights.updateCheckFrequency';
  static const _lastCheckKey = 'newsInsights.lastUpdateCheck';

  String _locale = 'en';
  ThemeMode _themeMode = ThemeMode.system;
  UpdateCheckFrequency _updateFreq = UpdateCheckFrequency.daily;
  DateTime? _lastUpdateCheck;

  String get locale => _locale;
  ThemeMode get themeMode => _themeMode;
  UpdateCheckFrequency get updateCheckFrequency => _updateFreq;

  /// Whether enough time has passed to ask GitHub again.
  ///
  /// The timestamp is written once per check WHATEVER THE ANSWER — not
  /// only when an update is found. Recording it only on a hit would mean
  /// a reader who is up to date gets checked on every launch, which is
  /// the opposite of what "daily" means.
  bool get updateCheckIsDue {
    final gap = _updateFreq.gap;
    if (gap == null) return false;
    final last = _lastUpdateCheck;
    if (last == null) return true;
    return DateTime.now().difference(last) >= gap;
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _locale = prefs.getString(_localeKey) ?? _deviceDefaultLocale();
    final modeStr = prefs.getString(_themeModeKey);
    _themeMode = switch (modeStr) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _updateFreq =
        UpdateCheckFrequency.fromPref(prefs.getString(_updateFreqKey));
    _lastUpdateCheck = DateTime.tryParse(prefs.getString(_lastCheckKey) ?? '');
    notifyListeners();
  }

  String _deviceDefaultLocale() {
    final code = WidgetsBinding
        .instance.platformDispatcher.locale.languageCode
        .toLowerCase();
    return code == 'zh' ? 'zh' : 'en';
  }

  Future<void> setLocale(String locale) async {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale);
  }

  void toggleLocale() => setLocale(_locale == 'en' ? 'zh' : 'en');

  Future<void> setUpdateCheckFrequency(UpdateCheckFrequency f) async {
    if (_updateFreq == f) return;
    _updateFreq = f;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_updateFreqKey, f.prefValue);
  }

  Future<void> noteUpdateChecked() async {
    _lastUpdateCheck = DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lastCheckKey, _lastUpdateCheck!.toIso8601String());
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
  }
}
