import 'package:flutter_test/flutter_test.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/services/connection_controller.dart';

import '../support/fakes.dart';

// The notification token lives with one server, the one the app talks to: a move registers it with the new server
// first, then lets the old one go — and a server out of reach is retried, never forgotten (ADR-034 D2, D3).

final standalone = ApiConfig.fromForm(acediaUrl: 'http://acedia:4001', acediaToken: 'acd_dev_phone', hubUrl: '', hubToken: '');
final wired = ApiConfig.fromForm(acediaUrl: 'http://acedia:4001', acediaToken: 'acd_dev_phone', hubUrl: 'http://hub:3333', hubToken: 'hub_dev_phone');

void main() {
  late FakePushServers servers;
  late MemoryPendingRelease pending;
  late List<ApiConfig> saved;

  ConnectionController controllerOn(ApiConfig config) => ConnectionController(
        config: config,
        persist: (c) async => saved.add(c),
        pending: pending,
        pushToken: () async => 'fcm-1',
        clientFor: servers.clientFor,
      );

  setUp(() {
    servers = FakePushServers();
    pending = MemoryPendingRelease();
    saved = [];
  });

  test('a move applies at once, registers with the new server, then lets the old one go — both ways', () async {
    final c = controllerOn(standalone);
    var notified = 0;
    c.addListener(() => notified++);

    await c.apply(wired);
    expect(saved.single, same(wired));
    expect(c.wired, isTrue);
    expect(notified, greaterThan(0));
    expect(servers.calls, ['register http://hub:3333 fcm-1', 'release http://acedia:4001 acd_dev_phone']);

    servers.calls.clear();
    await c.apply(standalone);
    expect(servers.calls, ['register http://acedia:4001 fcm-1', 'release http://hub:3333 hub_dev_phone']);
    expect(c.releasePending, isFalse);
  });

  test('the server left out of reach: the release is kept and retried at the next start', () async {
    servers.unreachable.add('http://acedia:4001');
    final c = controllerOn(standalone);
    await c.apply(wired);
    expect(c.releasePending, isTrue);
    expect(pending.held?.baseUrl, 'http://acedia:4001');

    servers.unreachable.clear();
    servers.calls.clear();
    final restarted = controllerOn(wired);
    await restarted.settle();
    expect(servers.calls, ['register http://hub:3333 fcm-1', 'release http://acedia:4001 acd_dev_phone']);
    expect(restarted.releasePending, isFalse);
    expect(pending.held, isNull);
  });

  test('the new server out of reach: the old one keeps the notifications until the new one has the token', () async {
    servers.unreachable.add('http://hub:3333');
    final c = controllerOn(standalone);
    await c.apply(wired);
    expect(servers.calls, isEmpty);
    expect(c.releasePending, isTrue);
  });

  test('a renewed token goes to the server the app talks to now, not the one at launch', () async {
    final c = controllerOn(standalone);
    await c.apply(wired);
    servers.calls.clear();
    await c.registerToken('fcm-2');
    expect(servers.calls, ['register http://hub:3333 fcm-2']);
  });

  test('saving the same server lets nothing go', () async {
    final c = controllerOn(wired);
    await c.apply(ApiConfig.fromForm(acediaUrl: 'http://acedia:4001', acediaToken: 'acd_dev_phone', hubUrl: 'http://hub:3333', hubToken: 'hub_dev_phone'));
    expect(servers.calls, ['register http://hub:3333 fcm-1']);
  });
}
