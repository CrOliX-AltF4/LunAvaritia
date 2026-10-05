import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lunavaritia/services/backend_error.dart';
import 'package:lunavaritia/services/pairing.dart';

// The phone gets its own token for a one-time code; it never holds a master secret again.

void main() {
  group('pairingStateOf', () {
    test('tells a device token from an old shared secret and from nothing', () {
      expect(pairingStateOf('acd_dev_abc'), PairingState.paired);
      expect(pairingStateOf('nts_dev_abc'), PairingState.paired);
      expect(pairingStateOf('the-acedia-secret'), PairingState.legacySecret);
      expect(pairingStateOf('  '), PairingState.none);
    });
  });

  group('pairDevice', () {
    Future<String> pairWith(MockClient client, PairingTarget target) => http.runWithClient(
          () => pairDevice(target: target, url: 'http://srv:4001', code: 'ABCD2345', name: 'Pixel'),
          () => client,
        );

    test('sends the code and the name to LunAcedia, with no authorization, and returns the token', () async {
      late http.Request sent;
      final client = MockClient((req) async {
        sent = req;
        return http.Response(jsonEncode({'device': {'id': 'd1'}, 'token': 'acd_dev_xyz'}), 201);
      });
      expect(await pairWith(client, PairingTarget.lunacedia), 'acd_dev_xyz');
      expect(sent.url.toString(), 'http://srv:4001/api/devices/pair');
      expect(sent.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(sent.body), {'code': 'ABCD2345', 'name': 'Pixel'});
    });

    test("uses the hub's own route", () async {
      late Uri url;
      final client = MockClient((req) async {
        url = req.url;
        return http.Response(jsonEncode({'token': 'nts_dev_xyz'}), 201);
      });
      expect(await pairWith(client, PairingTarget.hub), 'nts_dev_xyz');
      expect(url.path, '/api/mobile/devices/pair');
    });

    test('refuses an answer that is not a device token', () async {
      final client = MockClient((_) async => http.Response(jsonEncode({'token': 'master-secret'}), 201));
      await expectLater(pairWith(client, PairingTarget.lunacedia), throwsA(isA<BackendError>()));
    });

    test('speaks of the code when it is refused, of the server when it cannot pair', () async {
      Future<String> messageFor(int status) async {
        try {
          await pairWith(MockClient((_) async => http.Response('{"error":"x"}', status)), PairingTarget.lunacedia);
          return 'no error';
        } catch (e) {
          return pairingErrorMessage(e);
        }
      }

      expect(await messageFor(401), 'Code invalide ou expiré — demandez-en un nouveau.');
      expect(await messageFor(429), "Trop d'essais — attendez quelques minutes.");
      expect(await messageFor(404), 'Ce serveur ne sait pas encore appairer un appareil — mettez-le à jour.');
    });
  });
}
