import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/models/box_item.dart';
import 'package:lunavaritia/models/mail_sort.dart';
import 'package:lunavaritia/services/api_service.dart';
import 'package:lunavaritia/services/http_transport.dart';
import 'package:lunavaritia/services/inbox_api.dart';
import 'package:lunavaritia/services/lunacedia_client.dart';
import 'package:lunavaritia/services/mail_sort_api.dart';

// Sorting mail: LunAcedia's classes, rules and kept-out mail — standalone under /api, wired under /api/mobile.

void main() {
  late List<http.Request> sent;

  Future<T> withServer<T>(Object? Function(http.Request req) answer, Future<T> Function() run) => http.runWithClient(
        run,
        () => MockClient((req) async {
          sent.add(req);
          return http.Response(jsonEncode(answer(req)), 200, headers: {'content-type': 'application/json; charset=utf-8'});
        }),
      );

  setUp(() => sent = []);

  final transport = HttpTransport(ApiConfig.forTest(baseUrl: 'http://srv:4001', token: 'acd_dev_x'));
  String line(http.Request r) => '${r.method} ${r.url.toString().replaceFirst('http://srv:4001', '')}';

  final classesJson = {
    'classes': {
      'pro': {'visible': true, 'ai': true, 'rings': true},
      'perso': {'visible': true, 'ai': false, 'rings': true},
      'notification': {'visible': true, 'ai': true, 'rings': false},
      'pub': {'visible': false, 'ai': false, 'rings': false},
      'inconnu': {'visible': true, 'ai': true, 'rings': true},
    },
    'personalSenders': ['maman@famille.fr'],
    'counts': {'pub': 9},
    'mailboxes': [
      {'address': 'pro@espi.fr', 'mailClass': 'pro'},
      {'address': 'autre@x.fr', 'mailClass': null},
    ],
  };

  test('reads the classes and sets one switch; on the hub the same under /api/mobile', () async {
    final api = MailSortApi.hub(transport);
    final config = await withServer((_) => classesJson, () async {
      await api.setClass(MailClass.perso, 'ai', true);
      return api.config();
    });
    expect(sent.map(line), ['PATCH /api/mobile/config/mail-classes', 'GET /api/mobile/config/mail-classes']);
    expect(jsonDecode(sent.first.body), {
      'classes': {
        'perso': {'ai': true},
      },
    });
    expect(config.classes[MailClass.perso]!.ai, isFalse);
    expect(config.classes[MailClass.pub]!.visible, isFalse);
    expect(config.counts[MailClass.pub], 9);
    expect(config.personalSenders, ['maman@famille.fr']);
    expect(config.mailboxes.map((b) => (b.address, b.mailClass)), [('pro@espi.fr', MailClass.pro), ('autre@x.fr', null)]);

    sent.clear();
    await withServer((_) => classesJson, () => api.setMailboxes(config.mailboxes));
    expect(jsonDecode(sent.single.body), {
      'mailboxes': [
        {'address': 'pro@espi.fr', 'mailClass': 'pro'},
        {'address': 'autre@x.fr', 'mailClass': null},
      ],
    });
  });

  test('shows only the rules that classify, and says why a mail was kept out', () async {
    final api = MailSortApi.lunacedia(transport);
    final result = await withServer(
      (req) => req.url.path.endsWith('/rules')
          ? {
              'rules': [
                {
                  'id': 'r1',
                  'name': 'ESPI',
                  'enabled': true,
                  'conditions': [
                    {'field': 'from', 'op': 'domain', 'value': 'espi.fr'},
                  ],
                  'actions': [
                    {'type': 'classify', 'mailClass': 'pro'},
                  ],
                },
                {
                  'id': 'r2',
                  'name': 'AliExpress',
                  'enabled': true,
                  'conditions': [],
                  'actions': [
                    {'type': 'drop'},
                  ],
                },
              ],
            }
          : {
              'total': 3,
              'entries': [
                for (final id in ['class:pub', 'r2', 'gone'])
                  {
                    'ruleId': id,
                    'event': {'dedupeKey': 'email-$id', 'title': 'T', 'meta': {'from': 'X'}},
                  },
              ],
            },
      () async {
        final rules = await api.rules();
        return (rules: rules, kept: await api.keptOut(rules.names));
      },
    );
    expect(sent.map(line), ['GET /api/guard/rules', 'GET /api/guard/journal?limit=100']);
    expect(result.rules.rules.single.when, 'De « espi.fr »');
    expect(result.rules.rules.single.mailClass, MailClass.pro);
    expect(result.kept.items.map((k) => k.why),
        ['classe Pub (masquée)', 'règle « AliExpress »', 'règle supprimée']);
  });

  test('switches one rule, restores a mail, and « Classer… » files it — for its sender too', () async {
    await withServer((_) => {'ok': true}, () async {
      await MailSortApi.hub(transport).setRule('r 1', false);
      await MailSortApi.hub(transport).restore('email-9');
      await InboxApi.lunacedia(transport).classify('email-a/b', MailClass.pro, always: true);
    });
    expect(sent.map(line), [
      'PATCH /api/mobile/guard/rules/r%201',
      'POST /api/mobile/guard/journal/restore',
      'POST /api/inbox/email-a%2Fb/class-pro',
    ]);
    expect(jsonDecode(sent[1].body), {'dedupeKey': 'email-9'});
    expect(jsonDecode(sent[2].body), {'always': true});
  });

  test('each client reaches the sorting on its own server; an item says its class and whether a model may read it',
      () {
    final config = ApiConfig.forTest(baseUrl: 'http://srv:4001');
    expect(LunAcediaClient(config).mailSort.prefix, '/api');
    expect(ApiService(config).mailSort.prefix, '/api/mobile');
    final item = BoxItem.fromJson({
      'dedupeKey': 'email-1',
      'type': 'email.received',
      'source': 'email',
      'title': 'Soldes',
      'priority': 'info',
      'ts': 0,
      'ai': false,
      'meta': {'mailClass': 'pub'},
    });
    expect(item.mailClass, MailClass.pub);
    expect(item.aiReadable, isFalse);
    expect(BoxItem.fromJson({'dedupeKey': 'x', 'source': 'email'}).aiReadable, isTrue);
  });
}
