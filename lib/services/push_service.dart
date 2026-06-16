import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'backend_client.dart';

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
        );
      }
    });
  }
}
