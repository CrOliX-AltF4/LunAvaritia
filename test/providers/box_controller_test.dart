import 'package:flutter_test/flutter_test.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/box_item.dart';
import 'package:lunavaritia/providers/box_controller.dart';
import 'package:lunavaritia/services/backend_error.dart';

import '../support/fakes.dart';

// The box on the phone: LunAcedia's items, gestures at the source, the hub's own alerts apart.

BoxItem item(String key, {String source = 'email', String priority = 'normal', bool read = false, int ts = 1}) =>
    BoxItem.fromJson({
      'dedupeKey': key,
      'type': '$source.x',
      'source': source,
      'title': 'Titre $key',
      'priority': priority,
      'ts': ts,
      'read': read,
    });

Alert hubAlert(String id, {bool read = false}) => Alert(
      id: id,
      type: 'system',
      source: AlertSource.system,
      title: 'Alerte $id',
      priority: AlertPriority.normal,
      ts: DateTime(2026, 10, 5),
      read: read,
    );

void main() {
  late FakeBackend backend;
  late BoxController box;

  setUp(() {
    backend = FakeBackend();
    box = BoxController(backend);
  });

  test('splits the box into urgent and the rest, newest first as LunAcedia sends them, and counts the unread',
      () async {
    backend.inbox.items = [
      item('a', priority: 'urgent'),
      item('b'),
      item('c', priority: 'urgent', read: true),
      item('d', read: true),
    ];
    await box.load();
    expect(box.urgent.map((i) => i.key), ['a', 'c']);
    expect(box.rest.map((i) => i.key), ['b', 'd']);
    expect(box.unreadCount, 2);
    expect(box.urgentUnreadCount, 1);
  });

  test('filters by source', () async {
    backend.inbox.items = [item('m'), item('g', source: 'github'), item('t', source: 'tasks', priority: 'urgent')];
    await box.load();
    box.setFilter(BoxFilter.tasks);
    expect([...box.urgent, ...box.rest].map((i) => i.key), ['t']);
    box.setFilter(BoxFilter.all);
    expect([...box.urgent, ...box.rest], hasLength(3));
  });

  test('says why the box could not be read', () async {
    backend.inbox.listError = BackendError(BackendErrorKind.unreachable);
    await box.load();
    expect(box.error, isNotNull);
    expect(box.urgent, isEmpty);
  });

  test('a gesture that removes the item takes it out — the source answered, not a guess', () async {
    backend.inbox.items = [item('a'), item('b')];
    await box.load();
    final error = await box.gesture(box.rest.first, BoxGesture.archive);
    expect(error, isNull);
    expect(backend.inbox.gestures, [('a', BoxGesture.archive)]);
    expect(box.rest.map((i) => i.key), ['b']);
  });

  test('a refused gesture keeps the item and says why', () async {
    backend.inbox.items = [item('a')];
    await box.load();
    backend.inbox.gestureError = BackendError(BackendErrorKind.server, detail: 'Gmail said no');
    final error = await box.gesture(box.rest.first, BoxGesture.trash);
    expect(error, contains('Gmail said no'));
    expect(box.rest.map((i) => i.key), ['a']);
  });

  test('opening brings the full text and the item is now read', () async {
    backend.inbox.items = [item('a')];
    backend.inbox.openBody = 'Le texte entier.';
    await box.load();
    final body = await box.open(box.rest.first);
    expect(body, 'Le texte entier.');
    expect(box.rest.first.read, isTrue);
    expect(box.unreadCount, 0);
  });

  test('finds an item by key — what a notification points at', () async {
    backend.inbox.items = [item('email-1')];
    await box.load();
    expect(box.byKey('email-1')?.title, 'Titre email-1');
    expect(box.byKey('gone'), isNull);
  });

  test("keeps the hub's own alerts apart, and marks one read", () async {
    backend.hubAlertList = [hubAlert('h1'), hubAlert('h2', read: true)];
    await box.load();
    expect(box.hubAlerts.map((a) => a.id), ['h1', 'h2']);
    await box.markHubAlertRead('h1');
    expect(backend.hubAlertsRead, ['h1']);
    expect(box.hubAlerts.first.read, isTrue);
  });

  test('a hub alert failure never hides the box', () async {
    backend.inbox.items = [item('a')];
    backend.hubAlertError = BackendError(BackendErrorKind.server);
    await box.load();
    expect(box.error, isNull);
    expect(box.rest, hasLength(1));
    expect(box.hubAlerts, isEmpty);
  });

  test("lists Gmail's trash and restores from it", () async {
    backend.inbox.trashed = [TrashItem(id: 'm9', title: 'Vieux', from: 'Banque', ts: DateTime(2026))];
    expect((await box.trash()).single.id, 'm9');
    await box.restore('m9');
    expect(backend.inbox.restored, ['m9']);
  });
}
