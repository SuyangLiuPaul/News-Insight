// A free, GitHub-backed update check — 2026-09-17, 「this app should
// have check upgrade as well and frequency too?」.
//
// There is no app store in the loop: the native builds are published as
// assets on this project's GitHub Releases by `tools/release_github.sh`.
// This asks the Releases API for the latest one, compares its tag to the
// running version, and hands back the asset for this platform (falling
// back to the release page).
//
// It does NOT install anything. Yahweh's Words has a 400-line installer
// for the Android case; this app does not, and the difference is
// deliberate — the URL goes to the browser, which downloads the APK, and
// Android's own "install an update?" screen does the rest. One fewer
// thing to keep working for an app with a two-page interface.
//
// Web returns null throughout: the PWA serves the newest build on
// reload, so there is nothing to tell anyone about.

import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'package:yahwehs_world/constants/app_version.dart';

/// The answer to one check. [updateAvailable] is the only thing the UI
/// branches on; the URL is already resolved for this platform.
class UpdateInfo {
  const UpdateInfo({
    required this.updateAvailable,
    required this.currentVersion,
    required this.latestVersion,
    required this.downloadUrl,
    required this.releaseUrl,
  });

  final bool updateAvailable;
  final String currentVersion;
  final String latestVersion;

  /// The platform's asset, or the release page when there is none.
  final String downloadUrl;
  final String releaseUrl;
}

class UpdateService {
  UpdateService._();

  static const String repo = 'SuyangLiuPaul/News-Insight';
  static const String _latestApi =
      'https://api.github.com/repos/$repo/releases/latest';
  static const String releasesPage =
      'https://github.com/$repo/releases/latest';

  /// Native only. Web has nothing to update.
  static bool get isSupported {
    if (kIsWeb) return false;
    try {
      return Platform.isAndroid || Platform.isMacOS || Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  /// THE VERSION THIS BUILD ADMITS TO, or null if it does not know.
  ///
  /// This app's [kAppVersion] is
  /// `String.fromEnvironment('APP_VERSION', defaultValue: 'dev')` —
  /// deliberately, because a hard-coded literal went stale once and the
  /// app claimed to be v1.1.6 for months. The consequence is that a
  /// build made without the `--dart-define` calls itself `dev`, and
  /// `dev` parses to 0.0.0, and 0.0.0 is older than every release ever
  /// published. Left alone, such a build would nag about an update on
  /// every single launch, forever, and the nag would be wrong.
  ///
  /// So an unparseable version means "I cannot tell", not "I am
  /// ancient": the check returns null and the reader is told nothing.
  static String? get _knownVersion {
    final v = kAppVersion.trim();
    return looksLikeAVersion(v) ? v : null;
  }

  /// Public so a test can pin the `dev` case without a network.
  static bool looksLikeAVersion(String v) =>
      RegExp(r'^\d+(\.\d+)*$').hasMatch(v.trim());

  /// Returns null for "could not check" — never throws. Callers treat
  /// null as silence.
  static Future<UpdateInfo?> checkForUpdate() async {
    if (!isSupported) return null;
    final current = _knownVersion;
    if (current == null) return null;
    try {
      final resp = await http
          .get(Uri.parse(_latestApi),
              headers: const {'Accept': 'application/vnd.github+json'})
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;

      final body = jsonDecode(resp.body) as Map<String, dynamic>;
      final latest = stripV((body['tag_name'] as String?) ?? '');
      if (latest.isEmpty) return null;

      final releaseUrl = (body['html_url'] as String?) ?? releasesPage;
      final assets = (body['assets'] as List?) ?? const [];

      return UpdateInfo(
        updateAvailable: isNewer(latest, current),
        currentVersion: current,
        latestVersion: latest,
        downloadUrl: _assetUrlForPlatform(assets) ?? releaseUrl,
        releaseUrl: releaseUrl,
      );
    } catch (_) {
      return null;
    }
  }

  /// "v1.2.8" → "1.2.8".
  static String stripV(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  /// True iff [latest] is a higher version than [current]. Only the
  /// first three segments are compared, so a dev build calling itself
  /// `1.2.8.3` compares equal to the 1.2.8 release it was built from
  /// rather than newer than it.
  static bool isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (var i = 0; i < 3; i++) {
      if (l[i] != c[i]) return l[i] > c[i];
    }
    return false;
  }

  static List<int> _parse(String v) {
    final parts = v.split('.');
    return List<int>.generate(3, (i) {
      if (i >= parts.length) return 0;
      final digits = parts[i].replaceAll(RegExp(r'[^0-9]'), '');
      return int.tryParse(digits) ?? 0;
    });
  }

  /// The asset for this platform, by the names `release_github.sh`
  /// actually uploads: `News-Insight-Android-v…apk`, `News-Insight-iOS-v…zip`,
  /// `News-Insight-macOS-v…zip`, `News-Insight-Web-v…zip`.
  ///
  /// iOS returns null on purpose — its zip is an unsigned .app that a
  /// phone cannot install from a browser, so the release page (which
  /// explains itself) is the honest destination.
  static String? _assetUrlForPlatform(List<dynamic> assets) {
    String needle;
    try {
      if (Platform.isAndroid) {
        needle = '.apk';
      } else if (Platform.isMacOS) {
        needle = 'macOS';
      } else {
        return null;
      }
    } catch (_) {
      return null;
    }
    for (final a in assets) {
      if (a is! Map) continue;
      final name = (a['name'] as String?) ?? '';
      final url = (a['browser_download_url'] as String?) ?? '';
      if (url.isNotEmpty && name.contains(needle)) return url;
    }
    return null;
  }
}
