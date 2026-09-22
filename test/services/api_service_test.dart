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
}
