import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'config/api_config.dart';
import 'services/api_service.dart';
import 'services/lunacedia_client.dart';
import 'services/backend_client.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp();

  final config = await ApiConfig.load();

  final BackendClient client = config.backendMode == 'lunacedia'
      ? LunAcediaClient(config)
      : ApiService(config);

  // FCM push — non-fatal if Firebase is not configured
  try {
    await PushService(client).init();
  } catch (_) {}

  runApp(LunAvaritiaApp(config: config));
}
