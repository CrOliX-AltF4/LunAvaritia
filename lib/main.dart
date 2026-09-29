import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'config/api_config.dart';
import 'services/backend_client.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = await ApiConfig.load();

  // The UI first: nothing that needs the network may hold the app on its launch screen (live check
  // 2026-09-29 — away from home, registering the push token with an unreachable server did).
  runApp(LunAvaritiaApp(config: config));

  unawaited(_startPush(config));
}

/// FCM — non-fatal and in the background: Firebase may not be configured, the server may be out of reach.
Future<void> _startPush(ApiConfig config) async {
  try {
    await Firebase.initializeApp();
    await PushService(buildBackendClient(config)).init();
  } catch (_) {}
}
