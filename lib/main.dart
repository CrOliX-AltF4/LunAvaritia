import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'services/connection_controller.dart';
import 'services/push_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicences();

  final connection = await ConnectionController.load();

  // The UI first: nothing that needs the network may hold the app on its launch screen (live check
  // 2026-09-29 — away from home, registering the push token with an unreachable server did).
  runApp(LunAvaritiaApp(connection: connection));

  unawaited(_forgetLocalHistory());
  unawaited(_startPush(connection));
}

/// FCM — non-fatal and in the background: Firebase may not be configured, the server may be out of reach.
Future<void> _startPush(ConnectionController connection) async {
  try {
    await Firebase.initializeApp();
    await PushService(connection).init();
  } catch (_) {}
}

/// The conversations live on the server now (topics): the chat history the app used to keep goes.
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
