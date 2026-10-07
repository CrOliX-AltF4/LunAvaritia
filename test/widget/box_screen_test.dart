import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:lunavaritia/models/alert.dart';
import 'package:lunavaritia/models/box_item.dart';
import 'package:lunavaritia/providers/box_controller.dart';
import 'package:lunavaritia/providers/shell_controller.dart';
import 'package:lunavaritia/screens/box_reader_screen.dart';
import 'package:lunavaritia/screens/box_screen.dart';
import 'package:lunavaritia/screens/trash_screen.dart';
import 'package:lunavaritia/services/backend_error.dart';
import 'package:lunavaritia/theme/app_theme.dart';

import '../support/fakes.dart';

// The box, the reader, the trash.

BoxItem item(String key, {String source = 'email', String priority = 'normal', String? title, String? from, String? reason}) =>
    BoxItem.fromJson({
      'dedupeKey': key,
      'type': '$source.x',
      'source': source,
      'title': title ?? 'Titre $key',
      'priority': priority,
      'ts': DateTime.now().millisecondsSinceEpoch,
      'read': false,
      'url': 'https://example.com/$key',
      if (from != null) 'meta': {'from': from},
      if (reason != null) 'priorityReason': reason,
    });

late FakeBackend backend;
late ShellController shell;
late BoxController box;

