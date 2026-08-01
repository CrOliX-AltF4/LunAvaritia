import 'package:shared_preferences/shared_preferences.dart';

const _keyLastShown = 'digest_last_shown_at';

/// Gates automatic digest display on app "wake" (cold start or foreground resume) so it
/// doesn't reappear every time the user briefly switches apps and comes back — only after
/// a real gap since it was last shown.
class DigestGate {
  const DigestGate({this.minGap = const Duration(hours: 4)});

  final Duration minGap;

  Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_keyLastShown);
    if (lastMs == null) return true;
    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    return DateTime.now().difference(last) >= minGap;
  }

  Future<void> markShown() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyLastShown, DateTime.now().millisecondsSinceEpoch);
  }
}
