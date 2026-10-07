import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// The notifications this phone shows, known by their tag — the box item's key (« email-… »), « action-<id » for a
/// write waiting for a decision, « alert-<id> » for one of the hub's own alerts. Both servers tag what they send, so the
/// app can take a notification down once its object is settled, wherever that happened (2026-10-07).
abstract class NotificationTray {
  /// Takes down the notification with this tag, if one is shown.
  Future<void> dismiss(String tag);

  /// The tags of the notifications shown right now.
  Future<List<String>> shownTags();

  /// The real tray, set by the app at start; nothing at all in tests unless one sets a fake.
  static NotificationTray instance = const _NoTray();
}

class _NoTray implements NotificationTray {
  const _NoTray();

  @override
  Future<void> dismiss(String tag) async {}

  @override
  Future<List<String>> shownTags() async => const [];
}

/// Android's own tray. A tagged notification is posted with id 0 (FCM's rule, and the app's for what it shows itself).
class LocalNotificationTray implements NotificationTray {
  LocalNotificationTray(this._plugin);

  final FlutterLocalNotificationsPlugin _plugin;

  @override
  Future<void> dismiss(String tag) async {
    try {
      await _plugin.cancel(0, tag: tag);
    } catch (_) {
      // a tray that cannot be reached changes nothing
    }
  }

  @override
  Future<List<String>> shownTags() async {
    try {
      final shown = await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.getActiveNotifications();
      return [for (final n in shown ?? const <ActiveNotification>[]) if (n.tag != null) n.tag!];
    } catch (_) {
      return const [];
    }
  }
}

/// The tag a notification's data names: its item, its action or its alert — what the servers set as its tag.
String? notificationTagOf(Map<String, dynamic> data) {
  final key = data['dedupeKey'] ?? data['key'];
  if (key is String && key.isNotEmpty) return key;
  final alertId = data['alertId'];
  return alertId is String && alertId.isNotEmpty ? 'alert-$alertId' : null;
}
