import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/models/topic.dart';
import 'package:lunavaritia/providers/shell_controller.dart';
import 'package:lunavaritia/providers/topic_controller.dart';
import 'package:lunavaritia/providers/topics_provider.dart';
import 'package:lunavaritia/screens/topic_screen.dart';
import 'package:lunavaritia/services/backend_client.dart';
import 'package:lunavaritia/theme/app_theme.dart';

import 'package:lunavaritia/services/notification_tray.dart';

import '../support/fakes.dart';

/// Records what the app takes down from the notification shade.
class _FakeTray implements NotificationTray {
  final List<String> dismissed = [];
  @override
  Future<void> dismiss(String tag) async => dismissed.add(tag);
  @override
  Future<List<String>> shownTags() async => const [];
}

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

// The topic in progress: what an answer cites, and the actions settled where they appear.

const _reply = AgentAction(
  kind: 'reply',
  status: 'pending',
  id: 'act-1',
  connector: 'gmail',
  fields: {'kind': 'reply', 'sourceId': 'm1', 'body': 'C’est noté pour jeudi.'},
);

AgentOutcome _outcome({List<CitedItem> items = const [], List<AgentAction> actions = const []}) =>
    AgentOutcome(status: 'done', items: items, actions: actions);

Future<FakeBackend> _pump(WidgetTester tester, List<TopicMessage> messages, {ShellController? shell}) async {
  SharedPreferences.setMockInitialValues({});
  final backend = FakeBackend();
  backend.topics.active = [topic('t1', 'Mail du syndic')];
  backend.topics.messages['t1'] = messages;
  await tester.pumpWidget(MultiProvider(
    providers: [
      Provider<BackendClient>.value(value: backend),
      ChangeNotifierProvider(create: (_) => shell ?? ShellController()),
      ChangeNotifierProvider(create: (_) => TopicsProvider(backend)),
      ChangeNotifierProvider(create: (_) => TopicController(backend, 't1')),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: const TopicScreen()),
  ));
  await tester.pumpAndSettle();
  return backend;
}

