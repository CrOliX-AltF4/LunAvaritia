import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/services/api_service.dart';
import 'package:lunavaritia/services/backend_error.dart';
import 'package:lunavaritia/services/http_transport.dart';
import 'package:lunavaritia/services/lunacedia_client.dart';
import 'package:lunavaritia/services/validation_api.dart';

// « À valider »: LunAcedia's pending writes (both modes) and, wired, the memory proposals.

void main() {
  late List<http.Request> sent;

  Future<T> withServer<T>(Object? Function(http.Request req) answer, Future<T> Function() run, {int status = 200}) =>
      http.runWithClient(
        run,
        () => MockClient((req) async {
          sent.add(req);
          final body = answer(req);
          return http.Response(body == null ? '' : jsonEncode(body), body == null ? 204 : status,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

  setUp(() => sent = []);

  final transport = HttpTransport(ApiConfig.forTest(baseUrl: 'http://srv:4001', token: 'dev'));
  final deadline = DateTime(2026, 10, 5, 14, 30);

  test("reads LunAcedia's pending writes, in its own words, oldest first", () async {
    final writes = await withServer(
      (_) => [
        {
          'id': 'b',
          'connector': 'Gmail',
          'action': {'kind': 'reply'},
          'summary': 'Répondre à un mail — Noté.',
          'createdAt': 2,
          'expiresAt': deadline.millisecondsSinceEpoch,
          'untrusted': true,
          'origin': 'agent'
        },
        {
          'id': 'a',
          'connector': 'Tasks',
          'action': {'kind': 'create_task'},
          'createdAt': 1
        },
      ],
      () => ValidationApi.lunacedia(transport).actions(),
    );
    expect(sent.single.url.path, '/api/actions/pending');
    expect(writes.map((w) => w.id), ['a', 'b']);
    final reply = writes.last;
    expect(reply.summary, 'Répondre à un mail — Noté.');
    expect(reply.expiresAt, deadline);
    expect(reply.untrusted, isTrue);
    expect(reply.byAgent, isTrue);
    expect(writes.first.summary, 'create_task');
  });

  test('on the hub: the list is wrapped, decisions and proposals under /api/mobile', () async {
    final api = ValidationApi.hub(transport);
    await withServer((req) {
      if (req.url.path == '/api/mobile/actions/pending') return {'actions': []};
      if (req.url.path == '/api/mobile/proposals') {
        return {
          'proposals': [
            {
              'id': 'p1',
              'ts': 1,
              'origin': 'mobile',
              'payload': {'kind': 'add_fact', 'speakerId': 'master', 'text': 'Le syndic écrit par mail.'}
            },
            {
              'id': 'p2',
              'ts': 2,
              'origin': 'chat',
              'payload': {'kind': 'upsert_opinion', 'subject': 'Le thé', 'position': 'Bon le matin', 'intensity': 2}
            },
          ],
        };
      }
      return null;
    }, () async {
      expect(await api.actions(), isEmpty);
      await api.decide('a/1', confirm: true);
      final proposals = await api.proposals();
      expect(proposals.map((p) => p.text), ['Le syndic écrit par mail.', 'Le thé — Bon le matin']);
      expect(proposals.first.editableText, 'Le syndic écrit par mail.');
      expect(proposals.last.editableText, 'Bon le matin');
      await api.approve('p1', text: 'Corrigé.');
      await api.approve('p2');
      await api.reject('p1');
    });
    expect(sent.map((r) => '${r.method} ${r.url.path}${r.body.isEmpty ? '' : ' ${r.body}'}'), [
      'GET /api/mobile/actions/pending',
      'POST /api/mobile/actions/a%2F1/confirm',
      'GET /api/mobile/proposals',
      'POST /api/mobile/proposals/p1/approve {"text":"Corrigé."}',
      'POST /api/mobile/proposals/p2/approve',
      'POST /api/mobile/proposals/p1/reject',
    ]);
  });

  test('standalone has no memory to validate', () async {
    final api = ValidationApi.lunacedia(transport);
    expect(api.hasMemory, isFalse);
    expect(await api.proposals(), isEmpty);
    expect(await api.unasked(), isEmpty);
    expect(sent, isEmpty);
  });

  test('wired: a memory question carries the fact it is about', () async {
    final list = await withServer(
      (_) => {
        'proposals': [
          {'id': 'p1', 'origin': 'chat', 'ts': 1, 'conflictText': 'Habite à Lyon', 'payload': {'kind': 'add_fact', 'speakerId': 'master', 'text': 'Habite à Paris'}},
          {'id': 'p2', 'origin': 'chat', 'ts': 2, 'duplicateText': 'Joue à osu!', 'payload': {'kind': 'add_fact', 'speakerId': 'master', 'text': 'Joue à osu'}},
        ]
      },
      () => ValidationApi.hub(transport).proposals(),
    );
    expect(list.map((p) => (p.conflictText, p.duplicateText)), [('Habite à Lyon', null), (null, 'Joue à osu!')]);
  });

  test('wired: reads what was written unasked, and « Annuler » posts to its own path', () async {
    final facts = await withServer(
      (_) => {
        'facts': [
          {'speakerId': 'master', 'id': 'f 1', 'text': 'Aime le thé', 'timestamp': 5, 'source': 'J’aime le thé'},
        ]
      },
      () => ValidationApi.hub(transport).unasked(),
    );
    expect(facts.single.source, 'J’aime le thé');
    expect(sent.last.url.path, '/api/mobile/unasked');
    await withServer((_) => {'ok': true}, () => ValidationApi.hub(transport).undo(facts.single));
    expect(sent.last.method, 'POST');
    expect(sent.last.url.toString(), 'http://srv:4001/api/mobile/unasked/master/f%201/undo');
  });

  test('says why a decision was refused', () async {
    await expectLater(
      withServer((_) => {'error': 'Action failed: [Gmail] mail no longer exists'},
          () => ValidationApi.lunacedia(transport).decide('a1', confirm: true),
          status: 502),
      throwsA(isA<BackendError>().having((e) => e.detail, 'detail', contains('mail no longer exists'))),
    );
  });

  test('each client validates on its own server', () {
    final config = ApiConfig.forTest(baseUrl: 'http://srv:4001');
    expect(LunAcediaClient(config).validation.hasMemory, isFalse);
    expect(ApiService(config).validation.hasMemory, isTrue);
  });
}
