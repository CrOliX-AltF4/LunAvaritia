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

import '../support/fakes.dart';

// ADR-020 S4 — the topic in progress: what an answer cites, and the actions settled where they appear (§5.8 (a)).

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
    expect(find.text('Confirmé — fait.'), findsOneWidget);
    expect(find.text('Confirmer'), findsNothing);
  });

  testWidgets('cancelling does nothing but say so', (tester) async {
    final backend = await _pump(tester, [answer('m2', 'Voici.', agent: _outcome(actions: [_reply]))]);
    await tester.tap(find.text('Annuler'));
    await tester.pumpAndSettle();
    expect(backend.topics.decisions, [('act-1', false)]);
    expect(find.text('Annulé — rien n’a été fait.'), findsOneWidget);
  });

  testWidgets('an action LunAcedia no longer holds shows as expired, with nothing to press', (tester) async {
    await _pump(tester, [
      answer('m2', 'Voici.', when: at(6), agent: _outcome(actions: [_reply])),
    ]);
    expect(find.text('Confirmer'), findsNothing);
    expect(find.textContaining('Expiré'), findsOneWidget);
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
    expect(find.text('Proposé pour la mémoire — à valider dans le panel.'), findsOneWidget);
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
