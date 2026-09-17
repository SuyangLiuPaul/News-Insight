/// The update check, and the one way it could be worse than nothing.
///
/// 2026-09-17 「this app should have check upgrade as well and frequency
/// too?」.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:yahwehs_world/constants/update_check_frequency.dart';
import 'package:yahwehs_world/models/app_settings.dart';
import 'package:yahwehs_world/services/update_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('which version is newer', () {
    test('compares numerically, not as text', () {
      expect(UpdateService.isNewer('1.2.10', '1.2.9'), isTrue,
          reason: '10 > 9, though "1.2.10" sorts before "1.2.9" as a string');
      expect(UpdateService.isNewer('1.10.0', '1.9.9'), isTrue);
      expect(UpdateService.isNewer('1.2.8', '1.2.8'), isFalse);
      expect(UpdateService.isNewer('1.2.7', '1.2.8'), isFalse);
    });

    test('only the first three segments count', () {
      // A dev build calls itself `1.2.8.3` — three segments plus the
      // commits since the tag. It is the SAME release as 1.2.8 and must
      // not be offered an update to the thing it already is.
      expect(UpdateService.isNewer('1.2.8', '1.2.8.3'), isFalse);
      expect(UpdateService.isNewer('1.2.9', '1.2.8.3'), isTrue);
    });

    test('a tag is accepted with or without its v', () {
      expect(UpdateService.stripV('v1.2.8'), '1.2.8');
      expect(UpdateService.stripV('1.2.8'), '1.2.8');
    });
  });

  test('a build that does not know its version says nothing', () {
    // THE TRAP THIS APP SPECIFICALLY HAS. `kAppVersion` is
    // `String.fromEnvironment('APP_VERSION', defaultValue: 'dev')`, so a
    // build made without the --dart-define calls itself `dev`. Parsed as
    // a version that is 0.0.0, which is older than every release ever
    // made — so such a build would announce an update on every launch,
    // forever, and be wrong every time.
    expect(UpdateService.looksLikeAVersion('dev'), isFalse);
    expect(UpdateService.looksLikeAVersion(''), isFalse);
    expect(UpdateService.looksLikeAVersion('1.2.8-rc1'), isFalse);
    expect(UpdateService.looksLikeAVersion('1.2.8'), isTrue);
    expect(UpdateService.looksLikeAVersion('1.2.8.3'), isTrue);
  });

  group('when the next check is due', () {
    Future<AppSettings> settingsWith(Map<String, Object> prefs) async {
      SharedPreferences.setMockInitialValues(prefs);
      final s = AppSettings();
      await s.load();
      return s;
    }

    test('a fresh install is due immediately', () async {
      final s = await settingsWith({});
      expect(s.updateCheckFrequency, UpdateCheckFrequency.daily,
          reason: 'daily is the default, as in the sister apps');
      expect(s.updateCheckIsDue, isTrue);
    });

    test('"never" means no automatic check, ever', () async {
      final s = await settingsWith({
        'flutter.newsInsights.updateCheckFrequency': 'never',
      });
      expect(s.updateCheckIsDue, isFalse);
    });

    test('every launch is always due', () async {
      final s = await settingsWith({
        'flutter.newsInsights.updateCheckFrequency': 'everyLaunch',
        'flutter.newsInsights.lastUpdateCheck':
            DateTime.now().toIso8601String(),
      });
      expect(s.updateCheckIsDue, isTrue);
    });

    test('a daily check is not due again the same hour', () async {
      final s = await settingsWith({
        'flutter.newsInsights.lastUpdateCheck': DateTime.now()
            .subtract(const Duration(hours: 1))
            .toIso8601String(),
      });
      expect(s.updateCheckIsDue, isFalse);
    });

    test('a daily check is due again the next day', () async {
      final s = await settingsWith({
        'flutter.newsInsights.lastUpdateCheck': DateTime.now()
            .subtract(const Duration(days: 1, minutes: 1))
            .toIso8601String(),
      });
      expect(s.updateCheckIsDue, isTrue);
    });

    test('the stored value is the spelled-out name, not an index',
        () async {
      // An index breaks the moment a value is inserted in the middle of
      // the enum — someone's "weekly" silently becomes "monthly".
      final s = await settingsWith({});
      await s.setUpdateCheckFrequency(UpdateCheckFrequency.weekly);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('newsInsights.updateCheckFrequency'), 'weekly');
    });
  });
}
