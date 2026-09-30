import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/services/update_checker.dart';

UpdateChecker _checker(http.Client client, {String installed = '1.3.1'}) =>
    UpdateChecker(client: client, installedVersion: () async => installed);

MockClient _github(int status, Object? body) => MockClient((req) async {
      expect(req.url.toString(), releasesLatestUrl);
      return http.Response(body is String ? body : jsonEncode(body), status);
    });

Map<String, Object?> _release(String tag, {List<Map<String, Object?>> assets = const []}) => {
      'tag_name': tag,
      'html_url': 'https://github.com/CrOliX-AltF4/LunAvaritia/releases/tag/$tag',
      'assets': assets,
    };

void main() {
  group('compareVersions', () {
    test('compares numerically, not as text', () {
      expect(compareVersions('1.10.0', '1.9.2'), greaterThan(0));
      expect(compareVersions('1.3.1', '1.4.0'), lessThan(0));
      expect(compareVersions('2.0.0', '2.0.0'), 0);
    });

    test('ignores the "v" prefix, the build number and a missing part', () {
      expect(compareVersions('v1.4.0', '1.4.0+8'), 0);
      expect(compareVersions('1.4', '1.4.0'), 0);
      expect(compareVersions('1.4.0-beta', '1.4.0'), 0);
    });
  });

  group('UpdateChecker.check', () {
    test('a newer release offers its APK', () async {
      final status = await _checker(_github(200, _release('v1.4.0', assets: [
        {'name': 'notes.txt', 'browser_download_url': 'https://x/notes.txt'},
        {'name': 'lunavaritia-v1.4.0.apk', 'browser_download_url': 'https://x/lunavaritia-v1.4.0.apk'},
      ]))).check();

      expect(status, isA<UpdateAvailable>());
      final update = (status as UpdateAvailable).update;
      expect(update.version, '1.4.0');
      expect(update.downloadUrl, 'https://x/lunavaritia-v1.4.0.apk');
    });

    test('a newer release without an APK points to its page', () async {
      final status = await _checker(_github(200, _release('v1.4.0'))).check();
      expect((status as UpdateAvailable).update.downloadUrl, endsWith('/releases/tag/v1.4.0'));
    });

    test('the same or an older release: up to date', () async {
      expect(await _checker(_github(200, _release('v1.3.1'))).check(), isA<UpToDate>());
      expect(await _checker(_github(200, _release('v1.2.0'))).check(), isA<UpToDate>());
    });

    test('no release published yet: up to date', () async {
      expect(await _checker(_github(404, {'message': 'Not Found'})).check(), isA<UpToDate>());
    });

    test('rate limited, unreadable or unreachable: unknown — never "à jour"', () async {
      expect(await _checker(_github(403, {'message': 'rate limit'})).check(), isA<UpdateUnknown>());
      expect(await _checker(_github(200, 'not json')).check(), isA<UpdateUnknown>());
      expect(await _checker(_github(200, {'no': 'tag'})).check(), isA<UpdateUnknown>());
      final down = MockClient((_) async => throw http.ClientException('offline'));
      expect(await _checker(down).check(), isA<UpdateUnknown>());
    });

    test('a GitHub that never answers is given up on', () async {
      final hanging = MockClient((_) => Completer<http.Response>().future);
      final status = await _checker(hanging).check().timeout(
            UpdateChecker.timeout + const Duration(seconds: 2),
          );
      expect(status, isA<UpdateUnknown>());
    }, timeout: const Timeout(Duration(seconds: 20)));
  });

  group('launch notice, once per version', () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('offered the first time, not again for the same version, again for the next one', () async {
      expect(await UpdateChecker.shouldNotify('1.4.0'), isTrue);
      await UpdateChecker.markNotified('1.4.0');
      expect(await UpdateChecker.shouldNotify('1.4.0'), isFalse);
      expect(await UpdateChecker.shouldNotify('1.5.0'), isTrue);
    });
  });
}
