import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:lunavaritia/models/digest.dart';
import 'package:lunavaritia/models/box_item.dart';
import 'package:lunavaritia/services/validation_api.dart';
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

Future<void> _openDrawer(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Ouvrir le tiroir'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MainShell — digest on wake', () {
    testWidgets('shows the digest sheet on cold start when the gate allows it', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend(digest: 'Overnight: 3 emails, 1 meeting.');

      await tester.pumpWidget(_buildShell(backend, digestGate: const DigestGate(minGap: Duration.zero)));
      await tester.pumpAndSettle();

      expect(find.text('Overnight: 3 emails, 1 meeting.'), findsOneWidget);
    });

    // 2026-10-07: the digest called urgent what the box did not — the urgent items now come listed by LunAcedia.
    testWidgets('lists the urgent items with why, and a tap opens one in the reader', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final shell = ShellController();
      final backend = FakeBackend(
        digest: 'Deux newsletters.',
        digestUrgent: const [DigestUrgent(key: 'email-1', title: 'Du syndic', priorityReason: 'VIP')],
      );

      await tester.pumpWidget(_buildShell(backend, shell: shell, digestGate: const DigestGate(minGap: Duration.zero)));
      await tester.pumpAndSettle();

      expect(find.text('Urgent (1)'), findsOneWidget);
      expect(find.text('VIP'), findsOneWidget);
      expect(find.text('Deux newsletters.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('digest-urgent-email-1')));
      await tester.pumpAndSettle();
      expect(shell.current, isA<BoxItemDestination>().having((d) => d.key, 'key', 'email-1'));
    });

    testWidgets('does not show the digest sheet when the gate blocks it', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend(digest: 'Overnight: 3 emails, 1 meeting.');
      const gate = DigestGate();
      await gate.markShown(); // simulate "already shown recently"

      await tester.pumpWidget(_buildShell(backend, digestGate: gate));
      await tester.pumpAndSettle();

      expect(find.text('Overnight: 3 emails, 1 meeting.'), findsNothing);
    });

    testWidgets('does not show a sheet for an empty digest', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildShell(FakeBackend(), digestGate: const DigestGate(minGap: Duration.zero)));
      await tester.pumpAndSettle();

      expect(find.byType(DraggableScrollableSheet), findsNothing);
      expect(find.text('Nouveau sujet…'), findsOneWidget);
    });

    testWidgets('fails silently and does not crash when the digest fetch errors', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildShell(
        FakeBackend(digestError: Exception('offline')),
        digestGate: const DigestGate(minGap: Duration.zero),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Nouveau sujet…'), findsOneWidget);
    });
  });

  group('MainShell — a tapped notification opens what it announces', () {
    testWidgets('the box item, read in full; back leads to the box', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      backend.inbox.items = [
        BoxItem.fromJson({'dedupeKey': 'email-7', 'source': 'email', 'title': 'Facture', 'priority': 'normal', 'ts': 1}),
      ];
      backend.inbox.openBody = 'Le texte entier.';
      final router = DeepLinkRouter.instance..consume();
      final shell = ShellController();
      await tester.pumpWidget(_buildShell(backend, shell: shell, deepLinkRouter: router));
      await tester.pumpAndSettle();

      router.request(const DeepLinkTarget.box(boxKey: 'email-7'));
      await tester.pumpAndSettle();
      expect((shell.current as BoxItemDestination).key, 'email-7');
      expect(find.text('Le texte entier.'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(shell.current, isA<BoxDestination>());
    });

    testWidgets('a notification arriving with the app open reads the box again', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      final router = DeepLinkRouter.instance..consume();
      final shell = ShellController(initial: const BoxDestination());
      await tester.pumpWidget(_buildShell(backend, shell: shell, deepLinkRouter: router));
      await tester.pumpAndSettle();
      expect(find.text('Nouveau mail'), findsNothing);

      backend.inbox.items = [
        BoxItem.fromJson({'dedupeKey': 'email-8', 'source': 'email', 'title': 'Nouveau mail', 'priority': 'normal', 'ts': 1}),
      ];
      router.nudgeBox();
      await tester.pumpAndSettle();
      expect(find.text('Nouveau mail'), findsOneWidget);
    });
  });

  group('MainShell — « Action à valider »', () {
    testWidgets('a pending-write notification opens « À valider », listed in the drawer with its count', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      backend.validation.writes = [
        PendingWrite(id: 'a1', summary: 'Répondre à un mail — Noté.', connector: 'Gmail', createdAt: DateTime.now()),
      ];
      final router = DeepLinkRouter.instance..consume();
      final shell = ShellController();
      await tester.pumpWidget(_buildShell(backend, shell: shell, deepLinkRouter: router));
      await tester.pumpAndSettle();

      router.request(const DeepLinkTarget.validate());
      await tester.pumpAndSettle();
      expect(shell.current, isA<ValidateDestination>());
      expect(find.text('Répondre à un mail — Noté.'), findsOneWidget);

      shell.openDrawer();
      await tester.pumpAndSettle();
      expect(find.text('À valider'), findsWidgets);
      expect(find.text('1'), findsWidgets);
    });
  });

  group('MainShell — a tapped notification opens the box', () {
    testWidgets('when it is already pending on first build', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = DeepLinkRouter.instance..consume();
      router.request(const DeepLinkTarget.box());
      final shell = ShellController();

      await tester.pumpWidget(_buildShell(FakeBackend(), shell: shell, deepLinkRouter: router));
      await tester.pumpAndSettle();

      expect(shell.current, isA<BoxDestination>());
      expect(find.text('Boîte'), findsWidgets);
      expect(router.pending, isNull);
    });

    testWidgets('when it arrives after the shell is built', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final router = DeepLinkRouter.instance..consume();
      final shell = ShellController();
      await tester.pumpWidget(_buildShell(FakeBackend(), shell: shell, deepLinkRouter: router));
      await tester.pumpAndSettle();
      expect(shell.current, isA<HomeDestination>());

      router.request(const DeepLinkTarget.box());
      await tester.pumpAndSettle();

      expect(shell.current, isA<BoxDestination>());
    });
  });

  group('MainShell — the drawer and the topics (DA1)', () {
    testWidgets('lists the topics by day and opens one with its messages', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      backend.topics.active = [
        topic('t1', 'Mail du syndic'),
        topic('t2', 'Courses', updatedAt: DateTime.now().subtract(const Duration(days: 3))),
      ];
      backend.topics.messages['t1'] = [userMessage('m1', 'Un mail urgent ?'), answer('m2', 'Oui, du syndic.')];

      await tester.pumpWidget(_buildShell(backend));
      await tester.pumpAndSettle();
      await _openDrawer(tester);

      expect(find.text('AUJOURD’HUI'), findsOneWidget);
      expect(find.text('7 DERNIERS JOURS'), findsOneWidget);
      await tester.tap(find.text('Mail du syndic'));
      await tester.pumpAndSettle();

      expect(find.byType(TopicScreen), findsOneWidget);
      expect(find.text('Oui, du syndic.'), findsOneWidget);
    });

    testWidgets('a new topic shows its first answer, and joins the drawer', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      backend.topics.nextAnswer = answer('a1', 'Rien d’urgent ce matin.');

      await tester.pumpWidget(_buildShell(backend));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Quoi de neuf ?');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();

      expect(backend.topics.opened, [('Quoi de neuf ?', null)]);
      expect(find.text('Rien d’urgent ce matin.'), findsOneWidget);
      await _openDrawer(tester);
      expect(find.text('Quoi de neuf ?'), findsWidgets);
    });

    testWidgets('a topic that could not open keeps what was typed and says why', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();

      await tester.pumpWidget(_buildShell(backend));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Quoi de neuf ?');
      await tester.tap(find.byTooltip('Envoyer'));
      await tester.pumpAndSettle();

      expect(find.byType(TopicScreen), findsNothing);
      expect(find.text(BackendError(BackendErrorKind.timeout).message), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Quoi de neuf ?'), findsOneWidget);
    });

    testWidgets('archiving from a long press takes the topic out of the drawer', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      backend.topics.active = [topic('t1', 'Mail du syndic')];

      await tester.pumpWidget(_buildShell(backend));
      await tester.pumpAndSettle();
      await _openDrawer(tester);
      await tester.longPress(find.text('Mail du syndic'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archiver'));
      await tester.pumpAndSettle();

      expect(backend.topics.archivedTopics.single.id, 't1');
      expect(find.text('Mail du syndic'), findsNothing);
    });

    testWidgets('back leads home before leaving the app', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final shell = ShellController(initial: const BoxDestination());
      await tester.pumpWidget(_buildShell(FakeBackend(), shell: shell));
      await tester.pumpAndSettle();

      final popped = await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      expect(popped, isTrue);
      expect(shell.current, isA<HomeDestination>());
    });
  });

  group('MainShell — pairing banner', () {
    testWidgets('says the phone is not paired and leads to the settings', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildShell(FakeBackend(), pairingNeeded: true));
      await tester.pumpAndSettle();

      expect(find.byType(MaterialBanner), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Réglages'));
      await tester.pumpAndSettle();
      expect(find.text('SETTINGS'), findsOneWidget);
      expect(find.byType(MaterialBanner), findsNothing);
    });

    testWidgets('says nothing when the phone is paired', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildShell(FakeBackend()));
      await tester.pumpAndSettle();
      expect(find.byType(MaterialBanner), findsNothing);
    });
  });

  group('MainShell — update on launch', () {
    const available = UpdateAvailable(AvailableUpdate(version: '1.4.0', downloadUrl: 'https://x/app.apk'));

    testWidgets('offers a newer release once, with a download action', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final checker = FakeUpdateChecker(available);
      await tester.pumpWidget(_buildShell(FakeBackend(), updateChecker: checker));
      await tester.pump();
      await tester.pump();

      expect(checker.calls, 1);
      expect(find.text('Version 1.4.0 disponible'), findsOneWidget);
      expect(find.text('Télécharger'), findsOneWidget);
      expect(await UpdateChecker.shouldNotify('1.4.0'), isFalse);
    });

    testWidgets('does not offer the same version again on the next launch', (tester) async {
      SharedPreferences.setMockInitialValues({'update_notified_version': '1.4.0'});
      await tester.pumpWidget(_buildShell(FakeBackend(), updateChecker: FakeUpdateChecker(available)));
      await tester.pump();
      await tester.pump();

      expect(find.text('Version 1.4.0 disponible'), findsNothing);
    });

    testWidgets('says nothing when up to date or when GitHub cannot be reached', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.pumpWidget(_buildShell(
        FakeBackend(),
        updateChecker: FakeUpdateChecker(const UpdateUnknown('GitHub injoignable')),
      ));
      await tester.pump();
      await tester.pump();

      expect(find.byType(SnackBar), findsNothing);
    });
  });
}
