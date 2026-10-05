import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/services/push_service.dart';

// Moving to a hub, the phone takes itself off LunAcedia's notifications, or they come twice.

void main() {
  late List<http.Request> sent;

  Future<void> withServer(int status, Future<void> Function() run) => http.runWithClient(
        run,
        () => MockClient((req) async {
          sent.add(req);
          return http.Response('', status);
        }),
      );

  setUp(() => sent = []);

  test('asks LunAcedia to stop its notifications to this phone, with its own token', () async {
    await withServer(204, () => leaveStandalonePushAt(ApiConfig.forTest(baseUrl: 'http://acedia:4001', token: 'acd_dev_phone')));
    expect(sent.single.method, 'DELETE');
    expect(sent.single.url.toString(), 'http://acedia:4001/api/devices/push-token');
    expect(sent.single.headers['Authorization'], 'Bearer acd_dev_phone');
  });

  test('calls nothing when the phone never talked to LunAcedia', () async {
    await withServer(204, () => leaveStandalonePushAt(ApiConfig.forTest(baseUrl: '', token: '')));
    expect(sent, isEmpty);
  });

  test('never fails the move to the hub when LunAcedia is out of reach', () async {
    await withServer(503, () => leaveStandalonePushAt(ApiConfig.forTest(baseUrl: 'http://acedia:4001', token: 'acd_dev_phone')));
    expect(sent, hasLength(1));
  });
}
