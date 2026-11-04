import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static const repository = String.fromEnvironment('APP_REPOSITORY');

  static bool get hasRepository => repository.contains('/');

  static Uri? get releasesUri => hasRepository
      ? Uri.parse('https://github.com/$repository/releases')
      : null;

  static Future<AppVersion> version() async {
    final info = await PackageInfo.fromPlatform();
    return AppVersion(
      version: info.version,
      build: info.buildNumber,
      appName: info.appName,
    );
  }

  static Future<ReleaseInfo?> latestRelease() async {
    if (!hasRepository) return null;
    try {
      final r = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$repository/releases/latest',
            ),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode != 200) return null;
      final j = jsonDecode(r.body) as Map<String, dynamic>;
      final tag = j['tag_name'] as String?;
      final url = j['html_url'] as String?;
      if (tag == null || url == null) return null;
      return ReleaseInfo(
        tag: tag,
        name: j['name'] as String? ?? tag,
        url: url,
        notes: j['body'] as String? ?? '',
      );
    } catch (_) {
      return null;
    }
  }
}

class AppVersion {
  final String version, build, appName;
  const AppVersion({
    required this.version,
    required this.build,
    required this.appName,
  });

  String get label => build.isEmpty ? version : '$version+$build';
}

class ReleaseInfo {
  final String tag, name, url, notes;
  const ReleaseInfo({
    required this.tag,
    required this.name,
    required this.url,
    required this.notes,
  });

  bool isNewerThan(String currentVersion) {
    final current = _parts(currentVersion);
    final latest = _parts(tag);
    for (var i = 0; i < 3; i++) {
      final a = i < latest.length ? latest[i] : 0;
      final b = i < current.length ? current[i] : 0;
      if (a != b) return a > b;
    }
    return false;
  }

  static List<int> _parts(String raw) {
    final clean = raw.trim().replaceFirst(RegExp(r'^[vV]'), '');
    return [
      for (final part in clean.split('.'))
        int.tryParse(part.replaceAll(RegExp(r'[^0-9].*$'), '')) ?? 0,
    ];
  }
}
