import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:lunavaritia/config/api_config.dart';
import 'package:lunavaritia/models/box_item.dart';
import 'package:lunavaritia/services/api_service.dart';
import 'package:lunavaritia/services/http_transport.dart';
import 'package:lunavaritia/services/inbox_api.dart';
import 'package:lunavaritia/services/lunacedia_client.dart';
import 'package:lunavaritia/services/planning_api.dart';

// One client for the planning: LunAcedia's /api/planning standalone, the hub's /api/mobile/planning wired. A
// conflict's ways out ride on its box item and are chosen there.

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

  test('reads the planning: a day stays a day, a time is local, a task keeps its day and its state', () async {
    final snap = await withServer(
      (_) => {
        'events': [
          {'id': 'p/a', 'title': 'Dentiste', 'start': '2026-10-20T08:00:00.000Z', 'end': '2026-10-20T09:00:00.000Z', 'allDay': false},
          {'id': 'p/b', 'title': 'Anniversaire', 'start': '2026-10-23', 'end': '2026-10-24', 'allDay': true},
        ],
        'tasks': [
          {'id': 'l/x', 'title': 'Courses', 'listTitle': 'Maison', 'due': '2026-10-22', 'status': 'open'},
          {'id': 'l/y', 'title': 'Vieux', 'listTitle': 'Maison', 'status': 'completed'},
        ],
        'conflicts': [
          {'id': 'c1', 'eventIds': ['p/a', 'p/c'], 'from': '2026-10-20T08:30:00.000Z', 'to': '2026-10-20T09:00:00.000Z'},
        ],
        'complete': true,
      },
      () => PlanningApi.lunacedia(transport).snapshot(),
    );
    expect(line(sent.single), 'GET /api/planning');
    expect(snap.events.first.start, DateTime.utc(2026, 10, 20, 8).toLocal());
    expect(snap.events.last.start, DateTime(2026, 10, 23));
    expect(snap.events.last.on(DateTime(2026, 10, 23)), isTrue);
    expect(snap.events.last.on(DateTime(2026, 10, 24)), isFalse);
    expect(snap.tasksOn(DateTime(2026, 10, 22)).single.title, 'Courses');
    expect(snap.tasks.last.open, isFalse);
    expect(snap.late(DateTime(2026, 10, 24)).single.daysLate(DateTime(2026, 10, 24)), 2);
    expect(snap.conflictsOn(DateTime.utc(2026, 10, 20, 8).toLocal()).single.id, 'c1');
    expect(snap.complete, isTrue);
  });

  test('on the hub: the same planning and « Fait » under /api/mobile/planning, the task id encoded', () async {
    final api = PlanningApi.hub(transport);
    await withServer((_) => {'events': [], 'tasks': [], 'conflicts': [], 'complete': true, 'ok': true}, () async {
      await api.snapshot();
      await api.done('list/task');
    });
    expect(sent.map(line), ['GET /api/mobile/planning', 'POST /api/mobile/planning/tasks/list%2Ftask/done']);
  });

  test('each client reaches the planning on its own server', () {
    final config = ApiConfig.forTest(baseUrl: 'http://srv:4001');
    expect(LunAcediaClient(config).planning.path, '/api/planning');
    expect(ApiService(config).planning.path, '/api/mobile/planning');
  });

  test("a conflict's box item carries what would move and where; its ways out are gestures of the box", () async {
    final item = BoxItem.fromJson({
      'dedupeKey': 'conflict:p/a|p/b',
      'type': 'planning.conflict',
      'source': 'calendar',
      'title': 'Conflit — Dentiste et Appel Léa',
      'priority': 'urgent',
      'ts': 0,
      'read': false,
      'meta': {
        'conflict': true,
        'movingTitle': 'Appel Léa',
        'solutions': [
          {'eventId': 'p/b', 'start': '2026-10-20T09:00:00.000Z', 'end': '2026-10-20T10:00:00.000Z'},
        ],
      },
    });
    expect(item.conflict!.moving, 'Appel Léa');
    expect(item.conflict!.slots.single.start, DateTime.utc(2026, 10, 20, 9).toLocal());
    expect(item.gestures, isEmpty);

    await withServer((_) => {'ok': true}, () async {
      await InboxApi.hub(transport).solve(item.key, 0);
      await InboxApi.lunacedia(transport).leave(item.key);
    });
    expect(sent.map(line), [
      'POST /api/mobile/inbox/conflict%3Ap%2Fa%7Cp%2Fb/solve-0',
      'POST /api/inbox/conflict%3Ap%2Fa%7Cp%2Fb/leave',
    ]);
  });
}
