import 'package:package_info_plus/package_info_plus.dart';

/// "1.8.0" — the version actually installed, read from the package (never written by hand, C18). Android's build
/// number is left out: it only serves Android's updates and meant nothing on screen (2026-10-07).
Future<String> installedVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (_) {
    return 'version inconnue';
  }
}