Future<void> pump(WidgetTester tester, Widget screen) async {
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: shell),
      ChangeNotifierProvider.value(value: box),
    ],
    child: MaterialApp(theme: buildAppTheme(), home: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    backend = FakeBackend();
    shell = ShellController(initial: const BoxDestination());
    box = BoxController(backend);
  });

  group('BoxScreen', () {
    testWidgets('urgent first, then the rest; the sender and source on each row', (tester) async {
      backend.inbox.items = [
        item('email-1', priority: 'urgent', title: "Colonne d'eau", from: 'Syndic <syndic@ex.fr>'),
        item('gh-1', source: 'github', title: 'Revue demandée'),
      ];
      await pump(tester, const BoxScreen());
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Le reste'), findsOneWidget);
      expect(find.text("Colonne d'eau"), findsOneWidget);
      expect(find.text('Mail · Syndic'), findsOneWidget);
      expect(find.text('GitHub'), findsWidgets);
    });

    testWidgets('says when the box is empty, and why it could not be read', (tester) async {
      await pump(tester, const BoxScreen());
      expect(find.text('La boîte est vide.'), findsOneWidget);

      backend.inbox.listError = BackendError(BackendErrorKind.unreachable);
      await box.load();
      await tester.pumpAndSettle();
      expect(find.text('Réessayer'), findsOneWidget);
    });

    testWidgets('a chip keeps one source', (tester) async {
      backend.inbox.items = [item('email-1', title: 'Un mail'), item('gh-1', source: 'github', title: 'Une revue')];
      await pump(tester, const BoxScreen());
      await tester.tap(find.widgetWithText(FilterChip, 'GitHub'));
      await tester.pumpAndSettle();
      expect(find.text('Une revue'), findsOneWidget);
      expect(find.text('Un mail'), findsNothing);
    });

    testWidgets('a swipe archives a mail at the source and it leaves the box', (tester) async {
      backend.inbox.items = [item('email-1', title: 'Facture')];
      await pump(tester, const BoxScreen());
      await tester.drag(find.text('Facture'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(backend.inbox.gestures, [('email-1', BoxGesture.archive)]);
      expect(find.text('Facture'), findsNothing);
    });

    testWidgets('a refused swipe keeps the item and says why', (tester) async {
      backend.inbox.items = [item('email-1', title: 'Facture')];
      backend.inbox.gestureError = BackendError(BackendErrorKind.server, detail: 'Gmail said no');
      await pump(tester, const BoxScreen());
      await tester.drag(find.text('Facture'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(find.text('Facture'), findsOneWidget);
      expect(find.textContaining('Gmail said no'), findsOneWidget);
    });

    testWidgets('an agenda item has no swipe', (tester) async {
      backend.inbox.items = [item('cal-1', source: 'calendar', title: 'Banque')];
      await pump(tester, const BoxScreen());
      await tester.drag(find.text('Banque'), const Offset(-600, 0));
      await tester.pumpAndSettle();
      expect(backend.inbox.gestures, isEmpty);
      expect(find.text('Banque'), findsOneWidget);
    });

    testWidgets('a long press reports a mail as spam, at the source, and it leaves the box', (tester) async {
      backend.inbox.items = [item('email-1', title: 'Promo AliExpress')];
      await pump(tester, const BoxScreen());
      await tester.longPress(find.text('Promo AliExpress'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('box-action-spam')));
      await tester.pumpAndSettle();
      expect(backend.inbox.gestures, [('email-1', BoxGesture.spam)]);
      expect(find.text('Promo AliExpress'), findsNothing);
    });

    testWidgets('a long press offers the gestures of the source, the trash apart', (tester) async {
      backend.inbox.items = [item('email-1', title: 'Facture')];
      await pump(tester, const BoxScreen());
      await tester.longPress(find.text('Facture'));
      await tester.pumpAndSettle();
      for (final label in ['Lire en entier', 'Traiter', 'Marquer comme lu', 'Archiver', 'Corbeille']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      await tester.tap(find.byKey(const ValueKey('box-action-trash')));
      await tester.pumpAndSettle();
      expect(backend.inbox.gestures, [('email-1', BoxGesture.trash)]);
      expect(find.text('Facture'), findsNothing);
    });

    testWidgets('"Fait" on a task, "Traiter" opens a topic about the item', (tester) async {
      backend.inbox.items = [item('task-1', source: 'tasks', title: 'Mutuelle')];
      await pump(tester, const BoxScreen());
      await tester.tap(find.widgetWithText(TextButton, 'Fait'));
      await tester.pumpAndSettle();
      expect(backend.inbox.gestures, [('task-1', BoxGesture.done)]);

      backend.inbox.items = [item('task-2', source: 'tasks', title: 'Impôts')];
      await box.load();
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(OutlinedButton, 'Traiter'));
      await tester.pumpAndSettle();
      final dest = shell.current as HomeDestination;
      expect(dest.aboutKey, 'task-2');
      expect(dest.aboutTitle, 'Impôts');
    });

    testWidgets('a tap opens the reader; "Corbeille" opens the trash', (tester) async {
      backend.inbox.items = [item('email-1', title: 'Facture')];
      await pump(tester, const BoxScreen());
      await tester.tap(find.text('Facture'));
      await tester.pumpAndSettle();
      expect((shell.current as BoxItemDestination).key, 'email-1');

      shell.go(const BoxDestination());
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Corbeille'));
      await tester.pumpAndSettle();
      expect(shell.current, isA<TrashDestination>());
    });

    testWidgets("the hub's own alerts sit apart; opening one shows its text and marks it read", (tester) async {
      backend.hubAlertList = [
        Alert(
          id: 'h1',
          type: 'system',
          source: AlertSource.system,
          title: 'Dépense du jour',
          body: 'Seuil de 2 \$ dépassé.',
          priority: AlertPriority.normal,
          ts: DateTime.now(),
          read: false,
        ),
      ];
      await pump(tester, const BoxScreen());
      expect(find.text('Du hub'), findsOneWidget);
      // Opening is reading: no « Lu » button.
      expect(find.widgetWithText(TextButton, 'Lu'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('hub-alert-h1')));
      await tester.pumpAndSettle();
      expect(find.text('Seuil de 2 \$ dépassé.'), findsOneWidget);
      expect(backend.hubAlertsRead, ['h1']);
      expect(box.hubAlerts.single.read, isTrue);
    });

    testWidgets('no « Du hub » section without hub alerts', (tester) async {
      backend.inbox.items = [item('email-1')];
      await pump(tester, const BoxScreen());
      expect(find.text('Du hub'), findsNothing);
    });
  });

  group('BoxReaderScreen', () {
    testWidgets('opens the item: its whole text, from whom, a third party wrote it', (tester) async {
      backend.inbox.items = [item('email-1', title: "Colonne d'eau", from: 'Syndic <syndic@ex.fr>')];
      backend.inbox.openBody = 'Bonjour, voici le texte entier.';
      await box.load();
      await pump(tester, const BoxReaderScreen(itemKey: 'email-1'));
      expect(backend.inbox.gestures, [('email-1', BoxGesture.open)]);
      expect(find.text('Bonjour, voici le texte entier.'), findsOneWidget);
      expect(find.text('Syndic <syndic@ex.fr>'), findsOneWidget);
      expect(find.textContaining("texte d'un tiers"), findsOneWidget);
    });

    // One way to set a priority, said on the item: « Urgent — VIP », « Normal — Gmail : important ».
    testWidgets('says why the item has its priority', (tester) async {
      backend.inbox.items = [item('email-1', priority: 'urgent', reason: 'VIP')];
      await box.load();
      await pump(tester, const BoxReaderScreen(itemKey: 'email-1'));
      expect(find.text('Urgent — VIP'), findsOneWidget);
    });

    testWidgets('archiving leads back to the box, the item gone', (tester) async {
      backend.inbox.items = [item('email-1', title: 'Facture')];
      await box.load();
      shell.go(const BoxItemDestination('email-1'));
      await pump(tester, const BoxReaderScreen(itemKey: 'email-1'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Archiver'));
      await tester.pumpAndSettle();
      expect(backend.inbox.gestures.last, ('email-1', BoxGesture.archive));
      expect(shell.current, isA<BoxDestination>());
      expect(box.byKey('email-1'), isNull);
    });

    // 2026-10-07: trashed from the sheet of actions, the mail being read stayed on screen.
    testWidgets('goes back to the box once the item left it, whatever did it', (tester) async {
      backend.inbox.items = [item('email-1', title: 'Facture')];
      await box.load();
      shell.go(const BoxItemDestination('email-1'));
      await pump(tester, const BoxReaderScreen(itemKey: 'email-1'));
      await tester.tap(find.byTooltip('Autres gestes'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('box-action-trash')));
      await tester.pumpAndSettle();
      expect(backend.inbox.gestures.last, ('email-1', BoxGesture.trash));
      expect(shell.current, isA<BoxDestination>());
    });

    testWidgets('offers no « Non lu »: opening is reading', (tester) async {
      backend.inbox.items = [item('email-1')];
      await box.load();
      await pump(tester, const BoxReaderScreen(itemKey: 'email-1'));
      expect(find.text('Non lu'), findsNothing);
      await tester.tap(find.byTooltip('Autres gestes'));
      await tester.pumpAndSettle();
      expect(find.text('Marquer non lu'), findsNothing);
    });

    testWidgets('says when the item is no longer in the box', (tester) async {
      await pump(tester, const BoxReaderScreen(itemKey: 'gone'));
      expect(find.text("Cet élément n'est plus dans la boîte."), findsOneWidget);
    });

    testWidgets('says why the text could not be opened', (tester) async {
      backend.inbox.items = [item('email-1')];
      await box.load();
      backend.inbox.gestureError = BackendError(BackendErrorKind.server, detail: 'mail no longer exists');
      await pump(tester, const BoxReaderScreen(itemKey: 'email-1'));
      expect(find.textContaining('mail no longer exists'), findsOneWidget);
    });
  });

  group('TrashScreen', () {
    testWidgets("lists Gmail's trash and restores a mail", (tester) async {
      backend.inbox.trashed = [TrashItem(id: 'm9', title: 'Relevé', from: 'Banque', ts: DateTime.now())];
      await pump(tester, const TrashScreen());
      expect(find.text('Relevé'), findsOneWidget);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Restaurer'));
      await tester.pumpAndSettle();
      expect(backend.inbox.restored, ['m9']);
      expect(find.text('Relevé'), findsNothing);
    });

    testWidgets('reads the trash a page at a time, and says what Gmail could not give', (tester) async {
      backend.inbox.trashPageSize = 1;
      backend.inbox.trashSkipped = 2;
      backend.inbox.trashed = [
        TrashItem(id: 'm1', title: 'Premier', from: 'A', ts: DateTime.now()),
        TrashItem(id: 'm2', title: 'Second', from: 'B', ts: DateTime.now()),
      ];
      await pump(tester, const TrashScreen());
      expect(find.text('Premier'), findsOneWidget);
      expect(find.text('Second'), findsNothing);
      expect(find.text('2 mails illisibles dans Gmail : absents de cette liste.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('trash-more')));
      await tester.pumpAndSettle();
      expect(find.text('Second'), findsOneWidget);
      expect(backend.inbox.trashPages, [null, '1']);
      expect(find.byKey(const ValueKey('trash-more')), findsNothing);
    });
  });
}
