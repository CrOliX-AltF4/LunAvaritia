import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/config/api_config.dart';

const _secureStorageChannel = MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // An in-memory stand-in for the platform's secure storage.
  late Map<String, String> secure;

  setUp(() {
    secure = {};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, (call) async {
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_secureStorageChannel, null);
  });

  group('ApiConfig', () {
    test('no hub: the app talks to LunAcedia', () {
      final cfg = ApiConfig.fromForm(acediaUrl: ' http://a:4001 ', acediaToken: 't', hubUrl: '  ', hubToken: '');
      expect(cfg.wired, isFalse);
      expect(cfg.backendMode, 'lunacedia');
      expect(cfg.baseUrl, 'http://a:4001');
      expect(cfg.token, 't');
    });

    test('a hub set: every call goes to the hub, never to LunAcedia (hub-and-spoke)', () {
      final cfg = ApiConfig.fromForm(acediaUrl: 'http://a:4001', acediaToken: 't', hubUrl: 'http://h:3333', hubToken: 'k');
      expect(cfg.wired, isTrue);
      expect(cfg.backendMode, 'natsume');
      expect(cfg.baseUrl, 'http://h:3333');
      expect(cfg.headers['Authorization'], 'Bearer k');
    });

    test('a fresh install has no address — nothing guessed', () async {
      SharedPreferences.setMockInitialValues({});
      final cfg = await ApiConfig.load();
      expect(cfg.baseUrl, isEmpty);
      expect(cfg.wired, isFalse);
    });

    test('migrates the old single-address layout in "natsume" mode to the hub', () async {
      SharedPreferences.setMockInitialValues({'server_base_url': 'http://h:3333', 'backend_mode': 'natsume'});
      secure['server_token'] = 'k';

      final cfg = await ApiConfig.load();
      expect(cfg.hubUrl, 'http://h:3333');
      expect(cfg.hubToken, 'k');
      expect(cfg.acediaUrl, isEmpty);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('server_base_url'), isNull);
      expect(prefs.getString('backend_mode'), isNull);
      expect(secure.containsKey('server_token'), isFalse);
    });

    test('migrates the old layout in LunAcedia mode, plaintext token included', () async {
      SharedPreferences.setMockInitialValues({'server_base_url': 'http://a:4001', 'server_token': 'plain'});

      final cfg = await ApiConfig.load();
      expect(cfg.acediaUrl, 'http://a:4001');
      expect(cfg.acediaToken, 'plain');
      expect(cfg.wired, isFalse);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('server_token'), isNull);
    });

    test('save then load round-trips both servers', () async {
      SharedPreferences.setMockInitialValues({});
      await ApiConfig.save(acediaUrl: 'http://a:4001', acediaToken: 't', hubUrl: 'http://h:3333', hubToken: 'k');
      final cfg = await ApiConfig.load();
      expect(cfg.acediaUrl, 'http://a:4001');
      expect(cfg.acediaToken, 't');
      expect(cfg.hubUrl, 'http://h:3333');
      expect(cfg.hubToken, 'k');
    });
  });
}
