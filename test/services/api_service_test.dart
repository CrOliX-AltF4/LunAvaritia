import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/services/api_service.dart';

void main() {
  group('ApiService.getDigest (ADR-013 I4)', () {
    test('calls /api/mobile/digest — the path a MOBILE_API_KEY-only caller can reach', () async {
      Uri? calledUri;
      final mockClient = MockClient((request) async {
        calledUri = request.url;
        return http.Response(jsonEncode({'response': 'Digest text'}), 200);
      });

      final service = ApiService(
        ApiConfig.forTest(baseUrl: 'http://natsume.local:3333', token: 'k', backendMode: 'lunacedia'),
      );

      final result = await http.runWithClient(
        () => service.getDigest(),
        () => mockClient,
      );

      expect(result, 'Digest text');
      expect(calledUri?.path, '/api/mobile/digest');
    });
  });

  // ADR-020 §5.10 M4c — the box comes from LunAcedia; the hub's own alerts (system, spend, Discord) stay apart. Its
  // copies of box items (sourceKey) are left out: the box shows the items themselves.
  group('ApiService hub alerts', () {
    test("keeps only the hub's own alerts, and marks one read", () async {
      final calls = <String>[];
      final mockClient = MockClient((request) async {
        calls.add('${request.method} ${request.url.path}');
        if (request.method == 'GET') {
          return http.Response(
              jsonEncode({
                'alerts': [
                  {'id': 'h1', 'type': 'system', 'title': 'Dépense', 'ts': 1, 'read': false},
                  {'id': 'c1', 'type': 'email', 'title': 'Copie', 'ts': 2, 'read': false, 'sourceKey': 'email-1'},
                ],
              }),
              200);
        }
        return http.Response(jsonEncode({'ok': true}), 200);
      });
      final service = ApiService(ApiConfig.forTest(baseUrl: 'http://hub:3333', token: 'k', backendMode: 'natsume'));

      final alerts = await http.runWithClient(() => service.hubAlerts(), () => mockClient);
      await http.runWithClient(() => service.markHubAlertRead('h1'), () => mockClient);

      expect(alerts.map((a) => a.id), ['h1']);
      expect(calls.first, startsWith('GET /api/mobile/alerts'));
      expect(calls.last, 'POST /api/mobile/alerts/h1/read');
    });
  });
}
