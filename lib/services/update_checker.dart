import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Where releases are published (public repository: readable without a token).
const releasesLatestUrl = 'https://api.github.com/repos/CrOliX-AltF4/LunAvaritia/releases/latest';

const _keyNotifiedVersion = 'update_notified_version';

/// A newer version published on GitHub.
class AvailableUpdate {
  const AvailableUpdate({required this.version, required this.downloadUrl});

  /// "1.4.0" — without the tag's "v".
  final String version;

  /// The signed APK when the release has one, else the release page.
  final String downloadUrl;
}

sealed class UpdateStatus {
  const UpdateStatus();
}

class UpToDate extends UpdateStatus {
  const UpToDate(this.installed);
  final String installed;
}

class UpdateAvailable extends UpdateStatus {
  const UpdateAvailable(this.update);
  final AvailableUpdate update;
}

/// GitHub unreachable, rate-limited, or an answer the app cannot read — never shown as "à jour".
class UpdateUnknown extends UpdateStatus {
  const UpdateUnknown(this.reason);
  final String reason;
}

/// Compares "1.10.0" and "v1.9.2+7"-style versions by their numeric parts: < 0, 0, > 0.
/// The "v" prefix and the "+build" suffix are ignored; a missing part counts as 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) {
    final core = v.trim().replaceFirst(RegExp(r'^v'), '').split('+').first.split('-').first;
    return core.split('.').map((p) => int.tryParse(p) ?? 0).toList();
  }

  final pa = parts(a);
  final pb = parts(b);
  for (var i = 0; i < (pa.length > pb.length ? pa.length : pb.length); i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

Future<String> _installedVersionName() async => (await PackageInfo.fromPlatform()).version;

class UpdateChecker {
  UpdateChecker({http.Client? client, Future<String> Function()? installedVersion})
      : _client = client ?? http.Client(),
        _installedVersion = installedVersion ?? _installedVersionName;

  final http.Client _client;
  final Future<String> Function() _installedVersion;

  static const timeout = Duration(seconds: 10);

  Future<UpdateStatus> check() async {
    final String installed;
    try {
      installed = await _installedVersion();
    } catch (_) {
      return const UpdateUnknown('version installée illisible');
    }
    try {
      final res = await _client
          .get(Uri.parse(releasesLatestUrl), headers: {'Accept': 'application/vnd.github+json'})
          .timeout(timeout);
      if (res.statusCode == 404) return UpToDate(installed); // no release published yet
      if (res.statusCode != 200) return UpdateUnknown('GitHub a répondu ${res.statusCode}');
      final body = jsonDecode(res.body);
      if (body is! Map || body['tag_name'] is! String) return const UpdateUnknown('réponse illisible');
      final latest = (body['tag_name'] as String).replaceFirst(RegExp(r'^v'), '');
      if (compareVersions(latest, installed) <= 0) return UpToDate(installed);

      final assets = body['assets'] is List ? body['assets'] as List : const [];
      String? apk;
      for (final a in assets) {
        if (a is Map && a['browser_download_url'] is String && (a['name'] as String? ?? '').endsWith('.apk')) {
          apk = a['browser_download_url'] as String;
          break;
        }
      }
      final page = body['html_url'] is String ? body['html_url'] as String : null;
      final url = apk ?? page;
      if (url == null) return const UpdateUnknown('release sans lien de téléchargement');
      return UpdateAvailable(AvailableUpdate(version: latest, downloadUrl: url));
    } on TimeoutException {
      return const UpdateUnknown('GitHub n\'a pas répondu à temps');
    } on FormatException {
      return const UpdateUnknown('réponse illisible');
    } catch (_) {
      return const UpdateUnknown('GitHub injoignable');
    }
  }

  /// True the first time [version] is offered — so the launch notice shows once per version, not every launch.
  static Future<bool> shouldNotify(String version) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyNotifiedVersion) != version;
  }

  static Future<void> markNotified(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyNotifiedVersion, version);
  }
}
