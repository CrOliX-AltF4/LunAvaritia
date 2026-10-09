import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/providers/topic_controller.dart';
import 'package:lunavaritia/services/change_stream.dart';

import '../support/fakes.dart';

// Lot S — the app follows what changed on its server while it is in front.

http.StreamedResponse sse(String body, {int status = 200}) =>
    http.StreamedResponse(Stream.value(utf8.encode(body)), status);

void main() {
  group('ChangeEventParser', () {
    test('reads the change events, split anywhere, and skips heartbeats, retry and other events', () {
      final parser = ChangeEventParser();
      final out = [
        ...parser.add('retry: 5000\n\n: ping\n\nevent: change\ndata: {"scope":"bo'),
        ...parser.add('x","key":"email-1","settled":true,"at":1}\n\nevent: other\ndata: {"scope":"box"}\n\n'),
        ...parser.add('event: change\r\ndata: not json\r\n\r\nevent: change\ndata: {"scope":"actions","at":2}\n\n'),
      ];
      expect(out.map((c) => (c.scope, c.key, c.settled)), [('box', 'email-1', true), ('actions', null, false)]);
    });
  });

  group('ChangeStream', () {
    test("wired, it reads the hub's /api/mobile/changes with the device's token", () async {
      final requests = <http.BaseRequest>[];
      final stream = ChangeStream(
        ApiConfig.forTest(baseUrl: 'http://hub', token: 'dev-1', backendMode: 'natsume'),
        client: () => MockClient.streaming((request, _) async {
          requests.add(request);
          return sse('event: change\ndata: {"scope":"box","key":"email-1","at":1}\n\n');
        }),
        backoff: (_) => const Duration(hours: 1),
      );
      final first = stream.changes.first;
      stream.start();
      final change = await first;
      stream.stop();
      expect(change.key, 'email-1');
      expect(requests.single.url.toString(), 'http://hub/api/mobile/changes');
      expect(requests.single.headers['Authorization'], 'Bearer dev-1');
    });

    test("standalone, it reads LunAcedia's /api/changes", () async {
      final urls = <String>[];
      final stream = ChangeStream(
        ApiConfig.forTest(baseUrl: 'http://acedia', token: 'dev-2'),
        client: () => MockClient.streaming((request, _) async {
          urls.add(request.url.toString());
          return sse('event: change\ndata: {"scope":"actions","at":1}\n\n');
        }),
        backoff: (_) => const Duration(hours: 1),
      );
      final first = stream.changes.first;
      stream.start();
      await first;
      stream.stop();
      expect(urls, ['http://acedia/api/changes']);
    });

    test('a dropped stream is opened again after its wait; a refused token stops it', () async {
      var calls = 0;
      final stream = ChangeStream(
        ApiConfig.forTest(baseUrl: 'http://acedia', token: 'dev-3'),
        client: () => MockClient.streaming((_, __) async {
          calls++;
          return calls == 1 ? sse(': ping\n\n') : sse('', status: 401);
        }),
        backoff: (_) => Duration.zero,
      );
      stream.start();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(calls, 2);
      expect(stream.running, isFalse);
    });

    test('nothing is opened without an address or a token', () {
      var calls = 0;
      final stream = ChangeStream(
        ApiConfig.forTest(baseUrl: 'http://acedia'),
        client: () => MockClient.streaming((_, __) async {
          calls++;
          return sse('');
        }),
      );
      stream.start();
      expect(stream.running, isFalse);
      expect(calls, 0);
    });
  });

  test('ChangeBursts calls each scope once per burst, with everything the burst carried', () async {
    final calls = <(String, int)>[];
    final bursts = ChangeBursts((scope, changes) => calls.add((scope, changes.length)),
        window: const Duration(milliseconds: 20));
    bursts.add(const Change(scope: 'box', key: 'a'));
    bursts.add(const Change(scope: 'box', key: 'b'));
    bursts.add(const Change(scope: 'actions'));
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(calls, unorderedEquals([('box', 2), ('actions', 1)]));
  });

  group('open topic', () {
    test('reads itself again when it changed elsewhere or an action was decided — not for another topic', () async {
      final backend = FakeBackend();
      backend.topics.messages['t1'] = [userMessage('m1', 'Bonjour'), answer('m2', 'Salut')];
      final changes = StreamController<Change>.broadcast();
      final controller = TopicController(backend, 't1', changes: changes.stream);
      await controller.load();
      expect(controller.messages, hasLength(2));

      backend.topics.messages['t1'] = [...backend.topics.messages['t1']!, answer('m3', 'Fait au panel')];
      changes.add(const Change(scope: 'topics', key: 't2'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(controller.messages, hasLength(2));

      changes.add(const Change(scope: 'topics', key: 't1'));
      await Future<void>.delayed(const Duration(milliseconds: 400));
      expect(controller.messages.last.text, 'Fait au panel');

      controller.dispose();
      await changes.close();
    });
  });
}
