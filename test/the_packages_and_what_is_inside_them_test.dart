/// The release packages carry the app's name — outside AND inside.
///
/// 2026-09-18. 「这三个release包可以是Yahweh words Yahweh sword之类的吗」.
/// The assets were renamed to `News-Insight-…` first; the half that was
/// missed is what a reader finds after unzipping — the macOS bundle was
/// still `yahwehs_world.app`, the repository's old name and no longer
/// the app's.
///
/// Two contracts, both silent when broken:
///
///   * the FILENAME still carries the substring `_assetUrlForPlatform`
///     matches on (`.apk`, `macOS`). That picker never parses the
///     product token, which is what made the rename safe — this test is
///     what keeps that true.
///
///   * the BUNDLE inside carries the same name, and `release_github.sh`
///     looks for it under that name. It does not glob: a `PRODUCT_NAME`
///     changed without the script fails the build with "no such file",
///     and a script changed without `PRODUCT_NAME` ships nothing.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const String kProduct = 'News-Insight';

/// Throws rather than `expect`s: one of these reads happens while the
/// suite is being ASSEMBLED, outside any test, and `expect` there dies
/// with an unreadable `OutsideTestException` instead of naming the file.
String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('$path is gone — this test would otherwise pass by '
        'reading nothing');
  }
  return file.readAsStringSync();
}

void main() {
  final script = _read('tools/release_github.sh');

  test('every uploaded asset is named for the app', () {
    final names = RegExp(
            r'\$OUT/(' + kProduct + r'-[A-Za-z0-9-]+-v\$VERSION\.[a-z.]+)')
        .allMatches(script)
        .map((m) => m.group(1)!)
        .toSet();
    expect(names, isNotEmpty,
        reason: 'no asset names found in release_github.sh — the regex '
            'above has rotted and this test measures nothing');
    for (final name in names) {
      expect(name, startsWith('$kProduct-'));
    }
  });

  test('the two platforms the updater can install still match', () {
    // `_assetUrlForPlatform`: Android on `.apk`, macOS on `macOS`.
    // Everything else falls back to the release page on purpose.
    expect(script, contains('$kProduct-Android-v\$VERSION.apk'));
    expect(script, contains('$kProduct-macOS-v\$VERSION.zip'));
    final source = _read('lib/services/update_service.dart');
    expect(source, contains("needle = '.apk'"));
    expect(source, contains("needle = 'macOS'"));
  });

  test('the macOS bundle inside is the one the script zips', () {
    expect(_read('macos/Runner/Configs/AppInfo.xcconfig'),
        contains('PRODUCT_NAME = $kProduct'));
    expect(script,
        contains('build/macos/Build/Products/Release/$kProduct.app'),
        reason: 'the script would zip a path the build no longer writes');
    expect(script, contains('$kProduct.app/Contents/Frameworks/'),
        reason: 'the post-zip integrity check names a member the archive '
            'no longer has, so it would fail every release');
  });

  test('the macOS bundle is LABELLED with the app name, not the file name',
      () {
    // PRODUCT_NAME names a file; these two name what a reader sees.
    // Both were `$(PRODUCT_NAME)` until 2026-09-18, which is how the
    // desktop build came to introduce itself as 雅伟之界 — a different
    // app entirely. The Android label has said News Insight all along,
    // so that is the name pinned here.
    final plist = _read('macos/Runner/Info.plist');
    for (final key in ['CFBundleDisplayName', 'CFBundleName']) {
      final match = RegExp('<key>$key</key>\\s*<string>(.*?)</string>')
          .firstMatch(plist);
      expect(match, isNotNull, reason: '$key is missing from Info.plist');
      expect(match!.group(1), 'News Insight');
    }
    expect(_read('android/app/src/main/res/values/strings.xml'),
        contains('<string name="app_name">News Insight</string>'));
  });

  test('the application identifiers are untouched', () {
    // An install whose application id changes is a different app to the
    // OS. These keep the old spelling forever, on purpose.
    expect(_read('macos/Runner/Configs/AppInfo.xcconfig'),
        contains('PRODUCT_BUNDLE_IDENTIFIER = com.yswords.yahwehsworld'));
    expect(_read('linux/CMakeLists.txt'),
        contains('set(APPLICATION_ID "com.yswords.yahwehsworld")'));
  });
}
