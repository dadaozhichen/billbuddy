import 'dart:convert';
import 'dart:io';

import 'package:package_info_plus/package_info_plus.dart';

/// Result of checking for a newer version on GitHub.
class UpdateCheckResult {
  final String currentVersion;
  final String? latestVersion;
  final bool hasUpdate;
  final String? releaseUrl;
  final String? releaseNotes;
  final String? error;

  const UpdateCheckResult({
    required this.currentVersion,
    this.latestVersion,
    this.hasUpdate = false,
    this.releaseUrl,
    this.releaseNotes,
    this.error,
  });

  bool get checkFailed => error != null;
}

/// Check the latest release on GitHub and compare with the running version.
class UpdateService {
  static const _repo = 'dadaozhichen/billbuddy';
  static const _releasesUrl =
      'https://github.com/$_repo/releases';
  static const _apiUrl =
      'https://api.github.com/repos/$_repo/releases/latest';

  /// Fetch the latest release info from GitHub.
  ///
  /// Returns [UpdateCheckResult] even on network errors (hasUpdate = false).
  /// On failure [error] is set so callers can distinguish from "up to date".
  static Future<UpdateCheckResult> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;

    try {
      final client = HttpClient();
      client.userAgent = 'billbuddy';
      client.connectionTimeout = const Duration(seconds: 10);
      final request = await client.getUrl(Uri.parse(_apiUrl));
      final response = await request.close();

      if (response.statusCode != 200) {
        return UpdateCheckResult(
          currentVersion: currentVersion,
          error: '服务器返回 ${response.statusCode}',
          releaseUrl: _releasesUrl,
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final tagName = json['tag_name'] as String? ?? '';
      final latestVersion =
          tagName.startsWith('v') ? tagName.substring(1) : tagName;
      final releaseUrl = json['html_url'] as String?;
      final releaseNotes = json['body'] as String?;

      final hasUpdate = _compareVersions(latestVersion, currentVersion) > 0;

      return UpdateCheckResult(
        currentVersion: currentVersion,
        latestVersion: latestVersion,
        hasUpdate: hasUpdate,
        releaseUrl: releaseUrl,
        releaseNotes: releaseNotes,
      );
    } catch (e) {
      return UpdateCheckResult(
        currentVersion: currentVersion,
        error: '连接失败: $e',
        releaseUrl: _releasesUrl,
      );
    }
  }

  /// Open [url] in the system browser.
  static Future<void> openUrl(String url) async {
    if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else if (Platform.isWindows) {
      await Process.run('start', [url]);
    }
  }

  static String get releasesUrl => _releasesUrl;

  /// Compare two semver strings. Returns >0 if a > b, 0 if equal, <0 if a < b.
  static int _compareVersions(String a, String b) {
    final partsA = a.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final partsB = b.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final len = partsA.length > partsB.length ? partsA.length : partsB.length;
    for (var i = 0; i < len; i++) {
      final va = i < partsA.length ? partsA[i] : 0;
      final vb = i < partsB.length ? partsB[i] : 0;
      if (va != vb) return va - vb;
    }
    return 0;
  }
}
