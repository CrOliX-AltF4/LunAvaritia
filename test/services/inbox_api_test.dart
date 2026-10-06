import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/models/box_item.dart';
import 'package:lunavaritia/services/api_service.dart';
import 'package:lunavaritia/services/backend_error.dart';
import 'package:lunavaritia/services/http_transport.dart';
import 'package:lunavaritia/services/inbox_api.dart';
import 'package:lunavaritia/services/lunacedia_client.dart';

// One client for the box: LunAcedia's /api/inbox standalone, the hub's /api/mobile/inbox wired.

Map<String, dynamic> _mail({bool read = false}) => {
      'type': 'email.received',
      'ts': 1759651200000,
      'source': 'email',
      'title': "Intervention colonne d'eau",
      'body': 'Bonjour, une coupure…',
      'url': 'https://mail.google.com/mail/u/0/#inbox/m1',
      'priority': 'urgent',
      'dedupeKey': 'email-m1',
      'meta': {'from': 'Syndic <syndic@example.com>', 'messageId': 'm1'},
      'read': read,
    };

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

  final transport = HttpTransport(ApiConfig.forTest(baseUrl: 'http://srv:4001', token: 'acd_dev_x'));

  test('reads the box from LunAcedia: items with their key, sender and state, and the unread count', () async {
    final page = await withServer((_) => {'items': [_mail(), _mail(read: true)..['dedupeKey'] = 'email-m2'], 'unread': 1},
        () => InboxApi.lunacedia(transport).list());
    expect(sent.single.method, 'GET');
    expect(sent.single.url.path, '/api/inbox');
    expect(page.unread, 1);
    final first = page.items.first;
    expect(first.key, 'email-m1');
    expect(first.source, BoxSource.email);
    expect(first.title, "Intervention colonne d'eau");
    expect(first.from, 'Syndic <syndic@example.com>');
    expect(first.priority, BoxPriority.urgent);
    expect(first.read, isFalse);
    expect(first.ts, DateTime.fromMillisecondsSinceEpoch(1759651200000));
    expect(first.url, 'https://mail.google.com/mail/u/0/#inbox/m1');
    expect(page.items.last.read, isTrue);
  });

  test('opens an item: the full text comes back and it is now read', () async {
    final result = await withServer((_) => {'ok': true, 'change': 'read', 'body': 'Le texte entier.'},
        () => InboxApi.lunacedia(transport).gesture('email-m1', BoxGesture.open));
    expect(sent.single.method, 'POST');
    expect(sent.single.url.path, '/api/inbox/email-m1/open');
    expect(result.change, BoxChange.read);
    expect(result.body, 'Le texte entier.');
  });

  test('on the hub: the same box, gestures, trash and restore under /api/mobile/inbox, keys encoded', () async {
    final api = InboxApi.hub(transport);
    await withServer((req) {
      if (req.url.path.endsWith('/trash') && req.method == 'GET') {
        return {'items': [{'id': 'm9', 'title': 'Vieux mail', 'from': 'Banque', 'ts': 1759651200000}]};
      }
      return req.method == 'GET' ? {'items': [], 'unread': 0} : {'ok': true, 'change': 'removed'};
    }, () async {
      await api.list();
      final archived = await api.gesture('email-a/b', BoxGesture.archive);
      expect(archived.change, BoxChange.removed);
      final trash = await api.trash();
      expect(trash.single.id, 'm9');
      expect(trash.single.from, 'Banque');
      await api.restore('m9');
    });
    expect(sent.map((r) => '${r.method} ${r.url.toString().replaceFirst('http://srv:4001', '')}'), [
      'GET /api/mobile/inbox',
      'POST /api/mobile/inbox/email-a%2Fb/archive',
      'GET /api/mobile/inbox/trash',
      'POST /api/mobile/inbox/trash/m9/restore',
    ]);
  });

  test('says why a gesture was refused', () async {
    await expectLater(
      withServer((_) => {'error': 'No gestures for calendar'}, () => InboxApi.lunacedia(transport).gesture('cal-1', BoxGesture.archive),
          status: 400),
      throwsA(isA<BackendError>()
          .having((e) => e.kind, 'kind', BackendErrorKind.rejected)
          .having((e) => e.detail, 'detail', contains('No gestures for calendar'))),
    );
  });

  test('each client reaches the box on its own server', () {
    final config = ApiConfig.forTest(baseUrl: 'http://srv:4001');
    expect(LunAcediaClient(config).inbox.path, '/api/inbox');
    expect(ApiService(config).inbox.path, '/api/mobile/inbox');
  });

  test('offers only the gestures the source can do', () {
    BoxItem item(String source) => BoxItem.fromJson(_mail()..['source'] = source);
    expect(item('email').gestures, {BoxGesture.read, BoxGesture.unread, BoxGesture.archive, BoxGesture.spam, BoxGesture.trash});
    expect(item('email').swipe, BoxGesture.archive);
    expect(item('github').gestures, {BoxGesture.done});
    expect(item('github').swipe, BoxGesture.done);
    // "Fait" on a task (M4d): offered, never on a swipe — completing a task by a slip is worse than archiving a mail.
    expect(item('tasks').gestures, {BoxGesture.done});
    expect(item('tasks').swipe, isNull);
    expect(item('calendar').gestures, isEmpty);
    expect(item('calendar').swipe, isNull);
  });
}
