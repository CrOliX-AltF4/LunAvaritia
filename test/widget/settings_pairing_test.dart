import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/models/assistant_identity.dart';
import 'package:lunavaritia/screens/settings_screen.dart';
import 'package:lunavaritia/services/backend_error.dart';
import 'package:lunavaritia/services/pairing.dart';
import 'package:lunavaritia/services/update_checker.dart';

// ADR-020 M3 — pairing from the settings: no secret is ever typed; an old one is replaced by the device token.

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Map<String, String> secure;

  setUp(() {
    secure = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_secureStorageChannel, (call) async {
      final args = (call.arguments as Map?)?.cast<String, dynamic>() ?? {};
      final key = args['key'] as String?;
      switch (call.method) {
        case 'write':
          secure[key!] = args['value'] as String;
          return null;
        case 'read':
          return secure[key];
        case 'delete':
          secure.remove(key);
          return null;
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(_secureStorageChannel, null);
  });

  Future<void> pump(WidgetTester tester, PairDevice pair, {RegisterPush? registerPush, LeaveStandalonePush? leaveStandalonePush}) async {
    await tester.pumpWidget(MaterialApp(
      home: SettingsScreen(
        probe: (_) async => AssistantIdentity.unknown,
        checkUpdate: () async => const UpToDate('1.4.0'),
        pair: pair,
        registerPush: registerPush ?? (_) async {},
        leaveStandalonePush: leaveStandalonePush ?? (_) async {},
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('no secret field any more — pairing instead', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester, ({required target, required url, required code, required name}) async => 'acd_dev_x');
    expect(find.text("Jeton d'accès"), findsNothing);
    expect(find.text("Cet appareil n'est pas appairé."), findsOneWidget);
  });

  testWidgets('says an old shared secret is still on the phone', (tester) async {
    SharedPreferences.setMockInitialValues({'acedia_url': 'http://acedia:4001'});
    secure['acedia_token'] = 'the-acedia-master-secret';
    await pump(tester, ({required target, required url, required code, required name}) async => 'acd_dev_x');
    expect(find.textContaining('Ancien secret enregistré'), findsOneWidget);
  });

  testWidgets('pairs with a code and replaces the old secret with the device token', (tester) async {
    SharedPreferences.setMockInitialValues({'acedia_url': 'http://acedia:4001'});
    secure['acedia_token'] = 'the-acedia-master-secret';
    PairingTarget? usedTarget;
    String? usedUrl;
    String? usedCode;
    await pump(tester, ({required target, required url, required code, required name}) async {
      usedTarget = target;
      usedUrl = url;
      usedCode = code;
      return 'acd_dev_new';
    });

    await tester.tap(find.text('Appairer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'ABCD2345');
    await tester.tap(find.widgetWithText(FilledButton, 'Appairer'));
    await tester.pumpAndSettle();

    expect(usedTarget, PairingTarget.lunacedia);
    expect(usedUrl, 'http://acedia:4001');
    expect(usedCode, 'ABCD2345');
    expect(secure['acedia_token'], 'acd_dev_new');
    expect(secure.values, isNot(contains('the-acedia-master-secret')));
    expect(find.text('Cet appareil est appairé.'), findsOneWidget);
  });

  // Live check V3 (2026-10-05): the push token was only sent at startup, refused before pairing, never sent again.
  testWidgets('registers for notifications with the new device token right after pairing', (tester) async {
    SharedPreferences.setMockInitialValues({'acedia_url': 'http://acedia:4001'});
    final registered = <ApiConfig>[];
    await pump(
      tester,
      ({required target, required url, required code, required name}) async => 'acd_dev_new',
      registerPush: (config) async => registered.add(config),
    );

    await tester.tap(find.text('Appairer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'ABCD2345');
    await tester.tap(find.widgetWithText(FilledButton, 'Appairer'));
    await tester.pumpAndSettle();

    expect(registered, hasLength(1));
    expect(registered.single.baseUrl, 'http://acedia:4001');
    expect(registered.single.token, 'acd_dev_new');
  });

  // §5.10 Q4 (V3b): wired, the hub sends the notifications — LunAcedia must stop sending to this phone, or they come twice.
  group('moving to the hub', () {
    Future<void> wireToHub(WidgetTester tester) async {
      await tester.tap(find.text('Avancé — relier à un hub'));
      await tester.pumpAndSettle();
      await tester.enterText(find.widgetWithText(TextField, 'Adresse du hub'), 'http://hub:3333');
      await tester.tap(find.text('Sauvegarder'));
      await tester.pumpAndSettle();
    }

    testWidgets("takes this phone off LunAcedia's notifications, with its LunAcedia token", (tester) async {
      SharedPreferences.setMockInitialValues({'acedia_url': 'http://acedia:4001'});
      secure['acedia_token'] = 'acd_dev_phone';
      final left = <ApiConfig>[];
      await pump(tester, ({required target, required url, required code, required name}) async => 'x',
          leaveStandalonePush: (config) async => left.add(config));

      await wireToHub(tester);

      expect(left, hasLength(1));
      expect(left.single.baseUrl, 'http://acedia:4001');
      expect(left.single.token, 'acd_dev_phone');
      expect(left.single.wired, isFalse);
    });

    testWidgets('does nothing when the phone was already wired', (tester) async {
      SharedPreferences.setMockInitialValues({'acedia_url': 'http://acedia:4001', 'hub_url': 'http://hub:3333'});
      secure['acedia_token'] = 'acd_dev_phone';
      final left = <ApiConfig>[];
      await pump(tester, ({required target, required url, required code, required name}) async => 'x',
          leaveStandalonePush: (config) async => left.add(config));

      await tester.tap(find.text('Sauvegarder'));
      await tester.pumpAndSettle();

      expect(left, isEmpty);
    });
  });

  testWidgets('says why pairing failed and keeps the dialog open', (tester) async {
    SharedPreferences.setMockInitialValues({'acedia_url': 'http://acedia:4001'});
    await pump(tester, ({required target, required url, required code, required name}) async {
      throw BackendError(BackendErrorKind.unauthorized, statusCode: 401);
    });
    await tester.tap(find.text('Appairer'));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Code'), 'WRONG');
    await tester.tap(find.widgetWithText(FilledButton, 'Appairer'));
    await tester.pumpAndSettle();
    expect(find.text('Code invalide ou expiré — demandez-en un nouveau.'), findsOneWidget);
    expect(find.text('Appairer cet appareil'), findsOneWidget);
  });

  testWidgets('asks for the address first', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pump(tester, ({required target, required url, required code, required name}) async => 'acd_dev_x');
    await tester.tap(find.text('Appairer'));
    await tester.pumpAndSettle();
    expect(find.text("Renseignez d'abord l'adresse."), findsOneWidget);
    expect(find.text('Appairer cet appareil'), findsNothing);
  });

}