void main() {
  testWidgets('a batch shows what it would touch, as LunAcedia words it, and is confirmed in place', (tester) async {
    final backend = await _pump(tester, [
      userMessage('m1', 'Tout aliexpress en indésirable'),
      answer('m2', 'Deux mails à confirmer.', agent: _outcome(actions: [
        AgentAction.fromJson(const {
          'kind': 'bulk_email',
          'status': 'pending',
          'id': 'act-9',
          'connector': 'Gmail',
          'summary': 'Mettre un mail en indésirable × 2 — expéditeur contenant « aliexpress »',
          'action': {'kind': 'bulk_email', 'action': 'mark_spam', 'match': {'fromContains': 'aliexpress'}},
        }),
      ])),
    ]);
    expect(find.textContaining('× 2 — expéditeur contenant « aliexpress »'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(backend.topics.decisions, [('act-9', true)]);
  });

  testWidgets('confirms a waiting action right where it appears', (tester) async {
    final backend = await _pump(tester, [
      userMessage('m1', 'Réponds au syndic'),
      answer('m2', 'Voici la réponse.', agent: _outcome(actions: [_reply])),
    ]);

    expect(find.text('« C’est noté pour jeudi. »'), findsOneWidget);
    expect(find.textContaining('expire dans'), findsOneWidget);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();

    expect(backend.topics.decisions, [('act-1', true)]);
    expect(find.text('Confirmé par toi à ${_hm(DateTime.now())} — fait.'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
  });

  testWidgets('a decision takes the action\'s notification down', (tester) async {
    final tray = _FakeTray();
    NotificationTray.instance = tray;
    addTearDown(() => NotificationTray.instance = _FakeTray());
    await _pump(tester, [answer('m2', 'Voici.', agent: _outcome(actions: [_reply]))]);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(tray.dismissed, ['action-act-1']);
  });

  // 2026-10-07: a card stayed active once its action was decided elsewhere — a deletion could be confirmed again.
  testWidgets('reopened, a decided action shows how it ended, when and by whom, with nothing to press', (tester) async {
    final when = DateTime.now().subtract(const Duration(minutes: 20));
    await _pump(tester, [
      answer('m2', 'Voici.', when: at(30), agent: _outcome(actions: [
        AgentAction.fromJson({
          'kind': 'delete_event', 'status': 'pending', 'id': 'act-2', 'connector': 'Calendar',
          'action': {'kind': 'delete_event', 'sourceId': 'primary/ev1'},
          'expiresAt': DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch,
          'state': {'status': 'confirmed', 'at': when.millisecondsSinceEpoch, 'kind': 'delete_event'},
        }),
      ])),
    ]);
    expect(find.text('Confirmé par toi à ${_hm(when)} — fait.'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
    expect(find.text('Annuler'), findsNothing);
  });

  testWidgets('an action that failed at the source says why, with nothing to press', (tester) async {
    final when = DateTime.now().subtract(const Duration(minutes: 5));
    await _pump(tester, [
      answer('m2', 'Voici.', agent: _outcome(actions: [
        AgentAction.fromJson({
          'kind': 'delete_event', 'status': 'pending', 'id': 'act-3', 'connector': 'Calendar',
          'action': {'kind': 'delete_event', 'sourceId': 'primary/ev1'},
          'state': {'status': 'failed', 'at': when.millisecondsSinceEpoch, 'kind': 'delete_event', 'reason': 'event no longer exists'},
        }),
      ])),
    ]);
    expect(find.text('Pas fait (${_hm(when)}) : event no longer exists'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
  });

  testWidgets('an action done at its own tier says it was automatic, and when', (tester) async {
    final when = DateTime.now().subtract(const Duration(minutes: 3));
    await _pump(tester, [
      answer('m2', 'Archivé.', when: when, agent: _outcome(actions: [
        const AgentAction(kind: 'archive_email', status: 'executed', connector: 'Gmail', fields: {'sourceId': 'm1'}),
      ])),
    ]);
    expect(find.text('Fait automatiquement à ${_hm(when)}.'), findsOneWidget);
  });

  testWidgets('cancelling does nothing but say so', (tester) async {
    final backend = await _pump(tester, [answer('m2', 'Voici.', agent: _outcome(actions: [_reply]))]);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(backend.topics.decisions, [('act-1', false)]);
    expect(find.text('Annulé par toi à ${_hm(DateTime.now())} — rien n’a été fait.'), findsOneWidget);
  });

  testWidgets('an action LunAcedia no longer holds shows as expired, with nothing to press', (tester) async {
    await _pump(tester, [
      answer('m2', 'Voici.', when: at(6), agent: _outcome(actions: [_reply])),
    ]);
    expect(find.text('Confirmer'), findsNothing);
    expect(find.textContaining('Expiré'), findsOneWidget);
  });

  // LunAcedia's list is durable: an action lives until the deadline it carries, not 5 minutes.
  testWidgets('keeps an action decidable until the deadline LunAcedia gave it', (tester) async {
    final until = DateTime.now().add(const Duration(minutes: 90));
    await _pump(tester, [
      answer('m2', 'Voici.', when: at(30), agent: _outcome(actions: [
        AgentAction.fromJson({
          'kind': 'reply', 'status': 'pending', 'id': 'act-1', 'connector': 'gmail',
          'action': {'kind': 'reply', 'sourceId': 'm1', 'body': 'Noté.'},
          'expiresAt': until.millisecondsSinceEpoch,
        }),
      ])),
    ]);
    expect(find.text('Confirmer'), findsOneWidget);
    expect(find.textContaining('expire dans 1 h'), findsOneWidget);
  });

  testWidgets('says the action expired when the server answers it is gone', (tester) async {
    await _pump(tester, [answer('m2', 'Voici.', agent: _outcome(actions: [_reply]))]);
    final api = (tester.element(find.byType(TopicScreen)).read<BackendClient>() as FakeBackend).topics;
    api.decideError = BackendError(BackendErrorKind.rejected, statusCode: 410);
    await tester.tap(find.text('Confirmer'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Expiré'), findsOneWidget);
  });

  testWidgets('a memory proposal is not settled on the phone — it says where', (tester) async {
    await _pump(tester, [
      answer('m2', 'Je le note.', agent: _outcome(actions: [
        const AgentAction(kind: 'propose_memory', status: 'pending', id: 'p1', connector: 'memory', fields: {'text': 'Le syndic écrit par mail.'}),
      ])),
    ]);
    expect(find.text('Proposé pour la mémoire — à retenir dans « À valider ».'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
  });

  testWidgets('a cited element opens, and leads to a topic about it', (tester) async {
    final shell = ShellController(initial: const TopicDestination('t1'));
    await _pump(tester, [
      answer('m2', 'Oui.', external: true, agent: _outcome(items: [
        const CitedItem(key: 'email-42', source: 'email', title: 'Intervention colonne d’eau', from: 'Syndic', snippet: 'Jeudi 9 h.'),
      ])),
    ], shell: shell);

    expect(find.text("contient du texte d'un tiers"), findsOneWidget);
    await tester.tap(find.text('Intervention colonne d’eau'));
    await tester.pumpAndSettle();
    expect(find.text('Jeudi 9 h.'), findsOneWidget);
    await tester.tap(find.text('Ouvrir un sujet sur cet élément'));
    await tester.pumpAndSettle();

    expect((shell.current as HomeDestination).aboutKey, 'email-42');
  });

  testWidgets('a failed turn gives the text back when the server did not keep it', (tester) async {
    final backend = await _pump(tester, [answer('m1', 'Bonjour.')]);
    await tester.enterText(find.byType(TextField), 'Et le deuxième ?');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();

    expect(backend.topics.sent, [('t1', 'Et le deuxième ?')]);
    expect(find.widgetWithText(TextField, 'Et le deuxième ?'), findsOneWidget);
    expect(find.text(BackendError(BackendErrorKind.timeout).message), findsOneWidget);
  });

  testWidgets('…and never twice when the server kept it', (tester) async {
    await _pump(tester, [answer('m1', 'Bonjour.')]);
    final api = (tester.element(find.byType(TopicScreen)).read<BackendClient>() as FakeBackend).topics;
    api.keepsFailedMessage = true;
    await tester.enterText(find.byType(TextField), 'Et le deuxième ?');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();

    expect(find.widgetWithText(TextField, 'Et le deuxième ?'), findsNothing);
    expect(find.text('Et le deuxième ?'), findsOneWidget);
  });
}
