import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/services/http_transport.dart';
import 'package:lunavaritia/services/topic_api.dart';

// ADR-020 amendment 1 — one client for the topics contract: LunAcedia's paths standalone, the hub's when wired.

Map<String, dynamic> _turn({Map<String, dynamic>? agent}) => {
      'conversation': {
        'id': 't1',
        'title': 'Syndic',
        'createdAt': '2026-10-01T08:00:00.000Z',
        'updatedAt': '2026-10-01T08:01:00.000Z',
        'archived': false,
        'messageCount': 2,
      },
      'userMessage': {'id': 'm1', 'role': 'user', 'text': 'Un mail urgent ?', 'at': '2026-10-01T08:00:00.000Z', 'about': 'email-1'},
      'message': {
        'id': 'm2',
        'role': 'assistant',
        'text': 'Oui.',
        'at': '2026-10-01T08:01:00.000Z',
        'external': true,
        if (agent != null) 'agent': agent,
      },
    };

void main() {
  late List<http.Request> sent;

  Future<T> withServer<T>(Object? Function(http.Request req) answer, Future<T> Function() run) => http.runWithClient(
        run,
        () => MockClient((req) async {
          sent.add(req);
          final body = answer(req);
          return http.Response(body == null ? '' : jsonEncode(body), body == null ? 204 : 200,
              headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

  setUp(() => sent = []);

  final transport = HttpTransport(ApiConfig.forTest(baseUrl: 'http://srv:4001', token: 'acd_dev_x'));

  test('opens a topic about a box item, on LunAcedia, and reads the structured answer', () async {
    final api = TopicApi.lunacedia(transport);
    final result = await withServer(
      (_) => _turn(agent: {
        'version': 1,
        'status': 'done',
        'items': [
          {'key': 'email-1', 'source': 'email', 'title': 'Colonne d’eau', 'from': 'Syndic', 'priority': 'urgent', 'at': '2026-10-01T07:00:00.000Z'},
        ],
        'actions': [
          {'kind': 'reply', 'connector': 'gmail', 'status': 'pending', 'id': 'a1', 'action': {'kind': 'reply', 'sourceId': 'x', 'body': 'Noté.'}},
          {'kind': 'propose_memory', 'connector': 'memory', 'status': 'pending', 'id': 'p1', 'action': {'text': 'fait'}},
        ],
      }),
      () => api.open('Un mail urgent ?', aboutKey: 'email-1'),
    );

    expect(sent.single.method, 'POST');
    expect(sent.single.url.toString(), 'http://srv:4001/api/conversations');
    expect(sent.single.headers['Authorization'], 'Bearer acd_dev_x');
    expect(jsonDecode(sent.single.body), {'text': 'Un mail urgent ?', 'about': {'key': 'email-1'}});

    expect(result.topic.title, 'Syndic');
    expect(result.userMessage.about, 'email-1');
    expect(result.message.external, isTrue);
    final agent = result.message.agent!;
    expect(agent.items.single.key, 'email-1');
    expect(agent.items.single.from, 'Syndic');
    expect(agent.actions.first.isDecidable, isTrue);
    expect(agent.actions.first.preview, 'Noté.');
    expect(agent.actions.first.label, 'Répondre au mail');
    expect(agent.actions.last.isMemoryProposal, isTrue);
    expect(agent.actions.last.isDecidable, isFalse);
  });

  test("uses the hub's paths when wired, for topics and for decisions", () async {
    final api = TopicApi.hub(transport);
    await withServer((_) => {'conversations': []}, () => api.list(archived: true));
    await withServer((_) => null, () => api.decide('a/1', confirm: true));
    await withServer((_) => null, () => api.decide('a1', confirm: false));

    expect(sent[0].url.toString(), 'http://srv:4001/api/mobile/conversations?archived=true');
    expect(sent[1].url.toString(), 'http://srv:4001/api/mobile/actions/a%2F1/confirm');
    expect(sent[2].url.toString(), 'http://srv:4001/api/mobile/actions/a1/cancel');
  });

  test('pages backwards from a message, renames and archives with PATCH, deletes', () async {
    final api = TopicApi.lunacedia(transport);
    final page = await withServer(
      (_) => {
        'conversation': _turn()['conversation'],
        'messages': [_turn()['userMessage'], _turn()['message']],
        'hasMore': true,
      },
      () => api.page('t 1', before: 'm9'),
    );
    expect(sent.last.url.toString(), 'http://srv:4001/api/conversations/t%201?limit=30&before=m9');
    expect(page.messages.map((m) => m.id), ['m1', 'm2']);
    expect(page.hasMore, isTrue);

    final renamed = await withServer((_) => {'conversation': {..._turn()['conversation'] as Map<String, dynamic>, 'archived': true}},
        () => api.update('t1', title: 'Neuf', archived: true));
    expect(sent.last.method, 'PATCH');
    expect(jsonDecode(sent.last.body), {'title': 'Neuf', 'archived': true});
    expect(renamed.archived, isTrue);

    await withServer((_) => null, () => api.delete('t1'));
    expect(sent.last.method, 'DELETE');
    expect(sent.last.url.path, '/api/conversations/t1');
  });

  test('sends a turn in a topic', () async {
    final api = TopicApi.lunacedia(transport);
    await withServer((_) => _turn(), () => api.send('t1', 'Et le deuxième ?'));
    expect(sent.single.url.path, '/api/conversations/t1/messages');
    expect(jsonDecode(sent.single.body), {'text': 'Et le deuxième ?'});
  });
}
