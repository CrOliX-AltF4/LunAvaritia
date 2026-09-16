import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'backend_client.dart';
import 'deep_link_router.dart';

// Top-level handler required by Firebase for background messages
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  // Background messages are shown automatically by FCM on Android
}

class PushService {
  PushService(this._api);

  final BackendClient _api;

  final _localNotifications = FlutterLocalNotificationsPlugin();

  static const _channel = AndroidNotificationChannel(
    'lunavaritia_alerts',
    'Natsume Alerts',
    description: 'Push notifications from the Natsume ecosystem',
    importance: Importance.high,
  );

  Future<void> init() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

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

    // Register token with server
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      try {
        await _api.registerPushToken(token);
      } catch (_) {
        // Non-fatal — app works without push
      }
    }

    // Refresh token handler
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await _api.registerPushToken(newToken);
      } catch (_) {}
    });

    // Foreground message display
    FirebaseMessaging.onMessage.listen((message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        _localNotifications.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _channel.id,
              _channel.name,
              channelDescription: _channel.description,
              importance: Importance.high,
              priority: Priority.high,
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
  }

  /// Single choke point for every notification-tap entry point (foreground-shown local
  /// notification, backgrounded app, cold start) — see DeepLinkRouter for why every push
  /// today routes to the same destination regardless of which backend sent it.
  void _routeToPayload(Map<String, dynamic> data) {
    DeepLinkRouter.instance.requestTab(resolveDeepLinkTarget(data));
  }
}
