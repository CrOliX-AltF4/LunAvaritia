// The home screen: a new topic, optionally about an item of the box (« Traiter »).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/providers/box_controller.dart';
import 'package:lunavaritia/providers/validation_controller.dart';
import 'package:lunavaritia/providers/identity_provider.dart';
import 'package:lunavaritia/providers/shell_controller.dart';
import 'package:lunavaritia/providers/topics_provider.dart';
import 'package:lunavaritia/screens/main_shell.dart';
import 'package:lunavaritia/screens/topic_screen.dart';
import 'package:lunavaritia/services/backend_client.dart';
import 'package:lunavaritia/services/deep_link_router.dart';
import 'package:lunavaritia/services/digest_gate.dart';
import 'package:lunavaritia/services/update_checker.dart';
import 'package:lunavaritia/theme/app_theme.dart';

import '../support/fakes.dart';

const _quietGate = DigestGate(minGap: Duration(hours: 4));

Widget _buildShell(
  FakeBackend backend, {
  ShellController? shell,
  DigestGate digestGate = _quietGate,
  DeepLinkRouter? deepLinkRouter,
  UpdateChecker? updateChecker,
  bool pairingNeeded = false,
}) {
  return MultiProvider(
    providers: [
      Provider<BackendClient>.value(value: backend),
      ChangeNotifierProvider(create: (_) => shell ?? ShellController()),
      ChangeNotifierProvider(create: (_) => IdentityProvider(backend)),
      ChangeNotifierProvider(create: (_) => TopicsProvider(backend)),
      ChangeNotifierProvider(create: (_) => BoxController(backend)),
      ChangeNotifierProvider(create: (_) => ValidationController(backend)),
    ],
    child: MaterialApp(
      theme: buildAppTheme(),
      home: MainShell(
        digestGate: digestGate,
        deepLinkRouter: deepLinkRouter ?? (DeepLinkRouter.instance..consume()),
        updateChecker: updateChecker ?? FakeUpdateChecker(const UpToDate('1.3.1')),
        pairingNeeded: pairingNeeded,
        settings: const Scaffold(body: Text('SETTINGS')),
      ),
    ),
  );
}

void main() {
  group('« Traiter »: the home screen tied to an item of the box', () {
    testWidgets('the field is empty, the question only a hint', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final shell = ShellController(initial: const HomeDestination(aboutKey: 'email-1', aboutTitle: 'Promo'));
      await tester.pumpWidget(_buildShell(FakeBackend(), shell: shell));
      await tester.pumpAndSettle();
      final field = tester.widget<TextField>(find.byType(TextField).last);
      expect(field.controller!.text, isEmpty);
      expect(field.decoration!.hintText, "Qu'est-ce que je dois en faire ?");
    });

    testWidgets('sending the empty field asks that question about the item', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend()..topics.nextAnswer = answer('a1', 'Une promo, rien à faire.');
      final shell = ShellController(initial: const HomeDestination(aboutKey: 'email-1', aboutTitle: 'Promo'));
      await tester.pumpWidget(_buildShell(backend, shell: shell));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(backend.topics.opened, [("Qu'est-ce que je dois en faire ?", 'email-1')]);
      expect(find.byType(TopicScreen), findsOneWidget);
    });

    testWidgets('a written instruction is sent as written', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend()..topics.nextAnswer = answer('a1', 'À confirmer.');
      final shell = ShellController(initial: const HomeDestination(aboutKey: 'email-1', aboutTitle: 'Promo'));
      await tester.pumpWidget(_buildShell(backend, shell: shell));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, 'Mets-le en indésirable');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();
      expect(backend.topics.opened, [('Mets-le en indésirable', 'email-1')]);
    });
  });

  testWidgets('while the topic opens, the message sent shows at once, and « Je regarde… »', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final release = Completer<void>();
    final backend = FakeBackend()
      ..topics.nextAnswer = answer('a1', 'Fait.')
      ..topics.hold = release.future;
    final shell = ShellController(initial: const HomeDestination(aboutKey: 'email-1', aboutTitle: 'Promo'));
    await tester.pumpWidget(_buildShell(backend, shell: shell));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Archive-le');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pump();
    expect(find.text('Archive-le', findRichText: true), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, isEmpty);
    expect(find.text('Je regarde…'), findsOneWidget);
    release.complete();
    await tester.pumpAndSettle();
    expect(find.byType(TopicScreen), findsOneWidget);
  });

  testWidgets('when opening fails, the text comes back in the field', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final backend = FakeBackend(); // no answer: the turn fails
    await tester.pumpWidget(_buildShell(backend));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'Mes mails urgents ?');
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField).last).controller!.text, 'Mes mails urgents ?');
    expect(find.text("Le serveur n'a pas répondu à temps."), findsOneWidget);
    expect(find.text('Je regarde…'), findsNothing);
  });

  testWidgets('without an item, the empty field sends nothing', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final backend = FakeBackend();
    await tester.pumpWidget(_buildShell(backend));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Envoyer'));
    await tester.pumpAndSettle();
    expect(backend.topics.opened, isEmpty);
  });
}
