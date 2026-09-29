import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/services/backend_error.dart';
import 'package:lunavaritia/services/http_transport.dart';

// Live check 2026-09-29 — every failure read "Connexion impossible", a slow server and a wrong token included.

Future<Object?> _errorOf(Future<dynamic> Function() call, MockClient client) async {
  try {
    await http.runWithClient(call, () => client);
    return null;
  } catch (e) {
    return e;
  }
}

void main() {
  final transport = HttpTransport(ApiConfig.forTest(baseUrl: 'http://server.test:4001', token: 't'));

  test('decodes the JSON body and sends the bearer token', () async {
    String? auth;
    final client = MockClient((req) async {
      auth = req.headers['Authorization'];
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    final body = await http.runWithClient(() => transport.get('/api/x'), () => client);
    expect(body, {'ok': true});
    expect(auth, 'Bearer t');
  });

  test('a refused token is "unauthorized", not a connection problem', () async {
    final err = await _errorOf(() => transport.get('/api/x'), MockClient((_) async => http.Response('', 401)));
    expect((err as BackendError).kind, BackendErrorKind.unauthorized);
    expect(err.message, contains('Jeton refusé'));
  });

  test("a server error carries the server's own { error } text", () async {
    final err = await _errorOf(
      () => transport.get('/api/x'),
      MockClient((_) async => http.Response(jsonEncode({'error': 'AI_PROVIDER not configured'}), 503)),
    );
    expect((err as BackendError).kind, BackendErrorKind.server);
    expect(err.message, 'Service indisponible côté serveur (AI_PROVIDER not configured).');
  });

  test('an unreachable server is "unreachable"', () async {
    final err = await _errorOf(
      () => transport.get('/api/x'),
      MockClient((_) async => throw const SocketException('Connection refused')),
    );
    expect((err as BackendError).kind, BackendErrorKind.unreachable);
  });

  test('a server that never answers is a timeout, bounded', () async {
    final err = await _errorOf(
      () => transport.get('/api/x', timeout: const Duration(milliseconds: 50)),
      MockClient((_) => Completer<http.Response>().future),
    );
    expect((err as BackendError).kind, BackendErrorKind.timeout);
  });

  test('a 200 that is not JSON is a bad response', () async {
    final err = await _errorOf(() => transport.get('/api/x'), MockClient((_) async => http.Response('<html>', 200)));
    expect((err as BackendError).kind, BackendErrorKind.badResponse);
  });

  test('no saved address is "not configured", before any network call', () async {
    var called = false;
    final empty = HttpTransport(ApiConfig.forTest(baseUrl: ''));
    final err = await _errorOf(() => empty.get('/api/x'), MockClient((_) async {
      called = true;
      return http.Response('{}', 200);
    }));
    expect((err as BackendError).kind, BackendErrorKind.notConfigured);
    expect(called, isFalse);
  });
}
