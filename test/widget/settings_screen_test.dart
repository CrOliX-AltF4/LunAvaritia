import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/models/assistant_identity.dart';
import 'package:lunavaritia/screens/settings_screen.dart';
import 'package:lunavaritia/services/backend_client.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  Future<void> pumpSettings(WidgetTester tester, IdentityProbe probe) async {
    await tester.pumpWidget(MaterialApp(home: SettingsScreen(probe: probe)));
    await tester.pumpAndSettle();
  }

  group('SettingsScreen', () {
    testWidgets('no mode switch and no assistant name written in the app (ADR-020 D2)', (tester) async {
      await pumpSettings(tester, (_) async => AssistantIdentity.unknown);

      expect(find.text('Natsume'), findsNothing);
      expect(find.byType(SegmentedButton<String>), findsNothing);
      expect(find.text('Serveur LunAcedia'), findsOneWidget);
      expect(find.text('Avancé — relier à un hub'), findsOneWidget);
    });

    testWidgets('an already-wired install opens the hub section', (tester) async {
      SharedPreferences.setMockInitialValues({'hub_url': 'http://hub:3333'});
      await pumpSettings(tester, (_) async => AssistantIdentity.unknown);

      expect(find.text('Adresse du hub'), findsOneWidget);
    });

    testWidgets('the connection test goes to LunAcedia when no hub is set, and shows who answers', (tester) async {
      ApiConfig? probed;
      await pumpSettings(tester, (cfg) async {
        probed = cfg;
        return const AssistantIdentity(name: 'Iris', isCompanion: false);
      });

      await tester.enterText(find.widgetWithText(TextField, 'Adresse'), 'http://acedia:4001');
      await tester.tap(find.text('Tester la connexion'));
      await tester.pumpAndSettle();

      expect(probed!.wired, isFalse);
      expect(probed!.baseUrl, 'http://acedia:4001');
      expect(find.text('Connecté — Iris répond.'), findsOneWidget);
    });

    testWidgets('the connection test says what went wrong', (tester) async {
      await pumpSettings(tester, (_) async => throw BackendError(BackendErrorKind.unauthorized, statusCode: 401));

      await tester.enterText(find.widgetWithText(TextField, 'Adresse'), 'http://acedia:4001');
      await tester.tap(find.text('Tester la connexion'));
      await tester.pumpAndSettle();

      expect(find.text(BackendError(BackendErrorKind.unauthorized).message), findsOneWidget);
    });

    testWidgets('the connection test asks for an address before calling anything', (tester) async {
      var called = false;
      await pumpSettings(tester, (_) async {
        called = true;
        return AssistantIdentity.unknown;
      });

      await tester.tap(find.text('Tester la connexion'));
      await tester.pumpAndSettle();

      expect(called, isFalse);
      expect(find.text('Renseignez une adresse.'), findsOneWidget);
    });
  });
}
