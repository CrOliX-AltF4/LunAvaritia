import 'package:package_info_plus/package_info_plus.dart';

/// "1.3.1 (7)" — the version actually installed, read from the package (never written by hand, C18).
Future<String> installedVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
  } catch (_) {
    return 'version inconnue';
  }
}
