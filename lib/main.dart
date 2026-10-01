import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'config/api_config.dart';
import 'services/backend_client.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicences();

  final config = await ApiConfig.load();

  // The UI first: nothing that needs the network may hold the app on its launch screen (live check
  // 2026-09-29 — away from home, registering the push token with an unreachable server did).
  runApp(LunAvaritiaApp(config: config));

  unawaited(_forgetLocalHistory());
  unawaited(_startPush(config));
}

/// FCM — non-fatal and in the background: Firebase may not be configured, the server may be out of reach.
Future<void> _startPush(ApiConfig config) async {
  try {
    await Firebase.initializeApp();
    await PushService(buildBackendClient(config)).init();
  } catch (_) {}
}

/// The conversations live on the server now (topics, ADR-020 S4): the chat history the app used to keep goes.
Future<void> _forgetLocalHistory() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('chat_history');
  } catch (_) {}
}

/// The DA's typefaces ship under the SIL Open Font License — listed in the app's licences page.
void _registerFontLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (family, file) in const [
      ('Cormorant Garamond', 'assets/fonts/CormorantGaramond-OFL.txt'),
      ('Inter', 'assets/fonts/Inter-OFL.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks([family], await rootBundle.loadString(file));
    }
  });
}
