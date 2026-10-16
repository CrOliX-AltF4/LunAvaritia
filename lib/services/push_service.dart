import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'connection_controller.dart';
import 'deep_link_router.dart';
import 'notification_tray.dart';

// Top-level handler required by Firebase for background messages. The ones to show are shown by FCM itself on
// Android; the silent ones say which notifications are settled elsewhere — taken down here, the app staying closed.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  final tags = settledTagsOf(message.data);
  if (tags.isEmpty) return;
  final plugin = FlutterLocalNotificationsPlugin();
  try {
    await plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
  } catch (_) {}
  await dismissSettled(LocalNotificationTray(plugin), tags);
}

/// The tags a silent « settled » message names (both servers send `{type: settled, tags: "a,b"}`); empty otherwise.
List<String> settledTagsOf(Map<String, dynamic> data) {
  if (data['type'] != 'settled') return const [];
  final tags = data['tags'];
  if (tags is! String) return const [];
  return [for (final t in tags.split(',')) if (t.trim().isNotEmpty) t.trim()];
}

/// Takes down each settled notification — one that is not shown changes nothing.
Future<void> dismissSettled(NotificationTray tray, List<String> tags) async {
  for (final tag in tags) {
    await tray.dismiss(tag);
  }
}

class PushService {
  PushService(this._connection);

  /// Where the token goes — the server the app talks to now, whatever it was at launch.
  final ConnectionController _connection;

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'lunavaritia_alerts',
    'Notifications',
    description: 'Alertes et messages de ton assistant',
    importance: Importance.high,
  );

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);
    // The controllers take a notification down by its tag once its object is settled.
    NotificationTray.instance = LocalNotificationTray(_localNotifications);

    await _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _localNotifications.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      // Foreground case: onMessage below shows this via flutter_local_notifications
      // (FCM/Firebase's own tap handlers only ever fire for background/terminated
      // launches) — without this callback, tapping a foreground-shown notification did
      // nothing, same gap as the background/terminated cases below.
      onDidReceiveNotificationResponse: (response) {
        final payload = response.payload;
        if (payload == null) return;
        _routeToPayload(jsonDecode(payload) as Map<String, dynamic>);
      },
    );

    // Request permission (Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // A renewed token goes to the server the app talks to now.
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) => unawaited(_connection.registerToken(newToken)));

    // Foreground message display
    FirebaseMessaging.onMessage.listen((message) {
      // Settled elsewhere: nothing to show, its notification goes (the open views follow the stream of changes).
      final settled = settledTagsOf(message.data);
      if (settled.isNotEmpty) {
        unawaited(dismissSettled(NotificationTray.instance, settled));
        return;
      }
      // The app is open: the box may have changed.
      DeepLinkRouter.instance.nudgeBox();
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        // Tagged like the servers tag theirs (id 0, FCM's rule), so it can be taken down the same way.
        final tag = notificationTagOf(message.data);
        _localNotifications.show(
          tag == null ? notification.hashCode : 0,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
              tag: tag,
            ),
          ),
          // Carried through to onDidReceiveNotificationResponse above if the user taps
          // this while it's sitting in the shade — same routing as the background/
          // terminated cases below, just a different Firebase entry point.
          payload: jsonEncode(message.data),
        );
      }
    });

    // Tapped while the app was backgrounded (not terminated).
    FirebaseMessaging.onMessageOpenedApp.listen((message) => _routeToPayload(message.data));

    // App was launched fresh by tapping a notification (terminated case) — checked once,
    // after all the listeners above are already wired, so a cold-start tap isn't missed.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) _routeToPayload(initialMessage.data);

    // Registered with the server LAST: it is the only step that needs the network, and a server out of reach
    // must never delay the listeners above. A server the phone left lets the token go once this one has it.
    await _connection.settle();
  }

  /// Single choke point for every notification-tap entry point (foreground-shown local
  /// notification, backgrounded app, cold start) — see DeepLinkRouter for why every push
  /// today routes to the same destination regardless of which backend sent it.
  void _routeToPayload(Map<String, dynamic> data) {
    DeepLinkRouter.instance.request(resolveDeepLinkTarget(data));
  }
}
